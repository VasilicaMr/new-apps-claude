import Foundation
import RelayKit

/// Device metadata lives in UserDefaults; the secret keys live in the Keychain.
final class DefaultsPairedDeviceRepository: PairedDeviceRepository {
    private let defaults: UserDefaults
    private let keychain = KeychainStore(service: "com.adaptiveservices.coderelay.host.devices")
    private let storageKey = "pairedDevices"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func all() -> [PairedDevice] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([PairedDevice].self, from: data)) ?? []
    }

    func key(for deviceID: String) -> Data? {
        keychain.data(for: deviceID)
    }

    func save(_ device: PairedDevice, key: Data) {
        keychain.set(key, for: device.id)
        update(device)
    }

    func update(_ device: PairedDevice) {
        var devices = all().filter { $0.id != device.id }
        devices.append(device)
        write(devices)
    }

    func remove(_ deviceID: String) {
        keychain.remove(deviceID)
        write(all().filter { $0.id != deviceID })
    }

    private func write(_ devices: [PairedDevice]) {
        defaults.set(try? JSONEncoder().encode(devices), forKey: storageKey)
    }
}

final class DefaultsHostSettingsRepository: HostSettingsRepository {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HostSettings {
        guard let data = defaults.data(forKey: "hostSettings"),
              let settings = try? JSONDecoder().decode(HostSettings.self, from: data) else { return HostSettings() }
        return settings
    }

    func save(_ settings: HostSettings) {
        defaults.set(try? JSONEncoder().encode(settings), forKey: "hostSettings")
    }

    func hostID() -> String {
        if let id = defaults.string(forKey: "hostID") { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: "hostID")
        return id
    }
}

final class FileSessionRecordRepository: SessionRecordRepository {
    private let url: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodeRelayHost", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        url = support.appendingPathComponent("sessions.json")
    }

    func load() -> [SessionRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? FrameCodec.makeDecoder().decode([SessionRecord].self, from: data)) ?? []
    }

    func save(_ records: [SessionRecord]) {
        guard let data = try? FrameCodec.makeEncoder().encode(records) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
