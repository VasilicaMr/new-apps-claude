import Foundation

/// What the model is told about the listing when it writes a social post caption.
struct PostCaptionRequest: Equatable {
    var propertyInfo: PropertyInfo
    /// The rooms in the order the video shows them, consecutive repeats collapsed.
    var roomOrder: [String]
    var agentName: String?
    var brokerage: String?
    /// Set for an open house post: its date and time, already formatted.
    var openHouseWhen: String?
}

/// The parts of a caption the model writes. The facts (address, price, open house time,
/// contact) are added by `WritePostCaptionUseCase`, never by the model, so they're exact.
struct PostCaption: Equatable {
    /// One scroll-stopping opening line.
    var hook: String
    /// Two or three short sentences about the home.
    var body: String
    var hashtags: [String]
}

/// Writes the caption posted alongside the video. Domain owns the interface; the
/// on-device Apple Intelligence model lives in Data.
protocol PostCaptionWriter {
    /// False where Apple Intelligence isn't available; the app falls back to a plain caption.
    var isAvailable: Bool { get }
    func writeCaption(for request: PostCaptionRequest) async throws -> PostCaption
}

enum PostCaptionError: LocalizedError, Equatable {
    case unavailable
    case refused
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: "Writing captions needs Apple Intelligence, which isn't available on this device.")
        case .refused:
            return String(localized: "Couldn't write a caption from these details. Try rewording the headline.")
        case .failed:
            return String(localized: "Couldn't write the caption. Please try again.")
        }
    }
}
