import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreKitManager.shared

    private let features: [(icon: String, color: Color, title: String, detail: String)] = [
        ("clock.arrow.circlepath", .purple, "Unlimited history",   "Access every capture, forever."),
        ("icloud.fill",            .blue,   "iCloud sync",         "Your data on every device."),
        ("square.and.arrow.up",    .green,  "CSV export",          "Your data, your format."),
        ("slider.horizontal.3",    .orange, "Custom categories",   "Organise captures your way."),
        ("rectangle.3.group.fill", .pink,   "Home screen widget",  "Today's captures at a glance."),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.04, blue: 0.22),
                         Color(red: 0.28, green: 0.16, blue: 0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    featureList
                    purchaseSection
                }
                .padding(.bottom, 40)
            }

            // Close
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(20)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.top, 60)

            Text("UniversalCap Pro")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("One payment. Everything, forever.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.bottom, 36)
    }

    // MARK: Features

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(features, id: \.title) { feature in
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(feature.color.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: feature.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(feature.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(feature.detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                if feature.title != features.last!.title {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 84)
                }
            }
        }
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
    }

    // MARK: Purchase

    private var purchaseSection: some View {
        VStack(spacing: 14) {
            // Price
            if let product = store.product {
                VStack(spacing: 4) {
                    Text(product.displayPrice)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("one-time purchase · no subscription")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.top, 28)
            }

            // Error
            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Buy button
            Button {
                Task { await store.purchase() }
            } label: {
                ZStack {
                    if store.isPurchasing {
                        ProgressView().tint(Color(red: 0.28, green: 0.16, blue: 0.58))
                    } else {
                        Text(store.isPro ? "Already Unlocked ✓" : "Unlock Pro")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.28, green: 0.16, blue: 0.58))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            }
            .disabled(store.isPurchasing || store.isPro)
            .padding(.horizontal, 24)

            // Restore
            Button {
                Task { await store.restore() }
            } label: {
                Text("Restore purchase")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Text("Payment processed by Apple. No recurring charges.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
