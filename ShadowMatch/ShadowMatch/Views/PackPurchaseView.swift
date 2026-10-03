//
//  PackPurchaseView.swift
//  ShadowMatch
//
//  Grown-up facing pack page (shown after the parental gate): all 10 pictures,
//  price, buy + restore.
//

import SwiftUI

struct PackPurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PackStore

    let pack: ShadowPack
    /// Called once the pack is unlocked and the player taps "Play now".
    let onPlay: () -> Void

    private var unlocked: Bool { store.isUnlocked(pack) }
    private var purchasing: Bool { store.purchasingID == pack.productID }

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

                    Image(systemName: pack.symbol)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 70)
                        .background(pack.color, in: Circle())

                    VStack(spacing: 6) {
                        Text(pack.title)
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(NubeePalette.ink)
                        Text("\(pack.items.count) new pictures to match")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(NubeePalette.inkSoft)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(pack.items) { item in
                            Image(item.id)
                                .resizable()
                                .scaledToFit()
                                .padding(6)
                                .background(pack.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .accessibilityLabel(item.name)
                        }
                    }
                    .nubeeSurface(radius: 26, padding: 14)

                    if unlocked {
                        NubeePillButton(title: "Play now", symbol: "play.fill", color: NubeePalette.mint, fullWidth: true) {
                            onPlay()
                        }
                        .accessibilityIdentifier("purchase.play")
                    } else {
                        NubeePillButton(title: buyTitle, symbol: purchasing ? nil : "lock.open.fill",
                                        color: NubeePalette.purple, fullWidth: true) {
                            Task { await store.purchase(pack) }
                        }
                        .disabled(purchasing || store.product(for: pack) == nil)
                        .opacity(store.product(for: pack) == nil ? 0.6 : 1)
                        .accessibilityIdentifier("purchase.buy")

                        Text("One-time purchase. Yours to keep, shared with your family.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(NubeePalette.inkSoft)
                            .multilineTextAlignment(.center)

                        Button("Restore Purchases") {
                            Task { await store.restore() }
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(NubeePalette.purple)
                    }
                }
                .padding(NubeeMetrics.gutter)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut, value: unlocked)
        .task { if store.product(for: pack) == nil { await store.load() } } // e.g. offline at launch
        .alert("Store", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var buyTitle: String {
        if purchasing { return "Purchasing…" }
        guard let price = store.price(for: pack) else { return "Loading…" }
        return "Unlock for \(price)"
    }
}
