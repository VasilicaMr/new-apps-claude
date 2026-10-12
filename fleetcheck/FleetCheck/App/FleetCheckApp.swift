import SwiftUI

@main
struct FleetCheckApp: App {
    @State private var fleetStore: FleetStore
    @State private var liveStore: LiveTrackingStore
    @State private var driverMode: DriverModeStore

    init() {
        let dependencies: AppDependencies = ProcessInfo.processInfo.arguments.contains("-uiTesting") ? .preview : .mock
        _fleetStore = State(initialValue: FleetStore(repository: dependencies.repository))
        _liveStore = State(initialValue: LiveTrackingStore(dependencies: dependencies))
        _driverMode = State(initialValue: DriverModeStore(repository: dependencies.repository))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(fleetStore)
                .environment(liveStore)
                .environment(driverMode)
                .tint(Theme.accent)
        }
    }
}
