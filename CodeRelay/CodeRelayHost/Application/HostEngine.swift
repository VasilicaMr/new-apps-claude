import Foundation
import Observation
import OSLog
import RelayKit

/// Application layer for the Mac host: wires the network server, pairing,
/// project access rules and Claude sessions together, and exposes state to the UI.
@MainActor
@Observable
final class HostEngine {
    // MARK: UI state
    private(set) var serverStatus: RelayServer.Status = .stopped
    private(set) var claude: ClaudeInstallation?
    private(set) var isLocatingClaude = false
    private(set) var pairingCode: String?
    private(set) var pairingExpiresAt: Date?
    private(set) var pairedDevices: [PairedDevice] = []
    private(set) var connectedDeviceIDs: Set<String> = []
    private(set) var sessions: [SessionSummary] = []
    private(set) var settings: HostSettings

    let hostName = Host.current().localizedName ?? "Mac"

    // MARK: Dependencies
    @ObservationIgnored private let deviceRepository: PairedDeviceRepository
    @ObservationIgnored private let settingsRepository: HostSettingsRepository
    @ObservationIgnored private let sessionRepository: SessionRecordRepository
    @ObservationIgnored private let locator: ClaudeLocating
    @ObservationIgnored private let server = RelayServer()
    @ObservationIgnored private var controllers: [String: SessionController] = [:]
    @ObservationIgnored private var pairingTimer: Timer?
    @ObservationIgnored private let hostID: String
    @ObservationIgnored private let logger = Logger(subsystem: "com.adaptiveservices.coderelay.host", category: "engine")

    init(deviceRepository: PairedDeviceRepository, settingsRepository: HostSettingsRepository,
         sessionRepository: SessionRecordRepository, locator: ClaudeLocating) {
        self.deviceRepository = deviceRepository
        self.settingsRepository = settingsRepository
        self.sessionRepository = sessionRepository
        self.locator = locator
        self.settings = settingsRepository.load()
        self.hostID = settingsRepository.hostID()
        self.pairedDevices = deviceRepository.all()
        restoreSessions()

        server.onMessage = { [weak self] link, message in self?.handle(message, from: link) }
        server.onLinksChanged = { [weak self] in self?.refreshConnectedDevices() }
        server.onStatusChange = { [weak self] status in self?.serverStatus = status }
    }

    func start() {
        restartListener()
        Task { await refreshClaude() }
    }

    func refreshClaude() async {
        isLocatingClaude = true
        claude = await locator.locate(override: settings.claudePathOverride)
        isLocatingClaude = false
    }

    // MARK: Settings

    func addWorkspaceRoot(_ path: String) {
        let canonical = ProjectAccessPolicy.canonical(path)
        guard !settings.workspaceRoots.contains(canonical) else { return }
        settings.workspaceRoots.append(canonical)
        persistSettings()
    }

    func removeWorkspaceRoot(_ path: String) {
        settings.workspaceRoots.removeAll { $0 == path }
        persistSettings()
    }

    func setClaudePathOverride(_ path: String?) {
        settings.claudePathOverride = path?.isEmpty == true ? nil : path
        persistSettings()
        Task { await refreshClaude() }
    }

    private func persistSettings() {
        settingsRepository.save(settings)
        server.broadcast(.projects(policy.listProjects()))
    }

    private var policy: ProjectAccessPolicy { ProjectAccessPolicy(roots: settings.workspaceRoots) }

    // MARK: Pairing

