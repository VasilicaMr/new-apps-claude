//
//  UnlockJourneyView.swift
//  LittlePhysicsTrail
//
//  Grown-up facing page for the one-time Full Journey purchase (always shown behind the
//  parental gate): what's included, price, buy + restore. Adapted from ShadowMatch's
//  PackPurchaseView.
//

import SwiftUI
import TrailDomain

struct UnlockJourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: UnlockViewModel

    /// Shown as "Start exploring" once unlocked; nil = just close.
    private let onExplore: (() -> Void)?

    init(viewModel: UnlockViewModel, onExplore: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onExplore = onExplore
    }

    var body: some View {
        ZStack {
            NubeeBackground()

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(NubeePalette.inkSoft)
                                .frame(width: 40, height: 40)
                                .background(NubeePalette.surface, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }

                    Text("🗺️").font(.system(size: 64))

                    VStack(spacing: 6) {
                        Text("The full journey")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(NubeePalette.ink)
                            .accessibilityIdentifier("unlock.title")
                        Text("\(viewModel.includedStops.count) more big ideas · \(viewModel.itemCount) more things to sort")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(NubeePalette.inkSoft)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 10) {
                        ForEach(viewModel.includedStops) { stop in
                            HStack(spacing: 12) {
                                Text(stop.emoji)
                                    .font(.system(size: 30))
                                    .frame(width: 52, height: 52)
                                    .background(stop.color.opacity(0.15), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stop.title)
                                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                                        .foregroundStyle(stop.color)
                                    Text(stop.bigIdea.headline)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(NubeePalette.ink)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .nubeeSurface(radius: 26, padding: 14)

                    if viewModel.isUnlocked {
                        Label("Unlocked — thank you!", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(NubeePalette.mint)
                        NubeePillButton(title: onExplore == nil ? "Done" : "Start exploring", symbol: "play.fill",
                                        color: NubeePalette.mint, fullWidth: true) {
                            if let onExplore { onExplore() } else { dismiss() }
                        }
                        .accessibilityIdentifier("unlock.explore")
                    } else {
                        NubeePillButton(title: buyTitle, symbol: viewModel.isPurchasing ? nil : "lock.open.fill",
                                        color: NubeePalette.purple, fullWidth: true) {
                            Task { await viewModel.buy() }
                        }
                        .disabled(viewModel.isPurchasing || viewModel.price == nil)
                        .opacity(viewModel.price == nil ? 0.6 : 1)
                        .accessibilityIdentifier("unlock.buy")

                        Text("One-time purchase. No subscription, no ads. Yours to keep and shared with your family.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(NubeePalette.inkSoft)
                            .multilineTextAlignment(.center)

                        Button(viewModel.isRestoring ? "Restoring…" : "Restore Purchases") {
                            Task { await viewModel.restore() }
                        }
                        .disabled(viewModel.isRestoring)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(NubeePalette.purple)
                        .accessibilityIdentifier("unlock.restore")
                    }
                }
                .padding(NubeeMetrics.gutter)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut, value: viewModel.isUnlocked)
        .task { await viewModel.load() }
        .alert("Store", isPresented: Binding(
            get: { viewModel.message != nil },
            set: { if !$0 { viewModel.message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.message ?? "")
        }
    }

    private var buyTitle: String {
        if viewModel.isPurchasing { return "Purchasing…" }
        guard let price = viewModel.price else { return "Loading…" }
        return "Unlock everything for \(price)"
    }
}
