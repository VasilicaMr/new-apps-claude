import MapKit
import SwiftUI

struct LiveMapView: View {
    @Environment(FleetStore.self) private var store
    @Environment(LiveTrackingStore.self) private var live
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 44.44, longitude: 26.09),
        span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14)))
    @State private var selectedVehicleId: String?
    @State private var showEventLog = false

    var body: some View {
        NavigationStack {
            Map(position: $camera, selection: $selectedVehicleId) {
                ForEach(store.snapshot?.geofences ?? []) { fence in
                    MapCircle(center: fence.center.clLocation, radius: fence.radiusMeters)
                        .foregroundStyle(color(for: fence.type).opacity(0.15))
                        .stroke(color(for: fence.type), lineWidth: 1)
                    Annotation(fence.name, coordinate: fence.center.clLocation, anchor: .center) {
                        Image(systemName: fence.type == .depot ? "building.2" : fence.type == .restricted ? "nosign" : "mappin")
                            .font(.caption2).foregroundStyle(color(for: fence.type))
                    }
                }

                if let selectedVehicleId {
                    let trail = live.events(for: selectedVehicleId).map(\.coordinate.clLocation)
                    if trail.count > 1 {
                        MapPolyline(coordinates: trail).stroke(Theme.accent, lineWidth: 3)
                    }
                    ForEach(live.events(for: selectedVehicleId).prefix(40)) { event in
                        Annotation("", coordinate: event.coordinate.clLocation) {
                            Circle().fill(Theme.accent).frame(width: 6, height: 6)
                        }
                    }
                }

                ForEach(store.snapshot?.vehicles ?? []) { vehicle in
                    if let position = live.positions[vehicle.id] ?? store.snapshot?.telemetry(for: vehicle.id).map(VehiclePosition.init) {
                        let status = LiveStatus(vehicle: vehicle, position: live.positions[vehicle.id])
                        Annotation(vehicle.plate, coordinate: position.coordinate.clLocation) {
                            VehicleMarker(status: status, isSelected: selectedVehicleId == vehicle.id)
                        }
                        .tag(vehicle.id)
                    }
                }
            }
            .mapControls { MapCompass(); MapScaleView() }
            .safeAreaInset(edge: .bottom) { bottomPanel }
            .navigationTitle("Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(live.isRunning ? "Pause" : "Resume", systemImage: live.isRunning ? "pause.fill" : "play.fill") {
                        live.isRunning ? live.stop() : live.start()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Event log", systemImage: "list.bullet.rectangle") { showEventLog = true }
                }
            }
            .sheet(isPresented: $showEventLog) { LocationEventLogView() }
            .navigationDestination(for: String.self) { VehicleDetailView(vehicleId: $0) }
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let id = selectedVehicleId, let vehicle = store.snapshot?.vehicle(id: id) {
                selectedVehicleCard(vehicle)
            } else {
                filterStats
            }
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: Theme.cornerRadius))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var filterStats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Recording a point every \(live.thresholdMeters.meters) of movement", systemImage: "scope")
                .font(.subheadline.weight(.semibold))
            HStack {
                stat("\(live.samplesReceived)", "GPS samples")
                stat("\(live.eventsReported)", "points stored")
                stat(live.suppressedShare.percentString, "filtered out")
            }
            Text("Tap a vehicle to see its trail.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func selectedVehicleCard(_ vehicle: Vehicle) -> some View {
        let position = live.positions[vehicle.id]
        let status = LiveStatus(vehicle: vehicle, position: position)
        let lastEvent = live.events(for: vehicle.id).first
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(vehicle.plate).font(.headline)
                Text(vehicle.displayName).foregroundStyle(.secondary)
                Spacer()
                StatusBadge(text: status.rawValue, color: status.color)
            }
            HStack {
                stat(position.map { "\(Int($0.speedKmh)) km/h" } ?? "—", "speed")
                stat("\(live.events(for: vehicle.id).count)", "trail points")
                stat(lastEvent.map { $0.timestamp.formatted(date: .omitted, time: .shortened) } ?? "—", "last move")
            }
            NavigationLink(value: vehicle.id) {
                Label("Open vehicle details", systemImage: "chevron.right").font(.subheadline)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading) {
            Text(value).font(.headline.monospacedDigit()).contentTransition(.numericText())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for type: GeofenceType) -> Color {
        switch type {
        case .depot: .blue
        case .client: .teal
        case .restricted: .red
        }
    }
}

private struct VehicleMarker: View {
    let status: LiveStatus
    let isSelected: Bool

    var body: some View {
        Image(systemName: "car.fill")
            .font(.system(size: isSelected ? 16 : 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(isSelected ? 9 : 6)
            .background(status.color, in: .circle)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 2)
            .animation(.snappy, value: isSelected)
    }
}

struct LocationEventLogView: View {
    @Environment(FleetStore.self) private var store
    @Environment(LiveTrackingStore.self) private var live
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Only movements of at least \(live.thresholdMeters.meters) (or a heartbeat every 5 minutes while parked) are stored and sent to the server. Everything else is discarded on the device.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(live.events) { event in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(store.snapshot?.vehicle(id: event.vehicleId)?.plate ?? event.vehicleId).font(.subheadline.weight(.semibold))
                            Text(String(format: "%.5f, %.5f", event.coordinate.latitude, event.coordinate.longitude))
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(event.timestamp.formatted(date: .omitted, time: .standard)).font(.caption)
                            Text(reason(event)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Location events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func reason(_ event: LocationEvent) -> String {
        switch event.reason {
        case .firstFix: "first fix"
        case .movedBeyondThreshold: "+\(event.distanceFromPreviousMeters?.meters ?? "")"
        case .heartbeat: "heartbeat"
        }
    }
}

extension GeoCoordinate {
    var clLocation: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

extension VehiclePosition {
    init(_ telemetry: TelemetrySnapshot) {
        self.init(vehicleId: telemetry.vehicleId, coordinate: telemetry.coordinate,
                  speedKmh: telemetry.speedKmh, timestamp: telemetry.timestamp)
    }
}
