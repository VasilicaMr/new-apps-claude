import Foundation

/// Drafts the ~30-second AI voiceover from the property details and the clips' room order.
struct WriteVoiceoverScriptUseCase {
    let writer: VoiceoverScriptWriter

    static let targetSeconds = 30
    /// Relaxed real-estate narration runs ~2.3 words/second; leaves room for pauses.
    static let wordsPerSecond = 2.3

    var isAvailable: Bool { writer.isAvailable }

    func makeRequest(project: Project, brand: BrandProfile?) -> VoiceoverScriptRequest {
        VoiceoverScriptRequest(
            propertyInfo: project.propertyInfo,
            roomOrder: Self.roomOrder(of: project),
            agentName: brand?.agentName.nilIfBlank,
            brokerage: brand?.brokerage?.nilIfBlank,
            targetSeconds: Self.targetSeconds,
            targetWordCount: Int((Double(Self.targetSeconds) * Self.wordsPerSecond).rounded()),
            openHouseWhen: project.openHouse?.spokenWhen())
    }

    func write(project: Project, brand: BrandProfile?) async throws -> String {
        guard writer.isAvailable else { throw VoiceoverScriptError.unavailable }
        let request = makeRequest(project: project, brand: brand)
        guard request.propertyInfo.filledFieldCount > 0 || !request.roomOrder.isEmpty else {
            throw VoiceoverScriptError.missingDetails
        }
        let script = try await writer.writeScript(for: request)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !script.isEmpty else { throw VoiceoverScriptError.failed }
        return script
    }

    /// Labelled clips in playback order, e.g. two kitchen clips in a row read as one "Kitchen".
    static func roomOrder(of project: Project) -> [String] {
        var rooms: [String] = []
        for label in project.orderedClips.compactMap({ $0.roomLabel?.nilIfBlank }) where rooms.last != label {
            rooms.append(label)
        }
        return rooms
    }

    /// Rough spoken length, for the "≈ 28 s" hint under the script editor.
    static func estimatedSeconds(of script: String) -> Int {
        let words = script.split(whereSeparator: { $0.isWhitespace }).count
        return Int((Double(words) / wordsPerSecond).rounded())
    }
}

extension String {
    /// nil for empty or whitespace-only strings, otherwise the trimmed string.
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
