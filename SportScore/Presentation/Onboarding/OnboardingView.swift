import SwiftUI

/// First-launch tutorial: a few swipeable pages, then the Premium screen with what can be bought.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0
    @State private var showsPremium = false

    private let pages: [Onboarding.Page] = [
        .init(icon: "sportscourt.fill",
              title: "Pick your sport",
              message: "Real scoring rules for 48 sports, from darts and pool to tennis and chess."),
        .init(icon: "hand.tap.fill",
              title: "Score with a tap",
              message: "Tap a player to add points. Made a mistake? Undo the last entry anytime."),
        .init(icon: "trophy.fill",
              title: "Crown the champion",
              message: "Every game is saved to History, and Stats shows who really wins."),
    ]

    var body: some View {
        if showsPremium {
            PaywallView(onClose: onFinish)
                .transition(.move(edge: .trailing))
        } else {
            tutorial
        }
    }

    private var tutorial: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            HStack {
                Spacer()
                Button("Skip") { showPremium() }
                    .foregroundStyle(.secondary)
            }

            TabView(selection: $pageIndex) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageView(page).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if pageIndex < pages.count - 1 {
                    withAnimation { pageIndex += 1 }
                } else {
                    showPremium()
                }
            } label: {
                Text(pageIndex < pages.count - 1 ? "Next" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(AppTheme.Spacing.lg)
    }

    private func pageView(_ page: Onboarding.Page) -> some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: page.icon)
                .font(.system(size: 88))
                .foregroundStyle(.tint)
            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(page.message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.xl * 2) // clear of the page dots
    }

    /// Users who already own Premium (e.g. after reinstalling) go straight into the app.
    private func showPremium() {
        if PremiumManager.shared.isPremium {
            onFinish()
        } else {
            withAnimation { showsPremium = true }
        }
    }
}
