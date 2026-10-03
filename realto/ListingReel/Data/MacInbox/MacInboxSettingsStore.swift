import Foundation

/// Persists the Mac Inbox feature flag + watched folder as JSON in the
/// app-support directory — same shape as `FileBrandProfileRepository`.
/// Deliberately its own tiny store rather than `UserDefaults`: nothing else
/// in the app uses `UserDefaults` today, and keeping the flag's storage in
/// the same "MacInbox" folder as everything else this feature touches keeps
/// it trivially removable if the feature is ever pulled.
actor MacInboxSettingsStore: MacInboxSettingsRepository {

    private let fileManager = FileManager.default
    private var settingsURL: URL { MacInboxPaths.baseDirectory.appendingPathComponent("settings.json") }

    func load() async throws -> MacInboxSettings {
        guard let data = try? Data(contentsOf: settingsURL) else { return MacInboxSettings() }
        return (try? JSONDecoder().decode(MacInboxSettings.self, from: data)) ?? MacInboxSettings()
    }

    func save(_ settings: MacInboxSettings) async throws {
        try fileManager.createDirectory(at: MacInboxPaths.baseDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }
}
