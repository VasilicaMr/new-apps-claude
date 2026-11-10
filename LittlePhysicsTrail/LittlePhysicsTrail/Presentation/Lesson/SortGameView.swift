//
//  SortGameView.swift
//  LittlePhysicsTrail
//
//  Drag the item from the card stack (left/top) into the bin it belongs to (right/bottom).
//  The drag-and-fly mechanics are ported from ShadowMatch/Views/ShadowMatchView.swift;
//  the difference is what happens after a match: a fact card explains *why*, read aloud,
//  and the child taps Next when ready. Bins can also be tapped instead of dragging.
//

import SwiftUI
import TrailDomain

#if os(iOS)
import UIKit
#endif

struct SortGameView: View {
    let viewModel: LessonViewModel
    let onClose: () -> Void

    // Drag state (pure view concerns — the rules live in the view model / SortSession)
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var isFlying = false
    @State private var hoverBinID: SortBin.ID? = nil
    @State private var binFrames: [SortBin.ID: CGRect] = [:]
    @State private var itemFrame: CGRect = .zero

    private let space = "sortBoard"
    private var stop: JourneyStop { viewModel.stop }
    private var session: SortSession { viewModel.session }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width >= geo.size.height

            ZStack {
                NubeeBackground()

                VStack(spacing: 12) {
                    topBar
                    questionBanner

                    let layout = landscape
                        ? AnyLayout(HStackLayout(spacing: 20))
                        : AnyLayout(VStackLayout(spacing: 16))

                    layout {
                        stackHalf
                        binsHalf
                    }
                }
                .padding(.horizontal, NubeeMetrics.gutter)
                .padding(.vertical, 12)
                .coordinateSpace(name: space)
                .onPreferenceChange(BinFrameKey.self) { binFrames = $0 }
                .onPreferenceChange(ItemFrameKey.self) { itemFrame = $0 }

                if case .finished(let result) = viewModel.phase {
                    finishOverlay(result)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        .animation(.spring(), value: viewModel.phase)
        .onAppear(perform: viewModel.askQuestion)
    }
}

// ======================================================
// MARK: - Layout pieces
// ======================================================

private extension SortGameView {

    var topBar: some View {
        HStack(spacing: 14) {
            NubeeIconButton(symbol: "chevron.left", color: NubeePalette.slate, accessibilityLabel: "Back", action: onClose)
                .accessibilityIdentifier("lesson.back")

            VStack(alignment: .leading, spacing: 5) {
                Text(stop.title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(session.placed.count) / \(session.deck.count)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(NubeePalette.inkSoft)
                        .monospacedDigit()
                    NubeeProgressBar(value: session.progress, tint: stop.color, height: 8)
                        .frame(maxWidth: 140)
                }
            }

            Spacer(minLength: 8)

            NubeeIconButton(symbol: "lightbulb.fill", color: stop.color, accessibilityLabel: "Big idea", action: viewModel.reviewBigIdea)
                .accessibilityIdentifier("lesson.bigIdea")
        }
        .frame(height: 58)
    }

    var questionBanner: some View {
        Button(action: viewModel.askQuestion) {
            Label(stop.question, systemImage: "speaker.wave.2.fill")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(NubeePalette.ink)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(NubeePalette.surface, in: Capsule())
                .overlay(Capsule().stroke(stop.color.opacity(0.5), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Hear the question again")
    }

    // MARK: Stack (left / top half)

    var stackHalf: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.7

            ZStack {
                if let item = viewModel.revealedItem, !isFlying {
                    FactCard(item: item, bin: stop.bin(id: item.binID), color: stop.color,
                             isLast: session.remaining == 0,
                             onRead: viewModel.readRevealedFact,
                             onNext: viewModel.next)
                        .frame(maxWidth: 460)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else {
                    cardStack(side: side)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.revealedItem)
        }
        .zIndex(1) // the dragged item must float above the bins half
    }

    func cardStack(side: CGFloat) -> some View {
        ZStack {
            // Cards waiting underneath
            ForEach(0..<min(session.remaining, 3), id: \.self) { i in
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(NubeePalette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(NubeePalette.stroke))
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(Double(i + 1) * (i.isMultiple(of: 2) ? 4 : -4)))
                    .offset(y: CGFloat(i + 1) * 8)
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            }

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(NubeePalette.surface)
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(NubeePalette.stroke))
                .frame(width: side, height: side)
                .shadow(color: .black.opacity(0.1), radius: 12, y: 6)

            if let item = session.current {
                draggableItem(item, side: side)
            }
        }
        .overlay(alignment: .bottom) {
            Group {
                if viewModel.showsDragHint {
                    Label("Drag me into a box!", systemImage: "hand.point.up.left.fill")
                        .foregroundStyle(NubeePalette.purple)
                        .phaseAnimator([0.0, -6.0]) { content, y in content.offset(y: y) }
                            animation: { _ in .easeInOut(duration: 0.6) }
                } else {
                    Text(session.remaining == 0 ? "Last one!" : "\(session.remaining) more to go")
                        .foregroundStyle(NubeePalette.inkSoft)
                }
            }
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .offset(y: 34)
        }
    }

    func draggableItem(_ item: SortItem, side: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text(item.emoji)
                .font(.system(size: side * 0.48))
            Text(item.name)
                .font(.system(size: max(16, side * 0.08), weight: .heavy, design: .rounded))
                .foregroundStyle(NubeePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: side * 0.86, height: side * 0.86)
        .background(
            GeometryReader { g in
                Color.clear.preference(key: ItemFrameKey.self, value: g.frame(in: .named(space)))
            }
        )
        .scaleEffect(isDragging ? 1.08 : (isFlying ? 0.6 : 1))
        .shadow(color: .black.opacity(isDragging ? 0.2 : 0), radius: 18, y: 12)
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
                    hoverBinID = binID(at: value.location)
                }
                .onEnded { value in
                    guard !isFlying else { return }
                    isDragging = false
                    hoverBinID = nil
                    if let id = binID(at: value.location) {
                        drop(on: id)
                    } else {
                        returnToStack()
                    }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityHint("Drag into the right box, or tap a box.")
        .accessibilityIdentifier("lesson.item")
    }

    // MARK: Bins (right / bottom half)

    var binsHalf: some View {
        HStack(spacing: 14) {
            ForEach(stop.bins) { bin in
                binCard(bin)
            }
        }
        .padding(14)
        .background(NubeePalette.surface.opacity(0.45), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(NubeePalette.stroke))
    }

    func binCard(_ bin: SortBin) -> some View {
        let hovering = hoverBinID == bin.id
        let placed = session.placedItems(in: bin.id)

        return VStack(spacing: 6) {
            Text(bin.emoji)
                .font(.system(size: 44))
            Text(bin.title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(NubeePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 30), spacing: 2)], spacing: 2) {
                ForEach(placed) { item in
                    Text(item.emoji)
                        .font(.system(size: 24))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: placed)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(hovering ? stop.color.opacity(0.18) : NubeePalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    hovering ? stop.color : NubeePalette.inkSoft.opacity(0.3),
                    style: StrokeStyle(lineWidth: hovering ? 4 : 2, dash: hovering ? [] : [10, 8])
                )
        )
        .scaleEffect(hovering ? 1.04 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
        .modifier(NubeeShakeEffect(travel: 12, animatableData: CGFloat(viewModel.wrongDrops[bin.id] ?? 0)))
        .animation(.linear(duration: 0.4), value: viewModel.wrongDrops[bin.id] ?? 0)
        .background(
            GeometryReader { g in
                Color.clear.preference(key: BinFrameKey.self, value: [bin.id: g.frame(in: .named(space))])
            }
        )
        .contentShape(Rectangle())
        .onTapGesture { drop(on: bin.id) } // tap-to-place alternative to dragging
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bin.title) box, \(placed.count) inside")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("lesson.bin.\(bin.id)")
    }

