import StoreKit
import SwiftUI

/// What Pro adds, the three plans and the buy button. Shown as a sheet (`PaywallSheet`) when a free driver
/// reaches a Pro feature, and as the last page of the tutorial.
struct PaywallContent: View {
    @Binding var selectedID: String
    /// The tutorial shows feature titles only and puts the buy button in its own bottom bar.
    var compact = false
    /// Called once the driver has Pro, after buying or restoring.
    var onUnlocked: () -> Void = {}

    @Environment(ProStore.self) private var pro

    private let features: [(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey)] = [
        ("text.viewfinder", "Unlimited screenshot reading", "Free includes 10 a month."),
        ("sparkles", "Screenshots found for you", "New earnings screenshots show up on Home already read."),
        ("car.side.fill", "Your minimum fare", "The true cost of your car per km, so you know which trips lose money."),
        ("flag.checkered", "Weekly goal and best times", "The hours you still need, and the days and hours that pay best."),
        ("tablecells", "Export for your accountant", "Shifts, earnings and expenses as spreadsheets."),
    ]

    var body: some View {
        VStack(spacing: 18) {
            header
            if pro.isPro {
                unlockedCard
            } else {
                featureList
                plans
                if !compact { PaywallBuyButton(selectedID: selectedID, onUnlocked: onUnlocked) }
                finePrint
            }
        }
        .task { if pro.products.isEmpty { await pro.load() } }
        .alert("Purchase didn't go through", isPresented: Binding(get: { pro.purchaseError != nil }, set: { if !$0 { pro.purchaseError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pro.purchaseError ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: compact ? 28 : 38, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: compact ? 60 : 84, height: compact ? 60 : 84)
                .gradientCard(Theme.earningsGradient, cornerRadius: compact ? 19 : 26, shadow: Theme.warning.opacity(0.35))
            Text("DriveCap Pro")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("Stop typing numbers and see exactly where your money goes.")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            ForEach(features, id: \.symbol) { feature in
                HStack(alignment: compact ? .center : .top, spacing: 12) {
                    IconBadge(symbol: feature.symbol, tint: Theme.warning, size: compact ? 28 : 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                        if !compact {
                            Text(feature.detail).font(.caption).foregroundStyle(Theme.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - Plans

    @ViewBuilder
    private var plans: some View {
        if pro.products.isEmpty {
            VStack(spacing: 10) {
                if pro.loadFailed {
                    Text("Couldn't load the prices. Check your connection.")
                        .font(.footnote).foregroundStyle(Theme.inkSecondary)
                    Button("Try again") { Task { await pro.load() } }
                        .buttonStyle(CapsuleButtonStyle(filled: false, compact: true))
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(spacing: 10) {
                ForEach(pro.products) { product in
                    planRow(product)
                }
            }
        }
    }

    private func planRow(_ product: Product) -> some View {
        let selected = product.id == selectedID
        return Button { selectedID = product.id } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? Theme.warning : Theme.inkSecondary.opacity(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(planTitle(product)).font(.headline.weight(.bold)).foregroundStyle(Theme.ink)
                        if let badge = badge(product) {
                            Text(badge)
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.warning, in: .capsule)
                        }
                    }
                    Text(planDetail(product)).font(.caption).foregroundStyle(Theme.inkSecondary)
                }
                Spacer(minLength: 8)
                Text(product.displayPrice)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            .padding(14)
            .background(Theme.cardBackground, in: .rect(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? Theme.warning : Theme.cardStroke, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(product.id.split(separator: ".").last ?? "")")
    }

    private func planTitle(_ product: Product) -> String {
        switch product.id {
        case ProStore.ProductID.yearly: String(localized: "Yearly")
        case ProStore.ProductID.monthly: String(localized: "Monthly")
        default: String(localized: "Lifetime")
        }
    }

    private func planDetail(_ product: Product) -> String {
        switch product.id {
        case ProStore.ProductID.yearly:
            String(localized: "\((product.price / 12).formatted(product.priceFormatStyle)) a month, billed yearly")
        case ProStore.ProductID.monthly:
            String(localized: "Billed every month")
        default:
            String(localized: "Pay once, keep Pro forever")
        }
    }

    private func trialDays(_ product: Product) -> Int? { product.trialDays }

    private func badge(_ product: Product) -> String? {
        if pro.hasTrial(product), let days = trialDays(product) { return String(localized: "\(days) days free") }
        return product.id == ProStore.ProductID.yearly ? String(localized: "Best value") : nil
    }

    // MARK: - Buy

    private var selectedProduct: Product? { pro.product(selectedID) ?? pro.products.first }

    private var finePrint: some View {
        VStack(spacing: 10) {
            if let product = selectedProduct {
                Text(terms(product))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 14) {
                Button("Restore purchases") { Task { await pro.restore(); if pro.isPro { onUnlocked() } } }
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy", destination: URL(string: "https://adaptivebyte.com/privacy-policy/")!)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.blue)
        }
    }

    /// What the store requires the driver to see before subscribing: price, period, auto-renewal, how to cancel.
    private func terms(_ product: Product) -> String {
        let price = product.displayPrice
        let yearly = product.subscription?.subscriptionPeriod.unit == .year
        switch (product.type, pro.hasTrial(product) ? trialDays(product) : nil) {
        case (.nonConsumable, _):
            return String(localized: "One payment of \(price). No subscription.")
        case let (_, days?):
            return yearly
                ? String(localized: "Free for \(days) days, then \(price) a year. Renews automatically; cancel anytime in Settings at least 24 hours before it renews.")
                : String(localized: "Free for \(days) days, then \(price) a month. Renews automatically; cancel anytime in Settings at least 24 hours before it renews.")
        default:
            return yearly
                ? String(localized: "\(price) a year. Renews automatically; cancel anytime in Settings at least 24 hours before it renews.")
                : String(localized: "\(price) a month. Renews automatically; cancel anytime in Settings at least 24 hours before it renews.")
        }
    }

    private var unlockedCard: some View {
        Label("You have DriveCap Pro. Everything is unlocked.", systemImage: "checkmark.seal.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.positive)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
    }
}

/// Buys the selected plan: "Start 7-day free trial", "Subscribe" or "Buy lifetime".
struct PaywallBuyButton: View {
    let selectedID: String
    var onUnlocked: () -> Void = {}

    @Environment(ProStore.self) private var pro

    private var selectedProduct: Product? { pro.product(selectedID) ?? pro.products.first }

    var body: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task { if await pro.purchase(product) { onUnlocked() } }
        } label: {
            Group {
                if pro.isPurchasing {
                    ProgressView().tint(.white)
                } else if let product = selectedProduct, pro.hasTrial(product), let days = product.trialDays {
                    Text("Start \(days)-day free trial")
                } else if selectedProduct?.type == .nonConsumable {
                    Text("Buy lifetime")
                } else {
                    Text("Subscribe")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(CapsuleButtonStyle(tint: Theme.warning))
        .disabled(selectedProduct == nil || pro.isPurchasing)
        .accessibilityIdentifier("paywall.buy")
    }
}

extension Product {
    /// Length of the free trial in days, when the subscription has one.
    var trialDays: Int? {
        guard let period = subscription?.introductoryOffer?.period else { return nil }
        return switch period.unit {
        case .day: period.value
        case .week: period.value * 7
        case .month: period.value * 30
        case .year: period.value * 365
        @unknown default: nil
        }
    }
}

/// The paywall on its own, opened from a locked feature. Closes by itself after a purchase.
struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = ProStore.ProductID.yearly

    var body: some View {
        NavigationStack {
            ScrollView {
                PaywallContent(selectedID: $selectedID) { dismiss() }
                    .padding()
            }
            .fleetBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

/// A small "Pro" capsule for locked features.
struct ProBadge: View {
    var body: some View {
        Label("Pro", systemImage: "crown.fill")
            .font(.system(.caption2, design: .rounded, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.earningsGradient, in: .capsule)
    }
}
