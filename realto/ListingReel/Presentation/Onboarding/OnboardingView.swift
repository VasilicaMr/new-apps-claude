import SwiftUI

/// First-launch onboarding — shown once, gated by `RootView`'s
/// `hasCompletedOnboarding` flag. Purely informational: no sign-up, no
/// permission prompts, nothing that could gate reaching "New Video" (spec §6
/// design rule — "the empty-state should invite 'New Video,' not 'Sign up'").
/// Permissions (Photos, camera, mic) stay requested lazily at the point of
/// use, same as today — this just sets expectations before Home appears.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    /// One case per page, declared in display order. The Mac Inbox page only
    /// exists on macOS — `Page.allCases` (and therefore every index derived
    /// from it below) automatically drops it on iOS, so there's no separate
    /// page-count bookkeeping to keep in sync by hand.
    private enum Page: CaseIterable {
        case welcome
        case howItWorks
        #if os(macOS)
        case macInbox
        #endif
        case ready
    }

    private var pages: [Page] { Page.allCases }

    var body: some View {
        VStack(spacing: 0) {
            StepProgressBar(current: pageIndex + 1, total: pages.count)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.l)

            ScrollView {
                content(for: pages[pageIndex])
                    .padding(Theme.Spacing.l)
                    .frame(maxWidth: .infinity)
            }
            .animation(.default, value: pageIndex)

            footer
                .padding(Theme.Spacing.l)
                .background(.ultraThinMaterial)
        }
        .screenBackground()
    }

    @ViewBuilder
    private func content(for page: Page) -> some View {
        switch page {
        case .welcome: welcomePage
        case .howItWorks: howItWorksPage
        #if os(macOS)
        case .macInbox: macInboxPage
        #endif
        case .ready: readyPage
        }
    }

    // MARK: - Welcome

    private var welcomePage: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: Theme.Spacing.xl)
            GradientIconBadge(systemImage: "house.and.flag.fill", size: 96)
                .shadow(color: Theme.Palette.accent.opacity(0.25), radius: 16, y: 8)
            Text("Welcome to Realto")
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Turn raw walkthroughs into\nbranded listing videos")
                .multilineTextAlignment(.center)
                .font(.title3)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("No account. Nothing uploaded — everything renders right here on your device.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer(minLength: Theme.Spacing.xl)
        }
    }

    // MARK: - How it works

    private var howItWorksPage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            SectionHeader(title: "How it works", subtitle: "Three steps, start to finished video.")
            infoRow(
                systemImage: "square.and.arrow.down.on.square",
                title: "Add your footage",
                subtitle: addFootageSubtitle)
            infoRow(
                systemImage: "paintbrush.pointed.fill",
                title: "Pick a style, add your branding",
                subtitle: "Choose a template and enter your logo, name, and phone once — Realto remembers it for every video after.")
            infoRow(
                systemImage: "square.and.arrow.up.on.square",
                title: "Export, ready to post",
                subtitle: "Get 9:16, 1:1, and 16:9 versions in one tap — sized for Reels, feed, and YouTube.")
        }
    }

    private var addFootageSubtitle: LocalizedStringKey {
        #if os(macOS)
        "Drag clips in from Finder, or browse for a folder of footage."
        #else
        "Import clips from Photos, or record a walkthrough right in the app."
        #endif
    }

    // MARK: - Mac Inbox (macOS only)

    #if os(macOS)
    private var macInboxPage: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            SectionHeader(title: "Skip the app entirely",
                          subtitle: "An optional way to start videos without opening Realto.")
            infoRow(
                systemImage: "tray.and.arrow.down",
                title: "Set a watched folder",
                subtitle: "In Settings (⌘,), turn on Inbox and point it at a folder — an AirDrop landing spot, a card-reader import folder, wherever your footage lands.")
            infoRow(
                systemImage: "wand.and.stars",
                title: "Drafts appear automatically",
                subtitle: "Drop clips into that folder and a draft video is created for you — no \"New Video\" click needed.")
            infoRow(
                systemImage: "bell.badge.fill",
                title: "Export a whole batch at once",
                subtitle: "Render several drafts unattended from the Inbox window, with a notification when the batch finishes.")
            Text("Off by default — turn it on anytime in Settings.")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }
    #endif

    private func infoRow(systemImage: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            GradientIconBadge(systemImage: systemImage, gradient: Theme.Gradients.primary, size: 40)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title).font(.headline).foregroundStyle(Theme.Palette.textPrimary)
                Text(subtitle).font(.subheadline).foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .cardSurface()
    }

    // MARK: - Ready

    private var readyPage: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: Theme.Spacing.xl)
            GradientIconBadge(systemImage: "sparkles", gradient: Theme.Gradients.premium, size: 96)
                .shadow(color: Theme.Palette.accentAlt.opacity(0.3), radius: 16, y: 8)
            Text("You're all set")
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Your first export includes a small watermark. Upgrade anytime to remove it and unlock 4K — no subscription, pay once.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer(minLength: Theme.Spacing.xl)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        if pageIndex < pages.count - 1 {
            HStack(spacing: Theme.Spacing.m) {
                SecondaryButton(title: "Skip", accessibilityID: "onboarding.skipButton") {
                    onFinish()
                }
                PrimaryButton(title: "Next", systemImage: "arrow.right", accessibilityID: "onboarding.nextButton") {
                    pageIndex += 1
                }
            }
        } else {
            PrimaryButton(title: "Get Started", systemImage: "arrow.right", accessibilityID: "onboarding.getStartedButton") {
                onFinish()
            }
        }
    }
}
