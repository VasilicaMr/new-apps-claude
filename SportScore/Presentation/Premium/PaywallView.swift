import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    /// Set when shown at the end of the tutorial: called instead of `dismiss`, and after a purchase.
    var onClose: (() -> Void)?
    private let premium = PremiumManager.shared

    private let features: [(String, String)] = [
        ("clock.badge.checkmark.fill", "Unlimited session history"),
        ("chart.bar.fill", "Full stats & player leaderboards"),
        ("rectangle.3.group.fill", "Widget on your Home Screen"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    headerSection
                    featuresSection
                    purchaseSection
                }
                .padding(AppTheme.Spacing.lg)
            }
            .navigationTitle("ScoreCap Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { close() }
                }
            }
            .alert("Purchase Error", isPresented: Binding(
                get: { premium.purchaseError != nil },
                set: { if !$0 { premium.purchaseError = nil } }
            )) {
                Button("OK") { premium.purchaseError = nil }
            } message: {
                Text(premium.purchaseError ?? "")
            }
            .onChange(of: premium.isPremium) { _, isPremium in
                if isPremium, onClose != nil { close() }
            }
        }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)

            Text("Unlock the full game")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("One-time purchase. No subscription.\nPlay any sport, track everything.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            ForEach(features, id: \.0) { icon, text in
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 36)
                    Text(text)
                        .font(.body)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }

    private var purchaseSection: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Button {
                Task { await premium.purchase() }
            } label: {
                Group {
                    if premium.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else if let product = premium.product {
                        Text("Buy for \(product.displayPrice)")
                            .font(.headline)
                    } else {
                        Text("Buy Premium")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(premium.isPurchasing || premium.product == nil)

            Button {
                Task { await premium.restorePurchases() }
            } label: {
                Text("Restore purchase")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .disabled(premium.isPurchasing)

            Text("Payment charged to your Apple ID account at confirmation of purchase.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, AppTheme.Spacing.xs)
        }
    }
}
