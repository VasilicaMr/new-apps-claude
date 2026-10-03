import SwiftUI

/// @main composition root (spec §3.3). Builds the DI container once and hands it
/// to the coordinator-driven root view.
@main
struct ListingReelApp: App {
    // Registers AppDelegate so FirebaseApp.configure() runs at launch
    // (spec app protocol has no earlier hook for this). iOS only — Firebase
    // isn't linked on macOS (FirebaseAnalytics doesn't support the platform).
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @State private var container = DIContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                #if os(macOS)
                // The wizard UI was designed for phone-portrait layouts; give the
                // Mac window a sane minimum instead of a full desktop redesign.
                .frame(minWidth: 480, minHeight: 720)
                #endif
        }
        #if os(macOS)
        // Mac Inbox (feature-flagged, off by default — see DIContainer.inboxModel):
        // the flag toggle + watched-folder picker live in the standard ⌘,
        // Settings scene, and the batch-management surface is its own window
        // rather than a case in the wizard's `AppRoute` (it isn't part of an
        // editing session — spec §3.7).
        //
        // The Settings scene (and thus the flag toggle) is DEBUG-only for now —
        // not ready to expose to prod users. Everything else about the feature
        // (DIContainer wiring, the Inbox window, Home's toolbar button) is
        // untouched, so re-enabling for release later is just deleting this
        // #if/#endif pair.
        #if DEBUG
        Settings {
            MacInboxSettingsView(model: container.inboxModel)
        }
        #endif
        Window("Inbox", id: "mac-inbox") {
            InboxWindowView(model: container.inboxModel)
        }
        .defaultSize(width: 520, height: 480)
        #endif
    }
}
