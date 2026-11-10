import SwiftUI
import UserNotifications

/// First-launch walkthrough in the order the driver should do things: upload earnings, add costs, see profit.
/// Each step can switch on what it describes (screenshots, notifications), so by the end the app runs mostly by itself.
/// The last page offers DriveCap Pro; the driver can buy there or carry on with the free version. Buying or restoring
/// closes the tutorial straight away.
/// Replay it from Settings.
struct TutorialView: View {
    let onFinish: () -> Void

    @Environment(ScreenshotInbox.self) private var inbox
    @Environment(ProStore.self) private var pro
    @State private var page = Self.startPage
    @State private var permissions = TutorialPermissions()
    @State private var plan = ProStore.ProductID.yearly

    private var pages: [TutorialPage] {
        [
            TutorialPage(symbol: "banknote.fill", gradient: Theme.profitGradient, title: String(localized: "Know what you really earn"),
                         body: String(localized: "Upload your Uber and Bolt earnings, add your costs, and DriveCap shows what you keep per hour and per km. Three steps, mostly screenshots."),
                         examples: []),
            TutorialPage(symbol: "text.viewfinder", gradient: Theme.earningsGradient, title: String(localized: "1. Upload your earnings"),
                         body: String(localized: "In Uber Driver or Bolt Driver, take a screenshot of a trip, today's earnings or the week. Tap Upload screenshot on Home and DriveCap reads the money, kilometers and destination. Allow access and new screenshots show up by themselves."),
                         action: .photos),
            TutorialPage(symbol: "doc.text.viewfinder", gradient: Theme.receiptGradient, title: String(localized: "2. Add your costs"),
                         body: String(localized: "Photograph a fuel or service receipt and the expense fills in. Or just type it, like the examples below."),
                         examples: [String(localized: "fuel $40 38 L at Shell"), String(localized: "car wash 35")]),
            TutorialPage(symbol: "chart.line.uptrend.xyaxis", gradient: Theme.voiceGradient, title: String(localized: "3. See your real profit"),
                         body: String(localized: "Home shows what you keep this week. Ask anything in your own words; every number comes from your own data."),
                         examples: [String(localized: "How much did I make this week?"), String(localized: "Which day pays best?")],
                         footnote: AppleIntelligence.status == .available
                            ? String(localized: "Apple Intelligence is on, so answers are written on this iPhone.")
                            : String(localized: "Apple Intelligence: \(AppleIntelligence.status.description.lowercased()). Quick answers still work.")),
            TutorialPage(symbol: "steeringwheel", gradient: Theme.shiftGradient, title: String(localized: "Optional: hours and reminders"),
                         body: String(localized: "Tap Start shift when you go online and End when you're done to get earnings per hour. No GPS, so no battery drain. Add your ITP, RCA and vignette dates and you're reminded 30, 7 and 1 days before."),
                         action: .notifications),
            TutorialPage(symbol: "lock.shield.fill", gradient: Theme.carGradient, title: String(localized: "Private by design"),
                         body: String(localized: "No account, no cloud. Your trips, money and screenshots are read and stored only on this iPhone. Export to a spreadsheet any time."),
                         examples: [String(localized: "Hey Siri, ask DriveCap"), String(localized: "Hey Siri, start my shift in DriveCap")]),
        ]
    }

    /// Debug builds accept `-tutorialPage <n>` to open a page directly (the paywall is the last one).
    private static var startPage: Int {
        #if DEBUG
        return UserDefaults.standard.integer(forKey: "tutorialPage")
        #else
        return 0
        #endif
    }

