import Foundation

/// Replays the recorded routes from `live_routes.json` as if the vehicles were driving now.
/// Swap for a WebSocket/MQTT stream from your telematics provider in production.
struct SimulatedPositionStream: LivePositionStreaming {
    let routes: [LiveRoute]
    /// 1.0 = real time. Higher values make the demo move faster.
    var speedMultiplier: Double = 1

    func positions() -> AsyncStream<VehiclePosition> {
        let routes = routes.filter { !$0.points.isEmpty }
        let tick = (routes.map(\.tickSeconds).min() ?? 2) / max(speedMultiplier, 0.01)
        return AsyncStream { continuation in
            let task = Task {
                var step = 0
                while !Task.isCancelled {
                    let now = Date()
                    for route in routes {
                        let index = step % route.points.count
                        let previous = route.points[(index + route.points.count - 1) % route.points.count]
                        let point = route.points[index]
                        let current = GeoCoordinate(latitude: point[0], longitude: point[1])
                        let metersPerTick = GeoCoordinate(latitude: previous[0], longitude: previous[1]).distance(to: current)
                        continuation.yield(VehiclePosition(
                            vehicleId: route.vehicleId, coordinate: current,
                            speedKmh: metersPerTick / route.tickSeconds * 3.6, timestamp: now))
                    }
                    step += 1
                    try? await Task.sleep(for: .seconds(tick))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
