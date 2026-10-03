import SwiftUI
import StoreKit

/// The upgrade paywall (spec §7). One non-consumable product — pay once, own
/// it forever, no subscription. StoreKit 2 backed; graceful fallback when the
/// product isn't loaded yet (e.g. simulator without a StoreKit config).
struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var sub
    let onDismiss: () -> Void

    private let features: [(icon: String, text: LocalizedStringKey)] = [
        ("checkmark.seal.fill",   "No watermark on your exports"),
        ("4k.tv.fill",            "4K Ultra HD rendering"),
        ("paintbrush.pointed.fill","All templates, forever — no extra charge"),
        ("wifi.slash",            "100% on-device — works offline"),
        ("infinity",              "Pay once. No subscription, no renewal."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    featureList
                    priceCard
                    ctaSection
                    footerLinks
                }
                .padding(.bottom, 40)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Not now", action: onDismiss)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
        .task { await sub.load() }
        .alert("Purchase Error", isPresented: Binding(
            get: { sub.purchaseError != nil },
            set: { if !$0 { sub.purchaseError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sub.purchaseError ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "house.badge.shield.checkmark.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Palette.accent)
                .padding(.top, Theme.Spacing.xl)

            Text("Unlock Realto")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.Palette.textPrimary)

            Text("Professional listing videos with your branding — no watermark, no limits. One purchase, yours for good.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.bottom, Theme.Spacing.l)
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ForEach(features, id: \.icon) { feature in
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: feature.icon)
                        .foregroundStyle(Theme.Palette.accent)
                        .frame(width: 24)
                    Text(feature.text)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
            }
        }
        .padding(Theme.Spacing.l)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.l)
    }

    // MARK: - Price

    private var priceCard: some View {
        VStack(spacing: 2) {
            Text(sub.unlockProduct?.displayPrice ?? "$19.99")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("one-time purchase · pay once, use forever")
                .font(.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.l)
        .background(Theme.Palette.surfaceElevated)
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control)
            .strokeBorder(Theme.Palette.accent, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.l)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: Theme.Spacing.s) {
            if sub.isUnlocked {
                Label("You've already unlocked the full version!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.Palette.success)
                    .padding()
                SecondaryButton(title: "Done", accessibilityID: "Done", action: onDismiss)
                    .padding(.horizontal, Theme.Spacing.l)
            } else {
                PrimaryButton(
                    title: "Unlock Full Version",
                    systemImage: "crown.fill",
                    isLoading: sub.isPurchasing,
                    accessibilityID: "Unlock Full Version"
                ) {
                    guard let product = sub.unlockProduct else { return }
                    Task { await sub.purchase(product) }
                }
                .padding(.horizontal, Theme.Spacing.l)
            }
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Button("Restore Purchases") { Task { await sub.restore() } }
            HStack(spacing: Theme.Spacing.s) {
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Text("·").foregroundStyle(Theme.Palette.textSecondary)
                Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.Palette.textSecondary)
        .padding(.top, Theme.Spacing.m)
    }
}