    /// The paywall comes after the feature pages.
    private var paywallPage: Int { pages.count }
    private var isOnPaywall: Bool { page == paywallPage }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                // Skipping the walkthrough still shows what Pro offers, once.
                Button("Skip") { withAnimation { page = paywallPage } }
                    .buttonStyle(CapsuleButtonStyle(tint: Theme.ink, filled: false, compact: true))
                    .opacity(isOnPaywall ? 0 : 1)
                    .disabled(isOnPaywall)
            }
            .padding(.horizontal)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index]).tag(index)
                }
                ScrollView {
                    PaywallContent(selectedID: $plan, compact: true, onUnlocked: onFinish)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
                .tag(paywallPage)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0...paywallPage, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Theme.blue : Theme.ink.opacity(0.15))
                        .frame(width: index == page ? 24 : 8, height: 8)
                }
            }
            .animation(.spring(duration: 0.3), value: page)
            .accessibilityHidden(true)

            if isOnPaywall && !pro.isPro {
                VStack(spacing: 6) {
                    PaywallBuyButton(selectedID: plan, onUnlocked: onFinish)
                        .padding(.bottom, 4)
                    Button("Continue with the free version", action: onFinish)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.blue)
                        .accessibilityIdentifier("tutorial.continueFree")
                    Text("Free: shifts, stats, reminders and 10 screenshot reads a month.")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom)
            } else {
                Button {
                    if isOnPaywall {
                        onFinish()
                    } else {
                        withAnimation { page += 1 }
                    }
                } label: {
                    Text(isOnPaywall ? "Get started" : "Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CapsuleButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom)
                .accessibilityIdentifier("tutorial.next")
            }
        }
        .padding(.top)
        .background(Theme.canvas.ignoresSafeArea())
        .task { await permissions.refresh(inbox: inbox) }
        // However Pro arrives (buy button, restore, a purchase finishing in the background), go on to the app.
        .onChange(of: pro.isPro) { _, isPro in
            if isPro && isOnPaywall { onFinish() }
        }
    }

    private func pageView(_ page: TutorialPage) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: page.symbol)
                    .font(.system(size: 60, weight: .bold))
                    .frame(width: 140, height: 140)
                    .gradientCard(page.gradient, cornerRadius: 40, shadow: .black.opacity(0.18))
                    .padding(.top, 24)
                Text(page.title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)

                if !page.examples.isEmpty {
                    VStack(alignment: .trailing, spacing: 8) {
                        ForEach(page.examples, id: \.self) { example in
                            Text(example)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .gradientCard(Theme.shiftGradient, cornerRadius: 18, shadow: Theme.blue.opacity(0.20))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                if let footnote = page.footnote {
                    Label(footnote, systemImage: "apple.intelligence").font(.footnote).foregroundStyle(Theme.inkSecondary)
                }
                if let action = page.action {
                    permissionButton(action)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }

    @ViewBuilder
    private func permissionButton(_ action: TutorialPage.Action) -> some View {
        let granted = permissions.isGranted(action)
        Button {
            Task { await permissions.request(action, inbox: inbox) }
        } label: {
            Label(granted ? action.grantedTitle : action.title, systemImage: granted ? "checkmark.circle.fill" : action.symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CapsuleButtonStyle(tint: granted ? Theme.positive : Theme.blue, filled: false))
        .disabled(granted)
    }
}

struct TutorialPage {
    enum Action {
        case photos, notifications

        var title: String {
            switch self {
            case .photos: String(localized: "Let DriveCap find screenshots")
            case .notifications: String(localized: "Turn on reminders")
            }
        }

        var grantedTitle: String {
            switch self {
            case .photos: String(localized: "Screenshots: on")
            case .notifications: String(localized: "Reminders: on")
            }
        }

        var symbol: String {
            switch self {
            case .photos: "photo.on.rectangle.angled"
            case .notifications: "bell.badge.fill"
            }
        }
    }

    let symbol: String
    let gradient: LinearGradient
    let title: String
    let body: String
    var examples: [String] = []
    var footnote: String?
    var action: Action?
}

/// Asks for the permissions the tutorial pages describe and remembers what was granted.
@MainActor
@Observable
final class TutorialPermissions {
    private(set) var photos = false
    private(set) var notifications = false

    func isGranted(_ action: TutorialPage.Action) -> Bool {
        switch action {
        case .photos: photos
        case .notifications: notifications
        }
    }

    func refresh(inbox: ScreenshotInbox) async {
        photos = inbox.hasAccess
        notifications = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
    }

    func request(_ action: TutorialPage.Action, inbox: ScreenshotInbox) async {
        switch action {
        case .photos:
            await inbox.requestAccess()
            photos = inbox.hasAccess
        case .notifications:
            notifications = await ReminderNotifier.requestPermission()
        }
    }
}
