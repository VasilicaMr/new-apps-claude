import Foundation
import FoundationModels
import Observation
import SwiftData

/// The "Ask" assistant: questions about earnings, costs and papers, and adding entries by typing or dictating.
///
/// - Suggestion chips are answered instantly from DriverData (no model call).
/// - Free text goes to Apple Intelligence with tools over the driver's data, streamed as it is written.
/// - Without Apple Intelligence (or if it fails), `AssistantCommandParser` understands the common requests.
@MainActor
@Observable
final class Assistant {
    struct Message: Identifiable, Equatable {
        enum Role { case user, assistant }
        struct Action: Identifiable, Equatable {
            let id: UUID
            let title: String
            var undone = false
        }

        let id = UUID()
        let role: Role
        var text: String
        var actions: [Action] = []
        var usedAppleIntelligence = false
        var isStreaming = false
    }

    private(set) var messages: [Message] = []
    private(set) var isResponding = false

    let data: DriverData
    private let log = AssistantActionLog()
    private var undoModels: [UUID: any PersistentModel] = [:]
    private var session: LanguageModelSession?
    private let parser = AssistantCommandParser()

    init(data: DriverData) {
        self.data = data
    }

    var usesAppleIntelligence: Bool {
        AppleIntelligence.status == .available && UserDefaults.standard.object(forKey: SettingsKeys.useAppleIntelligence) as? Bool ?? true
    }

    /// Loads the model ahead of time so the first answer comes faster.
    func prewarm() {
        guard usesAppleIntelligence else { return }
        makeSessionIfNeeded().prewarm()
    }

    func clear() {
        messages.removeAll()
        session = nil
    }

    /// A suggestion chip: answered from the data right away.
    func ask(_ command: AssistantCommand, title: String) {
        messages.append(Message(role: .user, text: title))
        messages.append(Message(role: .assistant, text: data.answer(command)))
    }

    func send(_ text: String) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding else { return }
        messages.append(Message(role: .user, text: text))
        isResponding = true
        defer { isResponding = false }

        if usesAppleIntelligence, await respondWithModel(to: text) { return }
        respondWithoutModel(to: text)
    }

    /// One-shot answer for Siri.
    func answer(_ text: String) async -> String {
        await send(text)
        return messages.last { $0.role == .assistant }?.text ?? String(localized: "Sorry, I couldn't answer that.")
    }

    func undo(_ action: Message.Action, in message: Message) {
        guard let model = undoModels.removeValue(forKey: action.id),
              let messageIndex = messages.firstIndex(where: { $0.id == message.id }),
              let actionIndex = messages[messageIndex].actions.firstIndex(where: { $0.id == action.id }) else { return }
        data.delete(model)
        messages[messageIndex].actions[actionIndex].undone = true
    }

    // MARK: - Apple Intelligence

    private func respondWithModel(to text: String, retry: Bool = true) async -> Bool {
        let session = makeSessionIfNeeded()
        messages.append(Message(role: .assistant, text: "", usedAppleIntelligence: true, isStreaming: true))
        let index = messages.count - 1
        do {
            for try await snapshot in session.streamResponse(to: text) {
                messages[index].text = snapshot.content
            }
            messages[index].isStreaming = false
            attachActions(to: index)
            return true
        } catch let error as LanguageModelSession.GenerationError {
            messages.remove(at: index)
            attachActions(to: messages.count - 1)
            if case .exceededContextWindowSize = error, retry {
                self.session = nil // long conversation: start fresh, keep the UI history
                return await respondWithModel(to: text, retry: false)
            }
            if case .guardrailViolation = error {
                messages.append(Message(role: .assistant, text: String(localized: "I can only help with your driving, earnings, costs and car.")))
                return true
            }
            return false
        } catch {
            messages.remove(at: index)
            return false
        }
    }

    private func attachActions(to index: Int) {
        let actions = log.drain()
        guard messages.indices.contains(index), !actions.isEmpty else { return }
        for action in actions {
            let id = UUID()
            undoModels[id] = action.model
            messages[index].actions.append(Message.Action(id: id, title: action.title))
        }
    }

    private func makeSessionIfNeeded() -> LanguageModelSession {
        if let session { return session }
        let today = Date.now.formatted(date: .complete, time: .omitted)
        let tools: [any Tool] = [
            GetStatsTool(data: data), GetInsightsTool(data: data), GetRemindersTool(data: data),
            GetRecentEntriesTool(data: data), AddExpenseTool(data: data, log: log), AddEarningsTool(data: data, log: log),
        ]
        let session = LanguageModelSession(tools: tools, instructions: """
            You are DriveCap, the assistant inside a logbook app for a ride-sharing driver (Uber, Bolt). \
            Today is \(today). Money is in \(data.money.currencyCode). \
            Always use the tools for any number, date or total; never guess or invent figures. \
            When the driver says they paid for something or earned money, save it with addExpense or addEarnings \
            immediately without asking for confirmation, then confirm in one short sentence. \
            Answer in one to three short sentences, plain text, no markdown tables. \
            Reply in the same language the driver writes in (English, Romanian or French). \
            If a question is not about driving, earnings, costs, the car or its paperwork, say what you can help with.
            """)
        self.session = session
        return session
    }

    // MARK: - Without Apple Intelligence

    private func respondWithoutModel(to text: String) {
        let command = parser.parse(text)
        var message = Message(role: .assistant, text: "")
        switch command {
        case let .add(entry):
            let model: any PersistentModel = switch entry {
            case let .expense(draft): data.add(draft)
            case let .earning(draft): data.add(draft)
            }
            let id = UUID()
            undoModels[id] = model
            message.text = String(localized: "Saved.")
            message.actions = [Message.Action(id: id, title: String(localized: "Added \(data.describe(entry))"))]
        default:
            message.text = data.answer(command)
        }
        messages.append(message)
    }
}

/// The questions shown as chips; each maps to an instant, exact answer.
struct SuggestedQuestion: Identifiable, Hashable {
    let title: String
    let symbol: String
    let command: AssistantCommand

    var id: String { title }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.title == rhs.title }
    func hash(into hasher: inout Hasher) { hasher.combine(title) }

    static let all: [SuggestedQuestion] = [
        SuggestedQuestion(title: String(localized: "How did I do today?"), symbol: "sun.max", command: .stats(.day, offset: 0)),
        SuggestedQuestion(title: String(localized: "This week vs last week"), symbol: "arrow.left.arrow.right", command: .compare(.week)),
        SuggestedQuestion(title: String(localized: "This month so far"), symbol: "calendar", command: .stats(.month, offset: 0)),
        SuggestedQuestion(title: String(localized: "Which day pays best?"), symbol: "star", command: .bestDay),
        SuggestedQuestion(title: String(localized: "What did I spend this month?"), symbol: "cart", command: .spending(nil, .month, offset: 0)),
        SuggestedQuestion(title: String(localized: "What's due?"), symbol: "bell", command: .reminders),
        SuggestedQuestion(title: String(localized: "Shifts missing earnings"), symbol: "exclamationmark.circle", command: .missingEarnings),
    ]
}