    func beginPairing() {
        pairingCode = PairingCrypto.generatePairingCode()
        pairingExpiresAt = Date().addingTimeInterval(RelayConstants.pairingCodeLifetime)
        pairingTimer?.invalidate()
        pairingTimer = Timer.scheduledTimer(withTimeInterval: RelayConstants.pairingCodeLifetime, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.endPairing() }
        }
        restartListener()
    }

    func endPairing() {
        pairingTimer?.invalidate()
        pairingTimer = nil
        guard pairingCode != nil else { return }
        pairingCode = nil
        pairingExpiresAt = nil
        restartListener()
    }

    func revoke(_ device: PairedDevice) {
        deviceRepository.remove(device.id)
        pairedDevices = deviceRepository.all()
        server.disconnect(deviceID: device.id)
        restartListener()
    }

    private func restartListener() {
        var psks = pairedDevices.compactMap { device in
            deviceRepository.key(for: device.id).map { TLSParameters.PSK(identity: device.id, key: $0) }
        }
        if let pairingCode {
            psks.append(TLSParameters.PSK(identity: RelayConstants.pairingIdentity,
                                          key: PairingCrypto.pairingKey(for: pairingCode)))
        }
        server.start(serviceName: hostName, hostID: hostID, port: settings.port, psks: psks)
    }

    // MARK: Sessions

    func stopSession(_ id: String) {
        controllers[id]?.close()
    }

    func deleteSession(_ id: String) {
        controllers.removeValue(forKey: id)?.close()
        sessions.removeAll { $0.id == id }
        persistSessions()
        server.broadcast(.sessionClosed(sessionID: id))
    }

    private func restoreSessions() {
        for record in sessionRepository.load() {
            var summary = record.summary
            summary.isRunning = false
            makeController(summary)
        }
        sessions.sort { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    private func makeController(_ summary: SessionSummary) -> SessionController {
        let controller = SessionController(summary: summary) { [weak self] in self?.claude }
        let id = summary.id
        controller.onEvent = { [weak self] event in
            self?.server.broadcast(.event(sessionID: id, event: event))
        }
        controller.onSummaryChange = { [weak self] summary in
            guard let self else { return }
            if let index = self.sessions.firstIndex(where: { $0.id == summary.id }) {
                self.sessions[index] = summary
            }
            self.persistSessions()
            self.server.broadcast(.sessions(self.sessions))
        }
        controllers[id] = controller
        sessions.append(summary)
        return controller
    }

    private func persistSessions() {
        sessionRepository.save(sessions.prefix(100).map { SessionRecord(summary: $0) })
    }

    // MARK: Protocol handling

    private func handle(_ message: ClientMessage, from link: ClientLink) {
        switch message {
        case .hello(let deviceID, let deviceName, let version):
            guard version == relayProtocolVersion else {
                link.send(.error("Protocol mismatch. Please update CodeRelay on both devices."))
                return
            }
            link.deviceID = deviceID
            link.deviceName = deviceName
            if var device = pairedDevices.first(where: { $0.id == deviceID }) {
                link.isAuthenticated = true
                device.lastSeenAt = Date()
                device.name = deviceName
                deviceRepository.update(device)
                pairedDevices = deviceRepository.all()
            }
            link.send(.welcome(host: hostInfo, paired: link.isAuthenticated))
            refreshConnectedDevices()
            return
        case .pair(let deviceName):
            pair(link, deviceName: deviceName)
            return
        case .ping:
            link.send(.pong)
            return
        default:
            break
        }

        guard link.isAuthenticated else {
            link.send(.error("This device is not paired."))
            return
        }

        switch message {
        case .listProjects:
            link.send(.projects(policy.listProjects()))
        case .listSessions:
            link.send(.sessions(sessions))
        case .startSession(let projectPath, let mode, let resumeID):
            guard policy.isAllowed(projectPath) else {
                link.send(.error("That folder is not in an allowed workspace on the Mac."))
                return
            }
            let summary = SessionSummary(id: UUID().uuidString, claudeSessionID: resumeID,
                                         projectPath: ProjectAccessPolicy.canonical(projectPath),
                                         title: "New session", permissionMode: mode,
                                         createdAt: Date(), isRunning: false)
            makeController(summary)
            sessions.sort { $0.createdAt > $1.createdAt }
            persistSessions()
            link.send(.sessionStarted(summary))
            server.broadcast(.sessions(sessions))
        case .attach(let sessionID):
            guard let controller = controllers[sessionID] else {
                link.send(.error("Session not found."))
                return
            }
            link.send(.history(sessionID: sessionID, events: controller.history))
        case .prompt(let sessionID, let text):
            controllers[sessionID]?.send(prompt: text)
        case .permissionDecision(let sessionID, let requestID, let allow):
            controllers[sessionID]?.decide(requestID: requestID, allow: allow)
        case .interrupt(let sessionID):
            controllers[sessionID]?.interrupt()
        case .renameSession(let sessionID, let title):
            controllers[sessionID]?.rename(String(title.prefix(80)))
        case .closeSession(let sessionID):
            deleteSession(sessionID)
        case .hello, .pair, .ping:
            break
        }
    }

    private func pair(_ link: ClientLink, deviceName: String) {
        guard pairingCode != nil, let deviceID = link.deviceID else {
            link.send(.error("Pairing is not active. Click “Pair a device” on your Mac."))
            return
        }
        let key = PairingCrypto.generateDeviceKey()
        let device = PairedDevice(id: deviceID, name: deviceName, pairedAt: Date(), lastSeenAt: Date())
        deviceRepository.save(device, key: key)
        pairedDevices = deviceRepository.all()
        link.send(.paired(hostID: hostID, key: key))
        logger.info("Paired device \(deviceName, privacy: .public)")
        // Codes are single use; this also restarts the listener with the new key.
        endPairing()
    }

    private var hostInfo: HostInfo {
        HostInfo(hostID: hostID, name: hostName, claudeVersion: claude?.version, claudeAvailable: claude != nil)
    }

    private func refreshConnectedDevices() {
        connectedDeviceIDs = Set(server.links.values.compactMap { $0.isAuthenticated ? $0.deviceID : nil })
    }
}
