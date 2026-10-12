import Foundation

/// Serves every endpoint from a bundled JSON file, with a little latency so loading
/// states are visible. Behaves like the real client: same decoding, same errors.
struct MockAPIClient: APIClient {
    var bundle: Bundle = .main
    var latency: Duration = .milliseconds(350)

    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint, as type: Response.Type) async throws -> Response {
        if latency > .zero { try await Task.sleep(for: latency) }
        guard let url = bundle.url(forResource: endpoint.mockResource, withExtension: "json") else {
            throw APIError.missingMockResource(endpoint.mockResource)
        }
        let data = try Data(contentsOf: url)
        do {
            return try FleetJSON.makeDecoder().decode(Response.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decoding("\(endpoint.mockResource).json \(error.compactDescription)")
        }
    }
}
