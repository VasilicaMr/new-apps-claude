import Foundation

protocol APIClient: Sendable {
    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint, as type: Response.Type) async throws -> Response
}

enum APIError: LocalizedError, Equatable {
    case missingMockResource(String)
    case invalidResponse
    case httpStatus(Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case let .missingMockResource(name): "Mock file \(name).json is missing from the app bundle."
        case .invalidResponse: "The server returned an invalid response."
        case let .httpStatus(code): "The server returned HTTP \(code)."
        case let .decoding(detail): "Couldn't read the server data: \(detail)"
        }
    }
}

enum FleetJSON {
    /// Accepts both full timestamps ("2026-10-11T09:30:00Z") and calendar days ("2026-10-11").
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = (try? Date(raw, strategy: .iso8601)) ?? (try? Date(raw, strategy: dayFormat)) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognised date \(raw)")
        }
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// "2026-10-11", in UTC like every other calendar day in the feeds.
    static let dayFormat = Date.ISO8601FormatStyle().year().month().day()
}

extension DecodingError {
    /// Short "vehicles[3].purchaseDate: ..." description, much easier to act on than the default dump.
    var compactDescription: String {
        func path(_ context: Context) -> String {
            context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
        }
        switch self {
        case let .keyNotFound(key, context): return "missing \(path(context)).\(key.stringValue)"
        case let .typeMismatch(_, context), let .valueNotFound(_, context), let .dataCorrupted(context):
            return "\(path(context)): \(context.debugDescription)"
        @unknown default: return localizedDescription
        }
    }
}
