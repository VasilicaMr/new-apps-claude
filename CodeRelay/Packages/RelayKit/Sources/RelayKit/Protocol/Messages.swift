import Foundation

/// Messages sent from the iOS app to the Mac host.
public enum ClientMessage: Codable, Sendable {
    case hello(deviceID: String, deviceName: String, protocolVersion: Int)
    case pair(deviceName: String)
    case listProjects
    case listSessions
    case startSession(projectPath: String, permissionMode: PermissionMode, resumeClaudeSessionID: String?)
    case attach(sessionID: String)
    case prompt(sessionID: String, text: String)
    case permissionDecision(sessionID: String, requestID: String, allow: Bool)
    case interrupt(sessionID: String)
    case renameSession(sessionID: String, title: String)
    case closeSession(sessionID: String)
    case ping
}

/// Messages sent from the Mac host to the iOS app.
public enum HostMessage: Codable, Sendable {
    case welcome(host: HostInfo, paired: Bool)
    case paired(hostID: String, key: Data)
    case projects([ProjectInfo])
    case sessions([SessionSummary])
    case sessionStarted(SessionSummary)
    case history(sessionID: String, events: [ClaudeEvent])
    case event(sessionID: String, event: ClaudeEvent)
    case sessionClosed(sessionID: String)
    case error(String)
    case pong
}

public enum RelayConstants {
    /// Bonjour service type advertised by the host.
    public static let bonjourType = "_coderelay._tcp"
    /// Default TCP port (fixed so manual / VPN connections are predictable).
    public static let defaultPort: UInt16 = 52734
    /// PSK identity used during pairing (before the device has its own key).
    public static let pairingIdentity = "coderelay-pairing"
    /// Seconds a pairing code stays valid.
    public static let pairingCodeLifetime: TimeInterval = 120
}
