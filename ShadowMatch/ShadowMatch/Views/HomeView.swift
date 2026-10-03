//
//  HomeView.swift
//  ShadowMatch
//
//  Journey home: packs as stops along a road (JourneyMapView). Every unlocked stop
//  can be played in any order — the fox marker only suggests the next one, and moves
//  on (with a "Next stop" toast) after a pack is finished.
//  First visit to a stop shows PackIntroView; first launch shows TutorialView.
//  Locked stops open the purchase page behind the parental gate (Kids category);
//  the gear opens the grown-ups ComplianceHubView, also behind the gate.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PackStore
    @EnvironmentObject private var progress: GameProgress
    @EnvironmentObject private var account: AccountManager

    @AppStorage(TutorialView.doneKey) private var tutorialDone = false

    @State private var flow: PackFlow? = nil
    @State private var buying: ShadowPack? = nil
    @State private var playAfterPurchase: ShadowPack? = nil
    @State private var showGrownUps = false
    @State private var replayTutorialAfterHub = false
    @State private var showTutorial = false
    @State private var markerPackID: String? = nil
    @State private var toast: String? = nil

    private struct PackFlow: Identifiable {
        let pack: ShadowPack
        let intro: Bool
        var id: String { pack.id }
    }

    /// Suggested next stop: the first playable pack not finished yet. Locked packs are never
    /// suggested — no purchase nudges aimed at kids.
    private var nextPack: ShadowPack? {
        ShadowPack.all.first { store.isUnlocked($0) && progress.best(for: $0) == 0 }
    }

    var body: some View {
        ZStack(alignment: .top) {
            NubeeBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, NubeeMetrics.gutter)
                    .padding(.bottom, 6)

                ScrollViewReader { proxy in
                    ScrollView {
                        JourneyMapView(
                            packs: ShadowPack.all,
                            markerPackID: markerPackID,
                            isUnlocked: { store.isUnlocked($0) },
                            price: { store.price(for: $0) },
                            best: { progress.best(for: $0) },
                            onTap: open
                        )
                        .padding(.horizontal, NubeeMetrics.gutter)
                        .padding(.bottom, 30)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        if let pack = ShadowPack.all.first(where: { $0.id == markerPackID }) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeInOut(duration: 0.8)) { proxy.scrollTo(JourneyMapView.scrollID(pack), anchor: .center) }
                            }
                        }
                    }
                    .onChange(of: markerPackID) { _, id in
                        guard let pack = ShadowPack.all.first(where: { $0.id == id }) else { return }
                        withAnimation(.easeInOut(duration: 0.9)) { proxy.scrollTo(JourneyMapView.scrollID(pack), anchor: .center) }
                    }
                }
            }

            if let toast {
                Label(toast, systemImage: "map.fill")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                    .background(NubeePalette.purple, in: Capsule())
                    .shadow(color: NubeePalette.purple.opacity(0.35), radius: 12, y: 6)
                    .padding(.top, 80)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
                    .accessibilityIdentifier("home.toast")
            }

            if showTutorial {
                TutorialView {
                    tutorialDone = true
                    withAnimation(.easeInOut(duration: 0.4)) { showTutorial = false }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .onAppear {
            markerPackID = nextPack?.id
            let args = ProcessInfo.processInfo.arguments
            // UI tests skip the tutorial unless they ask for it.
            if !tutorialDone && (!args.contains("-uiTesting") || args.contains("-showTutorial")) {
                showTutorial = true
            }
        }
        .onChange(of: store.purchasedIDs) { _, _ in
            // A newly bought pack can become the suggestion (quietly, no toast).
            if markerPackID == nil { withAnimation(.spring(response: 0.8)) { markerPackID = nextPack?.id } }
        }
        .fullScreenCover(item: $flow, onDismiss: advanceJourney) { f in
            PackFlowView(pack: f.pack, showingIntro: f.intro)
                .environmentObject(progress)
        }
        .sheet(item: $buying, onDismiss: startPendingGame) { pack in
            NubeeParentalGate {
                PackPurchaseView(pack: pack) {
                    playAfterPurchase = pack
                    buying = nil
                }
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showGrownUps, onDismiss: {
            if replayTutorialAfterHub {
                replayTutorialAfterHub = false
                withAnimation(.easeInOut(duration: 0.4)) { showTutorial = true }
            }
            markerPackID = nextPack?.id   // progress may have been reset
            startPendingGame()
        }) {
            NubeeParentalGate {
                ComplianceHubView(
                    onPlay: { pack in
                        playAfterPurchase = pack
                        showGrownUps = false
                    },
                    onReplayTutorial: {
                        replayTutorialAfterHub = true
                        showGrownUps = false
                    }
                )
            }
            .environmentObject(store)
            .environmentObject(progress)
            .environmentObject(account)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Peekaboo Shapes")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Pick any stop on your journey!")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(NubeePalette.inkSoft)
            }
            Spacer(minLength: 8)
            NubeeStatPill(symbol: "star.fill", value: "\(progress.stars)", tint: NubeePalette.orange, accessibilityLabel: "Stars")
            NubeeIconButton(symbol: "gearshape.fill", color: NubeePalette.slate, accessibilityLabel: "Grown-ups") {
                showGrownUps = true
            }
            .accessibilityIdentifier("home.grownups")
        }
        .padding(.top, 8)
        .frame(maxWidth: 1000)
    }

    private func open(_ pack: ShadowPack) {
        if store.isUnlocked(pack) {
            play(pack)
        } else {
            buying = pack
        }
    }

    private func play(_ pack: ShadowPack) {
        flow = PackFlow(pack: pack, intro: !progress.hasSeenIntro(pack))
    }

    /// A pack bought from a sheet starts once that sheet is gone.
    private func startPendingGame() {
        if let pack = playAfterPurchase {
            playAfterPurchase = nil
            play(pack)
        }
    }

    /// Back from a pack: if it was finished, walk the fox to the next stop and say so.
    private func advanceJourney() {
        let next = nextPack
        guard next?.id != markerPackID else { return }
        withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) { markerPackID = next?.id }
        guard let next else { return }

        let message = "Next stop: \(next.title)!"
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { toast = message }
        NubeeSpeech.shared.speak(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeInOut) { if toast == message { toast = nil } }
        }
    }
}
