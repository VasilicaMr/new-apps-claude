//
//  ShadowMatchView.swift
//  ShadowMatch
//
//  Drag the picture from the stack (left half) onto its matching shadow (right half).
//  2–4 shadows per round, difficulty grows as you go. Plays one ShadowPack (10 pictures).
//  Ported from scrambledUI/Kid/ShadowMatchView.swift (Nubee).
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

enum ShadowStyle {
    /// Grown-ups setting: true = dark silhouette, false = 20% faded copy of the picture.
    static let silhouetteKey = "shadow.silhouette"
}

// ======================================================
// MARK: - Game view
// ======================================================

struct ShadowMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var progress: GameProgress

    let pack: ShadowPack

    @AppStorage(ShadowStyle.silhouetteKey) private var useSilhouette = true
    @AppStorage(NubeeSpeech.enabledKey) private var readAloud = true
    @AppStorage("shadow.tutorialDone") private var tutorialDone = false

    // Game state
    @State private var deck: [ShadowItem]
    @State private var round = 0
    @State private var targets: [ShadowItem] = []
    @State private var matchedID: String? = nil
    @State private var mistakes = 0
    @State private var finished: FinishResult? = nil

    // Drag state
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var isFlying = false
    @State private var hoverID: String? = nil
    @State private var shakes: [String: CGFloat] = [:]
    @State private var targetFrames: [String: CGRect] = [:]
    @State private var stackFrame: CGRect = .zero

    private let space = "shadowBoard"

    struct FinishResult: Equatable {
        let stars: Int
    }

    init(pack: ShadowPack) {
        self.pack = pack
        _deck = State(initialValue: pack.items.shuffled())
    }

    private var current: ShadowItem? { round < deck.count ? deck[round] : nil }

    /// 2 shadows for the first rounds, then 3, then 4.
    private var targetsCount: Int {
        switch round {
        case 0..<3: return 2
        case 3..<7: return 3
        default: return 4
        }
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width >= geo.size.height

            ZStack {
                NubeeBackground()

                VStack(spacing: 14) {
                    topBar

                    let layout = landscape
                        ? AnyLayout(HStackLayout(spacing: 20))
                        : AnyLayout(VStackLayout(spacing: 20))

                    layout {
                        stackHalf
                        targetsHalf
                    }
                }
                .padding(.horizontal, NubeeMetrics.gutter)
                .padding(.vertical, 12)
                .coordinateSpace(name: space)
                .onPreferenceChange(ShadowTargetFrameKey.self) { targetFrames = $0 }
                .onPreferenceChange(ShadowStackFrameKey.self) { stackFrame = $0 }

                if let finished {
                    finishOverlay(finished)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationBarBackButtonHidden(true)
        .onAppear { if targets.isEmpty { startRound() } }
    }
}

// ======================================================
// MARK: - Layout pieces
// ======================================================

private extension ShadowMatchView {

    var topBar: some View {
        HStack(spacing: 14) {
            NubeeIconButton(symbol: "chevron.left", color: NubeePalette.slate, accessibilityLabel: "Back") {
                dismiss()
            }
            .accessibilityIdentifier("shadow.back")

            VStack(alignment: .leading, spacing: 5) {
                Text(pack.title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                HStack(spacing: 8) {
                    Text("\(min(round + (matchedID == nil ? 0 : 1), deck.count)) / \(deck.count)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(NubeePalette.inkSoft)
                        .monospacedDigit()
                    NubeeProgressBar(
                        value: Double(round + (matchedID == nil ? 0 : 1)) / Double(max(deck.count, 1)),
                        tint: pack.color, height: 8
                    )
                    .frame(width: 140)
                }
            }

            Spacer(minLength: 8)

            NubeeStatPill(symbol: "star.fill", value: "\(progress.stars)", tint: NubeePalette.orange, accessibilityLabel: "Stars")
        }
        .frame(height: 58)
    }

    // MARK: Stack (left / top half)

    var stackHalf: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.62
            let remaining = max(0, deck.count - round - 1)

            ZStack {
                // Cards waiting underneath
                ForEach(0..<min(remaining, 3), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(NubeePalette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(NubeePalette.stroke))
                        .frame(width: side, height: side)
                        .rotationEffect(.degrees(Double(i + 1) * (i.isMultiple(of: 2) ? 4 : -4)))
                        .offset(y: CGFloat(i + 1) * 8)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                }

                // Top card (empty base — the animal lifts off it)
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(NubeePalette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(NubeePalette.stroke))
                    .frame(width: side, height: side)
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)

                if let current, matchedID != current.id {
                    draggableAnimal(current, side: side)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                VStack(spacing: 4) {
                    if !tutorialDone && round == 0 {
                        Label("Drag me to my shadow!", systemImage: "hand.point.up.left.fill")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(NubeePalette.purple)
                            .phaseAnimator([0.0, -6.0]) { content, y in content.offset(y: y) }
                                animation: { _ in .easeInOut(duration: 0.6) }
                    } else {
                        Text(remaining == 0 ? "Last one!" : "\(remaining) more to go")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(NubeePalette.inkSoft)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .zIndex(1) // the dragged animal must float above the targets half
    }

    func draggableAnimal(_ animal: ShadowItem, side: CGFloat) -> some View {
        Image(animal.id)
            .resizable()
            .scaledToFit()
            .frame(width: side * 0.82, height: side * 0.82)
            .background(
                GeometryReader { g in
                    Color.clear.preference(key: ShadowStackFrameKey.self, value: g.frame(in: .named(space)))
                }
            )
            .scaleEffect(isDragging ? 1.08 : (isFlying ? 0.9 : 1))
            .shadow(color: .black.opacity(isDragging ? 0.25 : 0.08), radius: isDragging ? 18 : 6, y: isDragging ? 12 : 3)
            .offset(dragOffset)
            .gesture(
                DragGesture(coordinateSpace: .named(space))
                    .onChanged { value in
                        guard !isFlying else { return }
                        if !isDragging {
                            isDragging = true
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                        }
                        dragOffset = value.translation
                        hoverID = targetID(at: value.location)
                    }
                    .onEnded { value in
                        guard !isFlying else { return }
                        isDragging = false
                        hoverID = nil
                        if let id = targetID(at: value.location) {
                            attemptDrop(on: id)
                        } else {
                            returnToStack()
                        }
                    }
            )
            .accessibilityLabel(animal.name)
            .accessibilityHint("Drag to the matching shadow, or tap a shadow.")
            .accessibilityIdentifier("shadow.current")
    }

    // MARK: Targets (right / bottom half)

    var targetsHalf: some View {
        GeometryReader { geo in
            let count = max(targets.count, 1)
            let spacing: CGFloat = 18
            // Pick the column count that gives the biggest cards for this space.
            let cellFor: (Int) -> CGFloat = { c in
                let r = Int(ceil(Double(count) / Double(c)))
                return min(
                    (geo.size.width - spacing * CGFloat(c - 1)) / CGFloat(c),
                    (geo.size.height - spacing * CGFloat(r - 1)) / CGFloat(r)
                )
            }
            let cols = (1...count).max { cellFor($0) < cellFor($1) } ?? 1
            let cell = max(80, min(cellFor(cols), 340))

            let rowsArray: [[ShadowItem]] = stride(from: 0, to: targets.count, by: cols).map {
                Array(targets[$0..<min($0 + cols, targets.count)])
            }

            VStack(spacing: spacing) {
                ForEach(rowsArray.indices, id: \.self) { r in
                    HStack(spacing: spacing) {
                        ForEach(rowsArray[r]) { animal in
                            targetCard(animal, side: cell)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .background(NubeePalette.surface.opacity(0.45), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(NubeePalette.stroke))
    }

    func targetCard(_ animal: ShadowItem, side: CGFloat) -> some View {
        let matched = matchedID == animal.id
        let hovering = hoverID == animal.id

        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(matched ? NubeePalette.mint.opacity(0.18) : NubeePalette.surface)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    matched ? NubeePalette.mint : (hovering ? NubeePalette.orange : NubeePalette.stroke),
                    style: StrokeStyle(lineWidth: matched || hovering ? 4 : 1.5, dash: matched || hovering ? [] : [10, 8])
                )

            if matched {
                Image(animal.id)
                    .resizable()
                    .scaledToFit()
                    .padding(side * 0.1)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .overlay(alignment: .bottom) {
                        Text(animal.name)
                            .font(.system(size: max(18, side * 0.1), weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(NubeePalette.mint, in: Capsule())
                            .offset(y: 12)
                            .transition(.scale.combined(with: .opacity))
                    }
            } else {
                shadowImage(animal)
                    .padding(side * 0.1)
            }
        }
        .frame(width: side, height: side)
        .scaleEffect(hovering ? 1.05 : (matched ? 1.04 : 1))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
        .modifier(NubeeShakeEffect(travel: 12, animatableData: shakes[animal.id] ?? 0))
        .background(
            GeometryReader { g in
                Color.clear.preference(key: ShadowTargetFrameKey.self, value: [animal.id: g.frame(in: .named(space))])
            }
        )
        .contentShape(Rectangle())
        .onTapGesture { attemptDrop(on: animal.id) } // tap-to-place alternative to dragging
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(matched ? animal.name : "Shadow")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("shadow.target.\(animal.name.lowercased())")
    }

    @ViewBuilder
    func shadowImage(_ animal: ShadowItem) -> some View {
        if useSilhouette {
            Image(animal.id)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(NubeePalette.ink.opacity(0.28))
        } else {
            Image(animal.id)
                .resizable()
                .scaledToFit()
                .opacity(0.2)
        }
    }

    // MARK: Finish

    func finishOverlay(_ r: FinishResult) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            ConfettiBurst().allowsHitTesting(false)

            VStack(spacing: 16) {
                Text(pack.finishTitle)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < r.stars ? "star.fill" : "star")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(i < r.stars ? NubeePalette.orange : NubeePalette.inkSoft.opacity(0.4))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(r.stars) stars")

                HStack(spacing: -18) {
                    ForEach(deck.prefix(5)) { a in
                        Image(a.id).resizable().scaledToFit().frame(width: 70, height: 70)
                    }
                }

                HStack(spacing: 14) {
                    NubeePillButton(title: "Home", symbol: "house.fill", color: NubeePalette.slate) {
                        dismiss()
                    }
                    NubeePillButton(title: "Play again", symbol: "arrow.clockwise", color: NubeePalette.mint) {
                        restart()
                    }
                    .accessibilityIdentifier("shadow.playAgain")
                }
            }
            .padding(28)
            .nubeeSurface(radius: 34, padding: 0)
            .padding(24)
            .frame(maxWidth: 560)
        }
    }
}

// ======================================================
// MARK: - Game logic
// ======================================================

private extension ShadowMatchView {

    func startRound() {
        guard let current else { return }
        var pool = pack.items.filter { $0 != current }.shuffled()
        var picks = [current]
        while picks.count < targetsCount, !pool.isEmpty { picks.append(pool.removeFirst()) }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            targets = picks.shuffled()
            matchedID = nil
            shakes = [:]
        }
    }

    func targetID(at point: CGPoint) -> String? {
        targetFrames.first { $0.value.contains(point) }?.key
    }

    func attemptDrop(on id: String) {
        guard let current, matchedID == nil, !isFlying, finished == nil else { return }

        if id == current.id {
            tutorialDone = true
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif

            // Fly the picture into its shadow, then reveal it there.
            if let target = targetFrames[id] {
                isFlying = true
                let dx = target.midX - stackFrame.midX
                let dy = target.midY - stackFrame.midY
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    dragOffset = CGSize(width: dx, height: dy)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { matchedID = id }
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { dragOffset = .zero; isFlying = false }
                if readAloud { NubeeSpeech.shared.speak(current.name) }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                advance()
            }
        } else {
            mistakes += 1
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            withAnimation(.linear(duration: 0.4)) { shakes[id, default: 0] += 1 }
            returnToStack()
        }
    }

    func returnToStack() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            dragOffset = .zero
        }
    }

    func advance() {
        if round + 1 >= deck.count {
            finish()
        } else {
            round += 1
            startRound()
        }
    }

    func finish() {
        let stars = mistakes == 0 ? 3 : (mistakes <= 3 ? 2 : 1)
        progress.record(pack: pack, stars: stars)
        if readAloud { NubeeSpeech.shared.speak("Well done!") }
        withAnimation(.spring()) { finished = FinishResult(stars: stars) }
    }

    func restart() {
        withAnimation(.easeInOut) {
            finished = nil
            deck = pack.items.shuffled()
            round = 0
            mistakes = 0
            dragOffset = .zero
        }
        startRound()
    }
}

// ======================================================
// MARK: - Frame preferences
// ======================================================

private struct ShadowTargetFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct ShadowStackFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
