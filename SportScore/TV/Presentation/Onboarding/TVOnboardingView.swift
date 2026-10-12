import SwiftUI

/// First-launch tutorial for Apple TV: a few pages stepped through with Continue, then the
/// Premium screen with what can be bought. Menu goes back a page.
struct TVOnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0
    @State private var showsPremium = false
    @FocusState private var continueFocused: Bool

    private let pages: [Onboarding.Page] = [
        .init(icon: "square.grid.2x2.fill",
              title: "Pick any game",
              message: "Card, board and party games, 48 sports with real scoring rules, or your own house rules."),
        .init(icon: "appletvremote.gen4.fill",
              title: "Score with the remote",
              message: "Click a player to give them a point, or enter points each turn. Play/Pause undoes the last entry."),
        .init(icon: "trophy.fill",
              title: "Crown the champion",
              message: "Every game is saved to History, and Stats shows who really wins."),
    ]

    var body: some View {
        if showsPremium {
            TVPaywallView(onClose: onFinish)
                .onExitCommand { showsPremium = false }
        } else {
            tutorial
        }
    }

    private var tutorial: some View {
        let page = pages[pageIndex]
        return VStack(spacing: 40) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 140, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(height: 180)
            Text(page.title)
                .font(.system(size: 64, weight: .heavy, design: .rounded))
            Text(page.message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 1100)

            HStack(spacing: 16) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == pageIndex ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.top, 10)

            Spacer()

            HStack(spacing: 40) {
                Button("Skip") { showPremium() }
                Button {
                    if pageIndex < pages.count - 1 {
                        withAnimation { pageIndex += 1 }
                    } else {
                        showPremium()
                    }
                } label: {
                    Text(pageIndex < pages.count - 1 ? "Next" : "Continue")
                        .frame(minWidth: 300)
                }
                .buttonStyle(.borderedProminent)
                .focused($continueFocused)
            }
        }
        .padding(80)
        .defaultFocus($continueFocused, true)
        .onExitCommand(perform: pageIndex > 0 ? { withAnimation { pageIndex -= 1 } } : nil)
    }

    /// Users who already own Premium (e.g. a new Apple TV) go straight into the app.
    private func showPremium() {
        if PremiumManager.shared.isPremium {
            onFinish()
        } else {
            showsPremium = true
        }
    }
}
