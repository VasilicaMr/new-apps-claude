import Foundation
import RelayKit

/// A row in the terminal-style transcript.
struct TranscriptItem: Identifiable, Equatable {
    enum PermissionState: Equatable {
        case pending, allowed, denied, expired
    }

    enum Kind: Equatable {
        case user(String)
        case assistant(String, isStreaming: Bool)
        case tool(name: String, summary: String, output: String?, isError: Bool)
        case permission(PermissionPrompt, state: PermissionState)
        case notice(String)
        case system(String)
        case turnSummary(isError: Bool, costUSD: Double?, durationMS: Int?)
    }

    let id: String
    var kind: Kind
}
