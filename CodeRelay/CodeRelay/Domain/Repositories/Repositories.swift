import Foundation
import RelayKit

/// Paired hosts + their secret keys.
protocol HostRepository {
    func all() -> [SavedHost]
    func credentialKey(for hostID: String) -> Data?
    func save(_ host: SavedHost, key: Data?)
    func remove(_ hostID: String)
}

/// Stable identity of this iPhone/iPad.
protocol DeviceIdentityProviding {
    var deviceID: String { get }
    var deviceName: String { get }
}

/// A live, authenticated-at-TLS-level link to a host.
@MainActor
protocol HostConnection: AnyObject {
    /// Every message from the host; finishes when the connection closes.
    var messages: AsyncStream<HostMessage> { get }
    func send(_ message: ClientMessage)
    func close()
}

/// Opens connections. Returns once the TLS handshake succeeded.
@MainActor
protocol HostConnecting {
    func open(_ endpoint: HostEndpoint, credential: HostCredential) async throws -> HostConnection
}

/// Watches the local network for hosts.
@MainActor
protocol HostDiscovering: AnyObject {
    var onChange: (([DiscoveredHost]) -> Void)? { get set }
    func start()
    func stop()
}

enum AIAvailability: Equatable {
    case available
    case unavailable(String)

    var isAvailable: Bool { self == .available }
}

/// On-device language model features (Apple Intelligence).
@MainActor
protocol AIAssistant {
    var availability: AIAvailability { get }
    func refine(prompt: String, projectName: String) async throws -> String
    func summarize(transcript: String) async throws -> String
    func suggestFollowUps(transcript: String) async throws -> [String]
    func explain(toolName: String, detail: String) async throws -> String
    func title(for transcript: String) async throws -> String
}
