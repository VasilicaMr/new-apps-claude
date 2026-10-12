import Foundation

/// Read/write access to fleet data. The app only talks to this protocol, so swapping
/// the mock JSON backend for a real API (or a telematics vendor) touches only the Data layer.
protocol FleetRepository: Sendable {
    func loadSnapshot() async throws -> FleetSnapshot
    func liveRoutes() async throws -> [LiveRoute]
    @discardableResult
    func report(_ events: [LocationEvent]) async throws -> LocationEventAck
}

/// Push-style live position feed (WebSocket / MQTT in production, a replayed route in mock mode).
protocol LivePositionStreaming: Sendable {
    func positions() -> AsyncStream<VehiclePosition>
}
