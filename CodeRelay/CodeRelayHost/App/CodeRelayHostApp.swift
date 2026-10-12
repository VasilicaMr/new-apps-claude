import SwiftUI

@main
struct CodeRelayHostApp: App {
    @State private var engine = HostContainer.makeEngine()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(engine)
        } label: {
            Image(systemName: engine.connectedDeviceIDs.isEmpty ? "terminal" : "terminal.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            HostSettingsView()
                .environment(engine)
        }
    }
}

/// Composition root: the only place that knows concrete implementations.
@MainActor
enum HostContainer {
    static func makeEngine() -> HostEngine {
        let engine = HostEngine(deviceRepository: DefaultsPairedDeviceRepository(),
                                settingsRepository: DefaultsHostSettingsRepository(),
                                sessionRepository: FileSessionRecordRepository(),
                                locator: ClaudeLocator())
        engine.start()
        return engine
    }
}
