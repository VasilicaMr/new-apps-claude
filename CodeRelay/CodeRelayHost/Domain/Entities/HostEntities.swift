import Foundation
import RelayKit

/// An iPhone/iPad that completed pairing with this Mac.
struct PairedDevice: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var pairedAt: Date
    var lastSeenAt: Date?
}

/// User-editable host configuration.
struct HostSettings: Codable, Equatable {
    /// Folders the phone may open. Claude can only be started inside these.
    var workspaceRoots: [String] = []
    /// Optional absolute path to the `claude` binary; auto-detected when nil.
    var claudePathOverride: String?
    var port: UInt16 = RelayConstants.defaultPort
}

/// A located Claude Code CLI install.
struct ClaudeInstallation: Equatable {
    var executable: URL
    var version: String?
    /// PATH captured from the user's login shell so the CLI finds node, git, etc.
    var environment: [String: String]
}

/// Persisted record of a session so it can be resumed after the host restarts.
struct SessionRecord: Codable, Hashable {
    var summary: SessionSummary
}
