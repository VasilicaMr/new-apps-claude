import Foundation
import UIKit
import RelayKit

/// Saved hosts in UserDefaults, their keys in the Keychain.
final class DefaultsHostRepository: HostRepository {
    private let defaults: UserDefaults
    private let keychain = KeychainStore(service: "com.adaptiveservices.coderelay.hosts")
    private let storageKey = "savedHosts"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func all() -> [SavedHost] {
        guard let data = defaults.data(forKey: storageKey),
              let hosts = try? JSONDecoder().decode([SavedHost].self, from: data) else { return [] }
        return hosts.sorted { ($0.lastConnectedAt ?? $0.pairedAt) > ($1.lastConnectedAt ?? $1.pairedAt) }
    }

    func credentialKey(for hostID: String) -> Data? {
        keychain.data(for: hostID)
    }

    func save(_ host: SavedHost, key: Data?) {
        if let key { keychain.set(key, for: host.id) }
        var hosts = all().filter { $0.id != host.id }
        hosts.append(host)
        defaults.set(try? JSONEncoder().encode(hosts), forKey: storageKey)
    }

    func remove(_ hostID: String) {
        keychain.remove(hostID)
        defaults.set(try? JSONEncoder().encode(all().filter { $0.id != hostID }), forKey: storageKey)
    }
}

/// Device ID kept in the Keychain so it survives reinstalls (pairings stay valid).
@MainActor
final class KeychainDeviceIdentity: DeviceIdentityProviding {
    private let keychain = KeychainStore(service: "com.adaptiveservices.coderelay.identity")

    lazy var deviceID: String = {
        if let data = keychain.data(for: "deviceID"), let id = String(data: data, encoding: .utf8) { return id }
        let id = UUID().uuidString
        keychain.set(Data(id.utf8), for: "deviceID")
        return id
    }()

    var deviceName: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }
}
