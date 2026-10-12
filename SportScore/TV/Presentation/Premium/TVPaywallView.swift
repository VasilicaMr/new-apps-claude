import SwiftUI

struct TVPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    /// Set when shown at the end of the tutorial: called instead of `dismiss`.
    var onClose: (() -> Void)?
    private let premium = PremiumManager.shared

    private let features: [(String, String)] = [
        ("clock.badge.checkmark.fill", "Unlimited session history"),
        ("chart.bar.fill", "Full stats & player leaderboards"),
        ("iphone.and.arrow.forward", "Also unlocks ScoreCap on iPhone"),
    ]

    var body: some View {
        HStack(spacing: 100) {
            VStack(alignment: .leading, spacing: 30) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(.yellow)
                Text("ScoreCap Premium")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Unlock the full game")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                Text("One-time purchase. No subscription.\nPlay any sport, track everything.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 24) {
                    ForEach(features, id: \.0) { icon, text in
                        HStack(spacing: 24) {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .frame(width: 56)
                            Text(text)
                                .font(.title3)
                        }
                    }
                }
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 30) {
                Button {
                    Task {
                        await premium.purchase()
                        if premium.isPremium { close() }
                    }
                } label: {
                    Group {
                        if premium.isPurchasing {
                            ProgressView()
                        } else if let product = premium.product {
                            Text("Buy for \(product.displayPrice)")
                        } else {
                            Text("Buy Premium")
                        }
                    }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(premium.isPurchasing || premium.product == nil)

                Button {
                    Task {
                        await premium.restorePurchases()
                        if premium.isPremium { close() }
                    }
                } label: {
                    Text("Restore purchase").frame(maxWidth: .infinity)
                }
                .disabled(premium.isPurchasing)

                Button {
                    close()
                } label: {
                    Text("Not now").frame(maxWidth: .infinity)
                }

                Text("Payment charged to your Apple ID account at confirmation of purchase.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 620)
        }
        .padding(80)
        .alert("Purchase Error", isPresented: Binding(
            get: { premium.purchaseError != nil },
            set: { if !$0 { premium.purchaseError = nil } }
        )) {
            Button("OK") { premium.purchaseError = nil }
        } message: {
            Text(premium.purchaseError ?? "")
        }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}
