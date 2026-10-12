import Observation
import SwiftUI

/// Lets any screen jump to the assistant, optionally with a question already asked.
@MainActor
@Observable
final class AppNavigation {
    var selectedTab = AppTab.launchDefault
    /// A question to send as soon as the Ask tab appears.
    var pendingQuestion: String?
    /// A chip to answer as soon as the Ask tab appears.
    var pendingSuggestion: SuggestedQuestion?
    /// Puts the cursor in the Ask field (from the Home "Ask or add anything" bar).
    var focusAsk = false

    func ask(_ question: String? = nil) {
        pendingQuestion = question
        focusAsk = question == nil
        selectedTab = .ask
    }

    func ask(_ suggestion: SuggestedQuestion) {
        pendingSuggestion = suggestion
        selectedTab = .ask
    }
}

enum AppTab: String, Hashable {
    case home, stats, diary, car, ask

    /// Debug builds accept `-initialTab <name>` so screenshots and UI tests can open any tab directly.
    static var launchDefault: AppTab {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "initialTab"), let tab = AppTab(rawValue: raw) { return tab }
        #endif
        return .home
    }
}
