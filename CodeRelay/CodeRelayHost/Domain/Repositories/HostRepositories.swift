import Foundation

/// Persistence of paired devices and their secret keys.
protocol PairedDeviceRepository {
    func all() -> [PairedDevice]
    func key(for deviceID: String) -> Data?
    func save(_ device: PairedDevice, key: Data)
    func update(_ device: PairedDevice)
    func remove(_ deviceID: String)
}

protocol HostSettingsRepository {
    func load() -> HostSettings
    func save(_ settings: HostSettings)
    /// Stable identifier for this Mac, generated on first launch.
    func hostID() -> String
}

protocol SessionRecordRepository {
    func load() -> [SessionRecord]
    func save(_ records: [SessionRecord])
}

/// Finds the Claude Code CLI on this Mac.
protocol ClaudeLocating {
    func locate(override: String?) async -> ClaudeInstallation?
}
