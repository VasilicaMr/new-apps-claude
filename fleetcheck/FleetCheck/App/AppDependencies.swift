import Foundation

/// Composition root: the only place that decides which concrete implementations the app uses.
/// To go live, replace `MockAPIClient()` with
/// `URLSessionAPIClient(baseURL: URL(string: "https://api.yourfleet.com")!)`
/// and the simulated stream with your telematics provider's WebSocket feed.
struct AppDependencies: Sendable {
    let repository: any FleetRepository
    let makePositionStream: @Sendable ([LiveRoute]) -> any LivePositionStreaming

    static let mock = AppDependencies(
        repository: DefaultFleetRepository(client: MockAPIClient()),
        makePositionStream: { SimulatedPositionStream(routes: $0) }
    )

    /// No latency: used by UI tests and previews.
    static let preview = AppDependencies(
        repository: DefaultFleetRepository(client: MockAPIClient(latency: .zero)),
        makePositionStream: { SimulatedPositionStream(routes: $0, speedMultiplier: 4) }
    )
}
