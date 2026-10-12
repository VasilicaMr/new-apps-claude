import Foundation
import Observation
import RelayKit

@MainActor
@Observable
final class SessionViewModel {
    var summary: SessionSummary
    var isConnected = false
    var draft = ""
    private(set) var transcript = TranscriptReducer()
    private(set) var suggestions: [String] = []
    private(set) var isRefining = false
    private(set) var isSummarizing = false
    private(set) var explaining: Set<String> = []
    private(set) var explanations: [String: String] = [:]
    var sessionSummaryText: String?
    var aiError: String?

    let assistant: AIAssistant
    @ObservationIgnored private let send: (ClientMessage) -> Void
    @ObservationIgnored private var hasAutoTitled = false

    init(summary: SessionSummary, assistant: AIAssistant, send: @escaping (ClientMessage) -> Void) {
        self.summary = summary
        self.assistant = assistant
        self.send = send
        hasAutoTitled = summary.title != "New session"
    }

    var aiAvailable: Bool { assistant.availability.isAvailable }
    var canSend: Bool { isConnected && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: Host events

    func replay(_ events: [ClaudeEvent]) {
        transcript.reset()
        events.forEach { transcript.apply($0) }
    }

    func apply(_ event: ClaudeEvent) {
        transcript.apply(event)
        if case .turnCompleted(let isError, _, _) = event, !isError {
            Task { await afterTurn() }
        }
    }

    // MARK: User actions

    func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        send(.prompt(sessionID: summary.id, text: text))
        draft = ""
        suggestions = []
    }

    func use(suggestion: String) {
        draft = suggestion
        suggestions = []
    }

    func decide(_ prompt: PermissionPrompt, allow: Bool) {
        transcript.markPermission(id: prompt.id, allowed: allow)
        send(.permissionDecision(sessionID: summary.id, requestID: prompt.id, allow: allow))
    }

    func interrupt() {
        send(.interrupt(sessionID: summary.id))
    }

    func rename(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hasAutoTitled = true
        send(.renameSession(sessionID: summary.id, title: trimmed))
    }

    // MARK: Apple Intelligence

    func refineDraft() async {
        guard aiAvailable, !draft.isEmpty else { return }
        isRefining = true
        defer { isRefining = false }
        do {
            draft = try await assistant.refine(prompt: draft, projectName: summary.projectName)
        } catch {
            aiError = error.localizedDescription
        }
    }

    func summarizeSession() async {
        guard aiAvailable else { return }
        isSummarizing = true
        defer { isSummarizing = false }
        do {
            sessionSummaryText = try await assistant.summarize(transcript: transcript.plainText(limit: 6_000))
        } catch {
            aiError = error.localizedDescription
        }
    }

    func explain(_ prompt: PermissionPrompt) async {
        guard aiAvailable, !explaining.contains(prompt.id) else { return }
        explaining.insert(prompt.id)
        defer { explaining.remove(prompt.id) }
        do {
            explanations[prompt.id] = try await assistant.explain(toolName: prompt.toolName, detail: prompt.detail)
        } catch {
            aiError = error.localizedDescription
        }
    }

    private func afterTurn() async {
        guard aiAvailable else { return }
        let defaults = UserDefaults.standard
        let context = transcript.plainText(limit: 3_000)
        if defaults.bool(forKey: PreferenceKeys.autoTitle), !hasAutoTitled {
            hasAutoTitled = true
            if let title = try? await assistant.title(for: context), !title.isEmpty {
                send(.renameSession(sessionID: summary.id, title: title))
            }
        }
        if defaults.bool(forKey: PreferenceKeys.autoSuggest) {
            suggestions = (try? await assistant.suggestFollowUps(transcript: context)) ?? []
        }
    }
}
