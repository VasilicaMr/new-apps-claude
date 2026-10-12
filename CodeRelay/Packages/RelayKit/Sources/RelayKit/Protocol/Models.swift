import Foundation

/// Bumped whenever a breaking change is made to `ClientMessage` / `HostMessage`.
public let relayProtocolVersion = 1

/// How the Claude CLI on the Mac should handle tool permission prompts.
public enum PermissionMode: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Every prompt is forwarded to the phone and waits for Allow / Deny.
    case ask
    /// File edits are auto-accepted, other prompts are forwarded.
    case acceptEdits
    /// Claude only plans; it cannot change anything.
    case plan
    /// Nothing is asked. Dangerous; the UI requires an explicit confirmation.
    case bypassPermissions

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ask: return "Ask me"
        case .acceptEdits: return "Auto-accept edits"
        case .plan: return "Plan only"
        case .bypassPermissions: return "Bypass (dangerous)"
        }
    }
}

/// Identity of a Mac running CodeRelay Host.
public struct HostInfo: Codable, Hashable, Sendable {
    public var hostID: String
    public var name: String
    public var claudeVersion: String?
    public var claudeAvailable: Bool

    public init(hostID: String, name: String, claudeVersion: String?, claudeAvailable: Bool) {
        self.hostID = hostID
        self.name = name
        self.claudeVersion = claudeVersion
        self.claudeAvailable = claudeAvailable
    }
}

/// A folder on the Mac that Claude can work in.
public struct ProjectInfo: Codable, Hashable, Identifiable, Sendable {
    public var path: String
    public var name: String
    public var isGitRepository: Bool

    public var id: String { path }

    public init(path: String, name: String, isGitRepository: Bool) {
        self.path = path
        self.name = name
        self.isGitRepository = isGitRepository
    }
}

/// A Claude conversation managed by the host.
public struct SessionSummary: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var claudeSessionID: String?
    public var projectPath: String
    public var title: String
    public var permissionMode: PermissionMode
    public var createdAt: Date
    public var isRunning: Bool

    public init(id: String, claudeSessionID: String?, projectPath: String, title: String,
                permissionMode: PermissionMode, createdAt: Date, isRunning: Bool) {
        self.id = id
        self.claudeSessionID = claudeSessionID
        self.projectPath = projectPath
        self.title = title
        self.permissionMode = permissionMode
        self.createdAt = createdAt
        self.isRunning = isRunning
    }

    public var projectName: String { (projectPath as NSString).lastPathComponent }
}

/// A tool call Claude wants to make that needs the user's approval.
public struct PermissionPrompt: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var toolName: String
    public var summary: String
    public var detail: String

    public init(id: String, toolName: String, summary: String, detail: String) {
        self.id = id
        self.toolName = toolName
        self.summary = summary
        self.detail = detail
    }
}

/// Normalised view of the Claude CLI `stream-json` output.
/// The host translates raw CLI lines into these events so the phone never
/// depends on CLI internals.
public enum ClaudeEvent: Codable, Hashable, Sendable {
    case started(model: String?, cwd: String?, claudeSessionID: String?)
    case userPrompt(String)
    case textDelta(String)
    case text(String)
    case thinking
    case toolUse(id: String, name: String, summary: String)
    case toolResult(toolUseID: String, output: String, isError: Bool)
    case permissionRequested(PermissionPrompt)
    case permissionResolved(requestID: String, allowed: Bool)
    case turnCompleted(isError: Bool, costUSD: Double?, durationMS: Int?)
    case notice(String)
    case processExited(code: Int32)
}
