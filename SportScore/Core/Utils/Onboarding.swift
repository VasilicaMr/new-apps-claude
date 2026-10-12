import Foundation

/// First-launch tutorial, shared by iOS and Apple TV. Each platform lists its own pages
/// (tap vs. click) and ends the tutorial on its Premium screen.
enum Onboarding {
    /// `@AppStorage` key; set once the user leaves the Premium screen at the end of the tutorial.
    static let completedKey = "hasCompletedOnboarding"

    struct Page: Identifiable {
        let icon: String
        let title: String
        let message: String
        var id: String { title }
    }

    /// UI tests start straight in the app; `--uitesting-onboarding` always shows the tutorial instead.
    static func shouldShow(completed: Bool) -> Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting-onboarding") { return true }
        if arguments.contains(where: { $0.hasPrefix("--uitesting") }) { return false }
        #endif
        return !completed
    }
}
