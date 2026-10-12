import SwiftUI

struct SettingsView: View {
    @Environment(FleetStore.self) private var store
    @Environment(LiveTrackingStore.self) private var live
    @Environment(DriverModeStore.self) private var driverMode
    @AppStorage(SettingsKeys.thresholdMeters) private var thresholdMeters = 50.0
    @AppStorage(SettingsKeys.lowPowerTracking) private var lowPowerTracking = false
    @AppStorage(SettingsKeys.hasSeenTutorial) private var hasSeenTutorial = true

    var body: some View {
        NavigationStack {
            Form {
                if let company = store.snapshot?.company {
                    Section("Company") {
                        LabeledContent("Name", value: company.name)
                        LabeledContent("Currency", value: company.currencyCode)
                        LabeledContent("Home base", value: company.homeBase.name)
                        LabeledContent("Data as of", value: company.dataAsOf.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("Data source", value: "Mock (local JSON)")
                    }
                }

                Section {
                    VStack(alignment: .leading) {
                        LabeledContent("Record a point every", value: thresholdMeters.meters)
                        Slider(value: $thresholdMeters, in: 25...300, step: 25)
                    }
                    Toggle("Ultra low power", isOn: $lowPowerTracking)
                } header: {
                    Text("Location tracking")
                } footer: {
                    Text("50 m is a good balance: precise enough to see where a car went, coarse enough that the phone mostly relies on Wi-Fi and cell towers instead of continuous GPS. Ultra low power uses iOS significant-change monitoring (~500 m) and costs almost no battery.")
                }

                Section {
                    Toggle("Track this iPhone as a vehicle", isOn: Binding(
                        get: { driverMode.isTracking },
                        set: { $0 ? driverMode.start(thresholdMeters: thresholdMeters, lowPower: lowPowerTracking) : driverMode.stop() }))
                    LabeledContent("Permission", value: driverMode.authorizationDescription)
                    if driverMode.isTracking {
                        LabeledContent("GPS fixes received", value: "\(driverMode.rawFixes)")
                        LabeledContent("Points stored", value: "\(driverMode.events.count)")
                        if let location = driverMode.lastLocation {
                            LabeledContent("Last fix", value: String(format: "%.5f, %.5f (±%.0f m)",
                                                                     location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy))
                        }
                    }
                } header: {
                    Text("Driver mode")
                } footer: {
                    Text("For drivers without a telematics box: the phone reports its position whenever it moves more than the distance above. Choose \"Always\" when iOS asks so tracking continues in the background.")
                }

                Section("Live feed (simulated)") {
                    LabeledContent("Status", value: live.isRunning ? "Running" : "Paused")
                    LabeledContent("Samples / stored", value: "\(live.samplesReceived) / \(live.eventsReported)")
                    if let error = live.lastError { Text(error).foregroundStyle(.red).font(.caption) }
                }

                Section {
                    Button("Show tutorial again", systemImage: "graduationcap") { hasSeenTutorial = false }
                    Button("Reload data", systemImage: "arrow.clockwise") { Task { await store.reload() } }
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .onChange(of: thresholdMeters) { _, _ in restartDriverModeIfNeeded() }
            .onChange(of: lowPowerTracking) { _, _ in restartDriverModeIfNeeded() }
        }
    }

    private func restartDriverModeIfNeeded() {
        guard driverMode.isTracking else { return }
        driverMode.start(thresholdMeters: thresholdMeters, lowPower: lowPowerTracking)
    }
}
