import Foundation
import FoundationModels

/// `VoiceoverScriptWriter` backed by the on-device Apple Intelligence language model.
/// Nothing leaves the device, in keeping with the offline pitch (spec §1.4).
@available(iOS 26.0, macOS 26.0, *)
final class FoundationModelsVoiceoverScriptWriter: VoiceoverScriptWriter {

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func writeScript(for request: VoiceoverScriptRequest) async throws -> String {
        guard isAvailable else { throw VoiceoverScriptError.unavailable }

        let language = Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en")
            ?? "English"
        let session = LanguageModelSession(instructions: """
            You write voiceover narration for short real estate listing videos. \
            The narration is read aloud by a text-to-speech voice over the video, so write \
            plain spoken sentences only: no headings, bullet points, emoji, stage directions, \
            hashtags or quotation marks. Spell prices and numbers the way a person would say them. \
            Warm, confident and concise — like a friendly listing agent giving a quick tour. \
            Use only the facts you're given; never invent features, finishes, views or amenities. \
            \(ListingPromptFacts.fairHousingRule) \
            Write in \(language).
            """)
        do {
            let response = try await session.respond(
                to: Self.prompt(for: request),
                options: GenerationOptions(temperature: 0.7))
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .assetsUnavailable: throw VoiceoverScriptError.unavailable
            case .guardrailViolation, .refusal: throw VoiceoverScriptError.refused
            default: throw VoiceoverScriptError.failed
            }
        }
    }

    private static func prompt(for request: VoiceoverScriptRequest) -> String {
        let facts = ListingPromptFacts.lines(for: request.propertyInfo,
                                             agentName: request.agentName, brokerage: request.brokerage)

        let rooms = request.roomOrder.isEmpty
            ? "Not specified — keep the tour general."
            : request.roomOrder.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let callToAction = request.openHouseWhen.map {
            "an invitation to the open house on \($0) — say the day and time exactly as written"
        } ?? "a short call to action"
        let openHouse = request.openHouseWhen.map {
            "This video announces an open house on \($0). Mention it in the hook.\n"
        } ?? ""

        return """
            Write a \(request.targetSeconds)-second voiceover, about \(request.targetWordCount) words.
            \(openHouse)Open with a hook, walk through the rooms in the order the video shows them, \
            and close with \(callToAction)\(request.agentName == nil ? "" : ", naming the agent").

            Property details:
            \(facts.isEmpty ? "None given." : facts.joined(separator: "\n"))

            Rooms, in video order:
            \(rooms)
            """
    }
}

/// Used where the AI voiceover isn't offered; the UI hides the action entirely.
struct UnavailableVoiceoverScriptWriter: VoiceoverScriptWriter {
    var isAvailable: Bool { false }

    func writeScript(for request: VoiceoverScriptRequest) async throws -> String {
        throw VoiceoverScriptError.unavailable
    }
}
