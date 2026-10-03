import Foundation
import FoundationModels

/// `PostCaptionWriter` backed by the on-device Apple Intelligence language model. It writes
/// only the hook, description and hashtags; the facts are added by `WritePostCaptionUseCase`.
@available(iOS 26.0, macOS 26.0, *)
final class FoundationModelsPostCaptionWriter: PostCaptionWriter {

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func writeCaption(for request: PostCaptionRequest) async throws -> PostCaption {
        guard isAvailable else { throw PostCaptionError.unavailable }

        let language = Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en")
            ?? "English"
        let session = LanguageModelSession(instructions: """
            You write Instagram and TikTok captions for real estate agents' listing reels. \
            Short, warm and confident, in the agent's own voice. \
            Use only the facts you're given; never invent features, finishes, views or amenities. \
            Don't repeat the address, price, date or contact details — they're added below your text. \
            \(ListingPromptFacts.fairHousingRule) \
            Write in \(language).
            """)
        do {
            let response = try await session.respond(
                to: Self.prompt(for: request),
                generating: GeneratedCaption.self,
                options: GenerationOptions(temperature: 0.8))
            let generated = response.content
            return PostCaption(hook: generated.hook, body: generated.body, hashtags: generated.hashtags)
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .assetsUnavailable: throw PostCaptionError.unavailable
            case .guardrailViolation, .refusal: throw PostCaptionError.refused
            default: throw PostCaptionError.failed
            }
        }
    }

    private static func prompt(for request: PostCaptionRequest) -> String {
        let facts = ListingPromptFacts.lines(for: request.propertyInfo,
                                             agentName: request.agentName, brokerage: request.brokerage)
        let rooms = request.roomOrder.isEmpty ? "Not specified." : request.roomOrder.joined(separator: ", ")
        let post = request.openHouseWhen.map {
            "This post announces an open house on \($0). Make the reader want to come by."
        } ?? "This post announces a new listing. Make the reader want to see it."

        return """
            Write the caption for a listing reel. \(post)

            Property details:
            \(facts.isEmpty ? "None given." : facts.joined(separator: "\n"))

            Rooms shown in the video: \(rooms)
            """
    }
}

// MARK: - Generable schema

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct GeneratedCaption {
    @Guide(description: "One scroll-stopping opening line, at most 10 words, may end with one emoji")
    var hook: String

    @Guide(description: "Two or three short sentences about the home's highlights, no hashtags")
    var body: String

    @Guide(description: "Relevant hashtags as single words without the # sign, e.g. DreamKitchen", .maximumCount(5))
    var hashtags: [String]
}

/// Used on OS versions without Foundation Models; the app writes a plain caption instead.
struct UnavailablePostCaptionWriter: PostCaptionWriter {
    var isAvailable: Bool { false }

    func writeCaption(for request: PostCaptionRequest) async throws -> PostCaption {
        throw PostCaptionError.unavailable
    }
}
