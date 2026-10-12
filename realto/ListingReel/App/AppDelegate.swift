import UIKit
import FirebaseCore
import FirebaseAnalytics

/// Bootstraps Firebase (Crashlytics + Analytics) before the SwiftUI app
/// builds its scene. Hooked in via `@UIApplicationDelegateAdaptor` in
/// `ListingReelApp` since SwiftUI's `App` protocol has no launch hook of
/// its own that runs early enough for `FirebaseApp.configure()`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
//        FirebaseApp.configure()

        #if DEBUG
        // Verifies the Analytics pipeline end to end: launch with
        // `-LogDemoAnalyticsEvent -FIRDebugEnabled` and the event shows up in
        // Firebase console → Analytics → DebugView within a few seconds.
        if ProcessInfo.processInfo.arguments.contains("-LogDemoAnalyticsEvent") {
            Analytics.logEvent("realto_demo_event", parameters: ["source": "debug_launch"])
        }
        #endif
        return true
    }
}
