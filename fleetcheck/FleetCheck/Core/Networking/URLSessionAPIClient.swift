import Foundation

/// Production client. Point `baseURL` at your backend and pass it to `AppDependencies`
/// instead of `MockAPIClient` — nothing else in the app has to change.
struct URLSessionAPIClient: APIClient {
    let baseURL: URL
    var session: URLSession = .shared
    /// Returns the bearer token for the signed-in owner (Keychain-backed in a real app).
    var authToken: @Sendable () async -> String? = { nil }

    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint, as type: Response.Type) async throws -> Response {
        var components = URLComponents(url: baseURL.appending(path: endpoint.path), resolvingAgainstBaseURL: false)!
        if !endpoint.queryItems.isEmpty { components.queryItems = endpoint.queryItems }

        var request = URLRequest(url: components.url!)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = await authToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = endpoint.body {
            request.httpBody = try FleetJSON.makeEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.httpStatus(http.statusCode) }
        do {
            return try FleetJSON.makeDecoder().decode(Response.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decoding(error.compactDescription)
        }
    }
}
