import Foundation
import RelayKit

/// Where a host can be reached.
enum HostEndpoint: Codable, Hashable {
    /// Discovered on the local network via Bonjour.
    case bonjour(serviceName: String)
    /// Entered by hand: LAN IP, Tailscale/VPN address, etc.
    case manual(host: String, port: UInt16)
    /// Built-in simulated host for App Review, screenshots and trying the app.
    case demo

    var displayAddress: String {
        switch self {
        case .bonjour(let name): return "\(name).local"
        case .manual(let host, let port): return "\(host):\(port)"
        case .demo: return "Demo"
        }
    }
}

/// A Mac this device has paired with. The secret key is stored separately in the Keychain.
struct SavedHost: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var endpoint: HostEndpoint
    var pairedAt: Date
    var lastConnectedAt: Date?

    static let demo = SavedHost(id: "demo-host", name: "Demo Mac", endpoint: .demo,
                                pairedAt: .distantPast, lastConnectedAt: nil)
}

/// A host seen on the network right now.
struct DiscoveredHost: Hashable, Identifiable {
    var serviceName: String
    var hostID: String?
    var id: String { serviceName }
    var endpoint: HostEndpoint { .bonjour(serviceName: serviceName) }
}

/// Secret used to authenticate the TLS-PSK connection.
struct HostCredential: Hashable {
    var identity: String
    var key: Data
}

enum ConnectionState: Equatable {
    case idle
    case connecting
    case connected(HostInfo)
    case disconnected(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

enum RelayError: LocalizedError, Equatable {
    case timeout
    case connectionClosed(String?)
    case notPaired
    case missingKey
    case host(String)

    var errorDescription: String? {
        switch self {
        case .timeout: return "The Mac did not respond in time."
        case .connectionClosed(let reason):
            return reason ?? "Could not connect. Check the code, that CodeRelay Host is running, and that both devices are on the same network."
        case .notPaired: return "This Mac no longer recognises this device. Pair again."
        case .missingKey: return "The pairing key for this Mac is missing. Pair again."
        case .host(let message): return message
        }
    }
}
