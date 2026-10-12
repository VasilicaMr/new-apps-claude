import Foundation
import FoundationModels
import Observation

/// The Home screen's short daily brief. Facts are computed by `InsightComposer`; Apple Intelligence
/// rewrites them as two or three friendly sentences with one practical tip. Cached until the data changes.
@MainActor
@Observable
final class BriefStore {
    private(set) var text: String?
    private(set) var insights: [Insight] = []
    private(set) var isWritten = false
    private(set) var isLoading = false

    private var cacheKey: String?

    func refresh(using data: DriverData, useAppleIntelligence: Bool) async {
        let insights = data.insights()
        self.insights = insights
        let facts = insights.map(\.text)
        let key = Calendar.current.startOfDay(for: .now).description + facts.joined()
        guard key != cacheKey else { return }
        cacheKey = key

        guard useAppleIntelligence, AppleIntelligence.status == .available, !facts.isEmpty else {
            text = nil
            isWritten = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let session = LanguageModelSession(instructions: """
                You write a short daily brief for a ride-sharing driver, shown on the home screen of their logbook app. \
                Use only the facts given; keep every number exactly as written. Two or three short sentences, \
                second person, warm and practical, no greeting, no emojis, no lists. End with one concrete tip based on the facts.
                """)
            let response = try await session.respond(to: "Facts:\n" + facts.map { "- \($0)" }.joined(separator: "\n"))
            text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            isWritten = true
        } catch {
            text = nil
            isWritten = false
            cacheKey = nil
        }
    }
}
