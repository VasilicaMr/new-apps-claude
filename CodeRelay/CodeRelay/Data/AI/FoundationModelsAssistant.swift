import Foundation
import FoundationModels

/// Apple Intelligence features powered by the on-device Foundation Models
/// framework. Nothing here leaves the phone.
@MainActor
final class FoundationModelsAssistant: AIAssistant {
    /// The on-device model has a small context window; keep inputs well under it.
    static let maxInputCharacters = 6_000

    private let model = SystemLanguageModel.default

    var availability: AIAvailability {
        switch model.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .unavailable("This device doesn't support Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Turn on Apple Intelligence in Settings to use these features.")
        case .unavailable(.modelNotReady):
            return .unavailable("Apple Intelligence is still getting ready. Try again soon.")
        case .unavailable:
            return .unavailable("Apple Intelligence is unavailable.")
        }
    }

    func refine(prompt: String, projectName: String) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You rewrite rough notes into a clear, specific instruction for an AI coding agent \
            working in the software project "\(projectName)". Keep the user's intent and any \
            file names, commands or identifiers exactly. Do not invent requirements. \
            Reply with only the rewritten instruction, no preamble.
            """)
        return try await session.respond(to: clip(prompt)).content
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func summarize(transcript: String) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You summarise a coding session between a developer (USER) and an AI coding agent \
            (CLAUDE). Write 3 to 6 short bullet points: what was asked, what changed, and \
            anything left to do. Be factual; only use information in the transcript.
            """)
        return try await session.respond(to: clip(transcript)).content
    }

    func suggestFollowUps(transcript: String) async throws -> [String] {
        let session = LanguageModelSession(instructions: """
            You suggest what a developer could ask their AI coding agent next, based on the \
            end of their session transcript. Suggestions are short imperative instructions.
            """)
        let response = try await session.respond(to: clip(transcript), generating: FollowUpSuggestions.self)
        return response.content.suggestions.filter { !$0.isEmpty }
    }

    func explain(toolName: String, detail: String) async throws -> String {
        let session = LanguageModelSession(instructions: """
            An AI coding agent is asking permission to run a tool on the developer's Mac. \
            Explain in two plain-English sentences what will happen and note any risk \
            (deleting files, network access, installing software, pushing code). \
            Do not tell the user what to decide.
            """)
        return try await session.respond(to: clip("Tool: \(toolName)\nInput:\n\(detail)")).content
    }

    func title(for transcript: String) async throws -> String {
        let session = LanguageModelSession(instructions: "You name coding sessions.")
        let response = try await session.respond(to: clip(transcript), generating: SessionTitle.self)
        return response.content.title
    }

    private func clip(_ text: String) -> String {
        String(text.suffix(Self.maxInputCharacters))
    }
}

@Generable
struct FollowUpSuggestions {
    @Guide(description: "Three distinct next instructions, each under 10 words", .count(3))
    var suggestions: [String]
}

@Generable
struct SessionTitle {
    @Guide(description: "A 2 to 5 word title describing the coding task, no punctuation at the end")
    var title: String
}
