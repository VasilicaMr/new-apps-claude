import SwiftUI

@main
struct CodeRelayApp: App {
    @State private var container = AppContainer.live()
    @AppStorage(PreferenceKeys.hasOnboarded) private var hasOnboarded = false

    init() {
        UserDefaults.standard.register(defaults: [
            PreferenceKeys.autoSuggest: true,
            PreferenceKeys.autoTitle: true,
            PreferenceKeys.haptics: true,
            PreferenceKeys.fontSize: 14.0
        ])
    }

    var body: some Scene {
        WindowGroup {
            HostsView(viewModel: container.makeHostsViewModel())
                .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })) {
                    OnboardingView { hasOnboarded = true }
                }
                .environment(container)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
