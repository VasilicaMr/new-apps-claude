#if os(iOS)
import UIKit

@MainActor
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
#else
/// Apple TV has no haptics; keeps shared view models platform-neutral.
@MainActor
enum Haptics {
    enum FeedbackStyle { case light, medium, heavy, soft, rigid }

    static func impact(_ style: FeedbackStyle = .medium) {}
    static func error() {}
    static func success() {}
    static func selection() {}
}
#endif
