import Foundation
import Observation
import RelayKit

/// Owns the live connection to one Mac and routes host messages to sessions.
@MainActor
@Observable
final class WorkspaceViewModel {
    let host: SavedHost
    let assistant: AIAssistant
    private(set) var state: ConnectionState = .idle
    private(set) var projects: [ProjectInfo] = []
    private(set) var sessions: [SessionSummary] = []
    var errorMessage: String?
    var openedSession: SessionSummary?

    @ObservationIgnored private let connectUseCase: ConnectHostUseCase
    @ObservationIgnored private var connection: HostConnection?
    @ObservationIgnored private var listenTask: Task<Void, Never>?
    @ObservationIgnored private var sessionModels: [String: SessionViewModel] = [:]
    @ObservationIgnored private var openWhenStarted = false

    init(host: SavedHost, connectUseCase: ConnectHostUseCase, assistant: AIAssistant) {
        self.host = host
        self.connectUseCase = connectUseCase
        self.assistant = assistant
    }

    var hostInfo: HostInfo? {
        if case .connected(let info) = state { return info }
        return nil
    }

    func connectIfNeeded() async {
        switch state {
        case .connected, .connecting: return
        case .idle, .disconnected: await connect()
        }
    }

    func connect() async {
        state = .connecting
        do {
            let (connection, info) = try await connectUseCase.execute(host)
            self.connection = connection
            state = .connected(info)
            listen(to: connection)
            connection.send(.listProjects)
            connection.send(.listSessions)
            // Re-sync any session screens that were open before a reconnect.
            for id in sessionModels.keys { connection.send(.attach(sessionID: id)) }
            sessionModels.values.forEach { $0.isConnected = true }
        } catch {
            state = .disconnected((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func disconnect() {
        listenTask?.cancel()
        connection?.close()
        connection = nil
        state = .idle
    }

    func startSession(in project: ProjectInfo, mode: PermissionMode) {
        openWhenStarted = true
        send(.startSession(projectPath: project.path, permissionMode: mode, resumeClaudeSessionID: nil))
    }

    func delete(_ session: SessionSummary) {
        send(.closeSession(sessionID: session.id))
    }

    func sessionModel(for summary: SessionSummary) -> SessionViewModel {
        if let existing = sessionModels[summary.id] { return existing }
        let model = SessionViewModel(summary: summary, assistant: assistant) { [weak self] message in
            self?.send(message)
        }
        model.isConnected = state.isConnected
        sessionModels[summary.id] = model
        send(.attach(sessionID: summary.id))
        return model
    }

    private func send(_ message: ClientMessage) {
        guard let connection else {
            errorMessage = "Not connected to \(host.name)."
            return
        }
        connection.send(message)
    }

    private func listen(to connection: HostConnection) {
        listenTask?.cancel()
        listenTask = Task { [weak self] in
            for await message in connection.messages {
                self?.handle(message)
            }
            guard let self, self.connection === connection else { return }
            self.connection = nil
            self.state = .disconnected("Connection to \(self.host.name) was lost.")
            self.sessionModels.values.forEach { $0.isConnected = false }
        }
    }

    private func handle(_ message: HostMessage) {
        switch message {
        case .projects(let projects):
            self.projects = projects
        case .sessions(let sessions):
            self.sessions = sessions
            for summary in sessions { sessionModels[summary.id]?.summary = summary }
        case .sessionStarted(let summary):
            if !sessions.contains(where: { $0.id == summary.id }) { sessions.insert(summary, at: 0) }
            if openWhenStarted {
                openWhenStarted = false
                openedSession = summary
            }
        case .history(let sessionID, let events):
            sessionModels[sessionID]?.replay(events)
        case .event(let sessionID, let event):
            sessionModels[sessionID]?.apply(event)
        case .sessionClosed(let sessionID):
            sessions.removeAll { $0.id == sessionID }
            sessionModels[sessionID] = nil
        case .error(let text):
            errorMessage = text
        case .welcome, .paired, .pong:
            break
        }
    }
}
