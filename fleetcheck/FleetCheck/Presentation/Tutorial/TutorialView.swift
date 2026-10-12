import CoreLocation
import SwiftUI
import UserNotifications

/// First-launch walkthrough of the AI-first flow. Each step can switch on what it describes
/// (screenshots, location, notifications), so by the end the app runs mostly by itself.
/// Replay it from Settings.
struct TutorialView: View {
    let onFinish: () -> Void

    @Environment(ScreenshotInbox.self) private var inbox
    @State private var page = 0
    @State private var permissions = TutorialPermissions()

    private var pages: [TutorialPage] {
        [
            TutorialPage(symbol: "sparkles", color: .indigo, title: "Your driving co-pilot",
                         body: "FleetCheck keeps your kilometers, earnings and costs with as little typing as possible, and tells you what you really make per hour.",
                         examples: []),
            TutorialPage(symbol: "bubble.left.and.text.bubble.right.fill", color: .blue, title: "Just ask",
                         body: "Ask in your own words, or tell it what happened. Every number comes from your own data.",
                         examples: ["How much did I make this week?", "fuel 250 lei 34 L at OMV", "When is my ITP due?"],
                         footnote: AppleIntelligence.status == .available
                            ? "Apple Intelligence is on, so answers are written on this iPhone."
                            : "Apple Intelligence: \(AppleIntelligence.status.description.lowercased()). Quick answers still work."),
            TutorialPage(symbol: "text.viewfinder", color: .orange, title: "Earnings fill themselves",
                         body: "After a shift, take a screenshot of the earnings screen in Uber or Bolt. FleetCheck finds it, reads it and puts it on Home. You just tap Add.",
                         action: .photos),
            TutorialPage(symbol: "steeringwheel", color: .green, title: "One tap per shift",
                         body: "Tap Start shift when you go online. Kilometers, driving time and waiting time are counted even with the phone locked. Or say \"Hey Siri, start my shift in FleetCheck\".",
                         action: .location),
            TutorialPage(symbol: "doc.text.viewfinder", color: .pink, title: "Receipts and reminders",
                         body: "Photograph a fuel or service receipt and the expense fills in. Add your ITP, RCA and vignette dates and you're reminded 30, 7 and 1 days before.",
                         action: .notifications),
            TutorialPage(symbol: "lock.shield.fill", color: .teal, title: "Private by design",
                         body: "No account, no cloud. Your trips, money and screenshots are read and stored only on this iPhone. Export to a spreadsheet any time.",
                         examples: ["Hey Siri, ask FleetCheck", "Hey Siri, end my shift in FleetCheck"]),
        ]
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish).foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index]).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom)
            .accessibilityIdentifier("tutorial.next")
        }
        .padding(.top)
        .task { await permissions.refresh(inbox: inbox) }
    }

    private func pageView(_ page: TutorialPage) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: page.symbol)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 136, height: 136)
                    .background(page.color.gradient, in: .rect(cornerRadius: 34))
                    .shadow(color: page.color.opacity(0.4), radius: 16, y: 8)
                    .padding(.top, 24)
                Text(page.title).font(.title.bold()).multilineTextAlignment(.center)
                Text(page.body).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)

                if !page.examples.isEmpty {
                    VStack(alignment: .trailing, spacing: 8) {
                        ForEach(page.examples, id: \.self) { example in
                            Text(example)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .foregroundStyle(.white)
                                .background(Theme.accent, in: .rect(cornerRadius: 16))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                if let footnote = page.footnote {
                    Label(footnote, systemImage: "apple.intelligence").font(.footnote).foregroundStyle(.secondary)
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
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(granted ? .green : Theme.accent)
        .disabled(granted)
    }
}

struct TutorialPage {
    enum Action {
        case photos, location, notifications

        var title: String {
            switch self {
            case .photos: "Let FleetCheck find screenshots"
            case .location: "Allow location for shifts"
            case .notifications: "Turn on reminders"
            }
        }

        var grantedTitle: String {
            switch self {
            case .photos: "Screenshots: on"
            case .location: "Location: on"
            case .notifications: "Reminders: on"
            }
        }

        var symbol: String {
            switch self {
            case .photos: "photo.on.rectangle.angled"
            case .location: "location.fill"
            case .notifications: "bell.badge.fill"
            }
        }
    }

    let symbol: String
    let color: Color
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
    private(set) var location = false
    private(set) var notifications = false
    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private var locationDelegate: LocationDelegate?

    func isGranted(_ action: TutorialPage.Action) -> Bool {
        switch action {
        case .photos: photos
        case .location: location
        case .notifications: notifications
        }
    }

    func refresh(inbox: ScreenshotInbox) async {
        photos = inbox.hasAccess
        location = [.authorizedWhenInUse, .authorizedAlways].contains(locationManager.authorizationStatus)
        notifications = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
    }

    func request(_ action: TutorialPage.Action, inbox: ScreenshotInbox) async {
        switch action {
        case .photos:
            await inbox.requestAccess()
            photos = inbox.hasAccess
        case .location:
            let delegate = LocationDelegate { [weak self] status in
                self?.location = [.authorizedWhenInUse, .authorizedAlways].contains(status)
            }
            locationDelegate = delegate
            locationManager.delegate = delegate
            locationManager.requestWhenInUseAuthorization()
        case .notifications:
            notifications = await ReminderNotifier.requestPermission()
        }
    }
}

private final class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let onChange: @MainActor @Sendable (CLAuthorizationStatus) -> Void

    init(onChange: @escaping @MainActor @Sendable (CLAuthorizationStatus) -> Void) {
        self.onChange = onChange
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let onChange = onChange
        Task { @MainActor in onChange(status) }
    }
}
