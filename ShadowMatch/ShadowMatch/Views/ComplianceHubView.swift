//
//  ComplianceHubView.swift
//  ShadowMatch
//
//  Grown-ups hub (behind the parental gate): account (Sign in with Apple), play settings,
//  picture-pack purchases, privacy, support. Adapted from scrambledUI/Kid/KidComplianceHubView.swift —
//  no subscriptions or diagnostics here, so those sections are left out.
//

import SwiftUI
import AuthenticationServices

struct ComplianceHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: PackStore
    @EnvironmentObject private var progress: GameProgress
    @EnvironmentObject private var account: AccountManager

    /// Called when a pack was just bought and the grown-up taps "Play now".
    var onPlay: (ShadowPack) -> Void = { _ in }
    /// "Show tutorial again" — the home screen shows it once this sheet is gone.
    var onReplayTutorial: () -> Void = {}

    var privacyURL: URL? = URL(string: "https://adaptivebyte.com/privacy-policy/")
    var termsURL: URL? = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    var supportEmail: String? = "support@adaptivebyte.com"
    /// Set once the app exists in App Store Connect to show "Rate this app".
    var appStoreAppID: String? = nil

    @AppStorage(NubeeSpeech.enabledKey) private var readAloud = true
    @AppStorage(ShadowStyle.silhouetteKey) private var shadowSilhouette = true

    @State private var buying: ShadowPack? = nil
    @State private var restoring = false
    @State private var showResetAlert = false
    @State private var showDeleteAccountAlert = false

    private var paidPacks: [ShadowPack] { ShadowPack.all.filter { !$0.isFree } }
    private var ownsAllPacks: Bool { paidPacks.allSatisfy(store.isUnlocked) }

    var body: some View {
        NavigationStack {
            ZStack {
                NubeeBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        headerHero

                        HubSectionCard(title: "Account", symbol: "person.crop.circle.fill") {
                            accountSection
                        }

                        HubSectionCard(title: "Play", symbol: "gamecontroller.fill") {
                            VStack(spacing: 12) {
                                HubToggleTile(
                                    title: "Read names aloud",
                                    subtitle: "Say each picture's name when it's matched.",
                                    symbol: "speaker.wave.2.fill",
                                    isOn: $readAloud
                                )
                                HubToggleTile(
                                    title: "Dark shadows",
                                    subtitle: "Solid silhouettes. Turn off for faded pictures (easier).",
                                    symbol: "circle.lefthalf.filled",
                                    isOn: $shadowSilhouette
                                )
                                HubActionTile(
                                    title: "Show tutorial again",
                                    subtitle: "Foxy shows how to play, step by step",
                                    symbol: "hand.point.up.left.fill",
                                    style: .regular
                                ) {
                                    onReplayTutorial()
                                }
                                .accessibilityIdentifier("hub.tutorial")
                            }
                        }

                        HubSectionCard(title: "Picture packs", symbol: "bag.fill") {
                            VStack(spacing: 12) {
                                if ownsAllPacks {
                                    allPacksStatusCard
                                }

                                ForEach(ShadowPack.all) { pack in
                                    packTile(pack)
                                }

                                HubActionTile(
                                    title: restoring ? "Restoring…" : "Restore Purchases",
                                    subtitle: "Re-enable packs bought on this Apple ID",
                                    symbol: "arrow.clockwise.circle.fill",
                                    style: .prominent
                                ) {
                                    guard !restoring else { return }
                                    Task {
                                        restoring = true
                                        await store.restore()
                                        restoring = false
                                    }
                                }
                                .accessibilityIdentifier("hub.restore")
                            }
                        }

                        HubSectionCard(title: "Privacy", symbol: "hand.raised.fill") {
                            VStack(spacing: 12) {
                                HubInfoTile(
                                    title: "No ads, no tracking",
                                    subtitle: "Peekaboo Shapes collects no data. Progress and your account details are stored only on this device.",
                                    symbol: "lock.shield.fill"
                                )

                                if let privacyURL {
                                    HubActionTile(
                                        title: "Privacy Policy",
                                        subtitle: "How we handle data",
                                        symbol: "hand.raised.fill",
                                        style: .regular
                                    ) { openURL(privacyURL) }
                                }

                                if let termsURL {
                                    HubActionTile(
                                        title: "Terms of Use",
                                        subtitle: "Rules for using the app",
                                        symbol: "doc.text.fill",
                                        style: .regular
                                    ) { openURL(termsURL) }
                                }

                                HubActionTile(
                                    title: "Reset progress",
                                    subtitle: "Clear stars and settings. Purchased packs stay unlocked.",
                                    symbol: "trash.fill",
                                    style: .destructive
                                ) {
                                    showResetAlert = true
                                }
                                .accessibilityIdentifier("hub.reset")
                            }
                        }

                        HubSectionCard(title: "Support", symbol: "questionmark.circle.fill") {
                            VStack(spacing: 12) {
                                if let supportEmail {
                                    HubActionTile(
                                        title: "Contact Support",
                                        subtitle: supportEmail,
                                        symbol: "envelope.fill",
                                        style: .regular
                                    ) {
                                        openSupportEmail(to: supportEmail)
                                    }
                                }

                                if let appStoreAppID {
                                    HubActionTile(
                                        title: "Rate this app",
                                        subtitle: "Helps a lot ❤️",
                                        symbol: "star.bubble.fill",
                                        style: .prominent
                                    ) {
                                        openRating(appID: appStoreAppID)
                                    }
                                }

                                HubVersionTile()
                            }
                        }

                        NubeePillButton(title: "Close", color: NubeePalette.slate, fullWidth: true) {
                            dismiss()
                        }
                        .frame(maxWidth: 360)
                        .padding(.top, 4)
                        .accessibilityLabel("Close")
                    }
                    .padding(.horizontal, NubeeMetrics.gutter)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $buying) { pack in
                // Already past the parental gate — go straight to the pack page.
                PackPurchaseView(pack: pack) {
                    buying = nil
                    onPlay(pack)
                }
                .environmentObject(store)
            }
            .alert("Reset progress?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { progress.reset() }
            } message: {
                Text("This clears stars and settings on this device. Purchased picture packs stay unlocked. This cannot be undone.")
            }
            .alert("Delete account?", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    account.deleteAccount()
                    progress.reset()
                }
            } message: {
                Text("This removes your account, stars and settings from this device. Purchased picture packs stay with your Apple ID. To also stop using Sign in with Apple for Peekaboo Shapes, go to Settings → your name → Sign-In & Security → Sign in with Apple.")
            }
            .task { if store.products.isEmpty { await store.load() } }
        }
    }

    // MARK: - Pieces

    private var headerHero: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Grown-ups")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                Text("Account, settings, picture packs, privacy & support")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .opacity(0.9)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [NubeePalette.purple, NubeePalette.sky], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: NubeeMetrics.cardRadius, style: .continuous)
        )
        .shadow(color: NubeePalette.purple.opacity(0.3), radius: 14, y: 8)
    }

    @ViewBuilder
    private var accountSection: some View {
        VStack(spacing: 12) {
            if let signedIn = account.account {
                profileTile(signedIn)

                HubActionTile(
                    title: "Sign Out",
                    subtitle: "Progress and packs stay on this device",
                    symbol: "rectangle.portrait.and.arrow.right",
                    style: .regular
                ) {
                    account.signOut()
                }
                .accessibilityIdentifier("hub.signOut")

                HubActionTile(
                    title: "Delete Account",
                    subtitle: "Remove your account and progress from this device",
                    symbol: "person.crop.circle.badge.xmark",
                    style: .destructive
                ) {
                    showDeleteAccountAlert = true
                }
                .accessibilityIdentifier("hub.deleteAccount")
            } else {
                HubInfoTile(
                    title: "Sign in with Apple",
                    subtitle: "Optional. Your name and email stay on this device — you can hide your email.",
                    symbol: "applelogo"
                )

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    account.handle(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .frame(maxWidth: 375)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("hub.signIn")

                if let error = account.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(NubeePalette.wrong)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    private func profileTile(_ signedIn: AccountManager.Account) -> some View {
        HStack(spacing: 14) {
            Text(initials(signedIn.name))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: [NubeePalette.purple, NubeePalette.sky], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(signedIn.name ?? "Signed in with Apple")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                Text(signedIn.email ?? "Email hidden")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(NubeePalette.inkSoft)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(NubeePalette.mint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 58)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NubeePalette.surfaceSunken))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hub.profile")
    }

    private func initials(_ name: String?) -> String {
        guard let name else { return "" }
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "" : String(letters).uppercased()
    }

    private var allPacksStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(NubeePalette.mint)
                Text("All picture packs")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
            }
            Text("You have every pack — \(ShadowPack.all.reduce(0) { $0 + $1.items.count }) pictures to match")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(NubeePalette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(NubeePalette.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(NubeePalette.mint.opacity(0.4)))
    }

    @ViewBuilder
    private func packTile(_ pack: ShadowPack) -> some View {
        let unlocked = store.isUnlocked(pack)
        let status = pack.isFree ? "Free" : (unlocked ? "Unlocked" : (store.price(for: pack) ?? (store.products.isEmpty ? "Loading…" : "Unavailable")))

        Button {
            if !unlocked { buying = pack }
        } label: {
            HStack(spacing: 14) {
                HubRowIcon(symbol: pack.symbol, color: pack.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(NubeePalette.ink)
                    Text("\(pack.items.count) pictures · \(pack.tagline)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(NubeePalette.inkSoft)
                }

                Spacer(minLength: 8)

                if unlocked {
                    Label(status, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(NubeePalette.mint)
                } else {
                    Text(status)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(NubeePalette.purple, in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 58)
            .background(NubeePalette.surfaceSunken, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pack.title), \(status)")
        .accessibilityIdentifier("hub.pack.\(pack.id)")
    }

    private func openSupportEmail(to email: String) {
        let subject = "Peekaboo Shapes Support"
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Support"
        if let url = URL(string: "mailto:\(email)?subject=\(encoded)") {
            openURL(url)
        }
    }

    private func openRating(appID: String) {
        if let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") { openURL(url) }
    }
}

// MARK: - Private helper views

private struct HubSectionCard<Content: View>: View {
    var title: String
    var symbol: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(NubeePalette.inkSoft)
                .padding(.leading, 4)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nubeeSurface(radius: NubeeMetrics.cardRadius, padding: 14)
    }
}

/// Colored rounded-square icon used by every hub row so titles line up.
private struct HubRowIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct HubActionTile: View {
    enum Style { case prominent, regular, destructive }

    var title: String
    var subtitle: String
    var symbol: String
    var style: Style
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                HubRowIcon(symbol: symbol, color: iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(style == .destructive ? NubeePalette.wrong : NubeePalette.ink)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(NubeePalette.inkSoft)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(NubeePalette.inkSoft.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(backgroundFill))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var backgroundFill: Color {
        switch style {
        case .prominent: return NubeePalette.purple.opacity(0.10)
        case .regular: return NubeePalette.surfaceSunken
        case .destructive: return NubeePalette.wrong.opacity(0.10)
        }
    }

    private var iconColor: Color {
        switch style {
        case .prominent: return NubeePalette.purple
        case .regular: return NubeePalette.sky
        case .destructive: return NubeePalette.wrong
        }
    }
}

private struct HubToggleTile: View {
    var title: String
    var subtitle: String
    var symbol: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            HubRowIcon(symbol: symbol, color: NubeePalette.mint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(NubeePalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(NubeePalette.mint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 58)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NubeePalette.surfaceSunken))
    }
}

private struct HubInfoTile: View {
    var title: String
    var subtitle: String
    var symbol: String

    var body: some View {
        HStack(spacing: 14) {
            HubRowIcon(symbol: symbol, color: NubeePalette.mint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(NubeePalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 58)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NubeePalette.surfaceSunken))
    }
}

private struct HubVersionTile: View {
    var body: some View {
        HStack(spacing: 14) {
            HubRowIcon(symbol: "info.circle.fill", color: NubeePalette.slate)
            Text("Version")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(NubeePalette.ink)
            Spacer()
            Text(appVersionString())
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(NubeePalette.inkSoft)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 58)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NubeePalette.surfaceSunken))
    }

    private func appVersionString() -> String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(v) (\(b))"
    }
}