    // MARK: Finish

    func finishOverlay(_ result: StopResult) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            ConfettiBurst().allowsHitTesting(false)

            VStack(spacing: 16) {
                Text(stop.finishTitle)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                    .multilineTextAlignment(.center)

                StarsRow(earned: result.stars, size: 44)

                VStack(spacing: 6) {
                    Label("You learned", systemImage: "lightbulb.fill")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(stop.color)
                    Text(stop.bigIdea.headline)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(NubeePalette.ink)
                        .multilineTextAlignment(.center)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(stop.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack(spacing: 14) {
                    NubeePillButton(title: "Trail", symbol: "map.fill", color: NubeePalette.slate, action: onClose)
                        .accessibilityIdentifier("lesson.home")
                    NubeePillButton(title: "Play again", symbol: "arrow.clockwise", color: NubeePalette.mint, action: viewModel.playAgain)
                        .accessibilityIdentifier("lesson.playAgain")
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
// MARK: - Drop handling
// ======================================================

private extension SortGameView {

    func binID(at point: CGPoint) -> SortBin.ID? {
        binFrames.first { $0.value.contains(point) }?.key
    }

    func drop(on binID: SortBin.ID) {
        guard !isFlying, let target = binFrames[binID] else { return }

        switch viewModel.drop(on: binID) {
        case .correct:
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            // Fly the item into its bin; the fact card replaces the stack once it lands.
            isFlying = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                dragOffset = CGSize(width: target.midX - itemFrame.midX, height: target.midY - itemFrame.midY)
            }
            Task {
                try? await Task.sleep(for: .milliseconds(320))
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { dragOffset = .zero }
                isFlying = false
            }
        case .tryAgain:
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            returnToStack()
        case .ignored:
            returnToStack()
        }
    }

    func returnToStack() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            dragOffset = .zero
        }
    }
}

// ======================================================
// MARK: - Fact card
// ======================================================

/// The "why" after a correct drop.
private struct FactCard: View {
    let item: SortItem
    let bin: SortBin?
    let color: Color
    let isLast: Bool
    let onRead: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(item.emoji).font(.system(size: 54))
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(NubeePalette.inkSoft)
                if let bin {
                    Text(bin.emoji).font(.system(size: 40))
                }
            }
            .accessibilityHidden(true)

            Text("\(item.name) · \(bin?.title ?? "")!")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)

            Text(item.fact)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(NubeePalette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lesson.fact")

            HStack(spacing: 12) {
                NubeeIconButton(symbol: "speaker.wave.2.fill", color: color, accessibilityLabel: "Read to me", action: onRead)
                NubeePillButton(title: isLast ? "Finish" : "Next", symbol: isLast ? "flag.checkered" : "arrow.right",
                                color: NubeePalette.mint, action: onNext)
                    .accessibilityIdentifier("lesson.next")
            }
        }
        .padding(20)
        .nubeeSurface(radius: 30, padding: 0)
    }
}

// ======================================================
// MARK: - Frame preferences
// ======================================================

private struct BinFrameKey: PreferenceKey {
    static var defaultValue: [SortBin.ID: CGRect] = [:]
    static func reduce(value: inout [SortBin.ID: CGRect], nextValue: () -> [SortBin.ID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct ItemFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
