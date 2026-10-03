//
//  TutorialView.swift
//  ShadowMatch
//
//  First-launch tutorial, shown over the journey: 1) hello from the fox,
//  2) an animated hand shows the drag, 3) the child tries one match themselves.
//  "Skip" is always there; replay it from the grown-ups hub.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

struct TutorialView: View {
    static let doneKey = "shadow.onboardingDone"

    var onFinish: () -> Void

    @State private var page = 0
    @State private var practiceDone = false

    var body: some View {
        ZStack {
            NubeeBackground()

            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? NubeePalette.purple : NubeePalette.inkSoft.opacity(0.25))
                                .frame(width: i == page ? 26 : 10, height: 10)
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Step \(page + 1) of 3")

                    Spacer()

                    if !practiceDone {
                        Button("Skip", action: onFinish)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(NubeePalette.inkSoft)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(NubeePalette.surface, in: Capsule())
                            .accessibilityIdentifier("tutorial.skip")
                    }
                }
                .frame(height: 44)

                Spacer(minLength: 0)

                Group {
                    switch page {
                    case 0: TutorialWelcomePage()
                    case 1: TutorialDemoPage()
                    default: TutorialPracticePage(done: $practiceDone)
                    }
                }
                .id(page)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer(minLength: 0)

                bottomBar
                    .frame(height: 70)
            }
            .padding(NubeeMetrics.gutter)
            .frame(maxWidth: 700)

            if practiceDone {
                ConfettiBurst().allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if page < 2 {
            NubeePillButton(title: page == 0 ? "Show me how" : "My turn!", symbol: "arrow.right", color: NubeePalette.purple) {
                withAnimation(.easeInOut(duration: 0.4)) { page += 1 }
            }
            .accessibilityIdentifier("tutorial.next")
        } else if practiceDone {
            NubeePillButton(title: "Start the journey!", symbol: "map.fill", color: NubeePalette.mint, action: onFinish)
                .transition(.scale.combined(with: .opacity))
                .accessibilityIdentifier("tutorial.start")
        } else {
            Color.clear
        }
    }
}

// ======================================================
// MARK: - 1. Welcome
// ======================================================

private struct TutorialWelcomePage: View {
    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Image("shadow_fox")
                    .resizable().renderingMode(.template).scaledToFit()
                    .foregroundStyle(NubeePalette.ink.opacity(0.22))
                    .frame(width: 200, height: 200)
                    .offset(x: 46, y: 26)
                Image("shadow_fox")
                    .resizable().scaledToFit()
                    .frame(width: 200, height: 200)
                    .phaseAnimator([0.0, -14.0]) { c, y in c.offset(y: y) } animation: { _ in .easeInOut(duration: 0.8) }
            }
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Hi, I'm Foxy!")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                Text("Every picture has a shadow.\nLet's find them together!")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(NubeePalette.inkSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear { NubeeSpeech.shared.speak("Hi, I'm Foxy! Every picture has a shadow. Let's find them together!") }
    }
}

// ======================================================
// MARK: - Shared canvas layout (base 340 × 260, scaled up on iPad)
// ======================================================

private struct TutorialCanvas {
    let k: CGFloat
    var size: CGSize { CGSize(width: 340 * k, height: 260 * k) }
    var card: CGFloat { 112 * k }
    var shadow: CGFloat { 100 * k }
    var picture: CGPoint { CGPoint(x: 72 * k, y: 130 * k) }
    var topShadow: CGPoint { CGPoint(x: 266 * k, y: 68 * k) }
    var bottomShadow: CGPoint { CGPoint(x: 266 * k, y: 192 * k) }

    static func scale(for width: CGFloat) -> CGFloat { width > 600 ? 1.5 : 1 }
}

private struct ShadowSlot: View {
    let item: String
    let side: CGFloat
    var revealed = false
    var highlighted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(revealed ? NubeePalette.mint.opacity(0.18) : NubeePalette.surface)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(revealed ? NubeePalette.mint : (highlighted ? NubeePalette.orange : NubeePalette.stroke),
                              style: StrokeStyle(lineWidth: revealed || highlighted ? 4 : 1.5, dash: revealed || highlighted ? [] : [8, 6]))
            if revealed {
                Image(item).resizable().scaledToFit().padding(side * 0.1)
            } else {
                Image(item).resizable().renderingMode(.template).scaledToFit()
                    .foregroundStyle(NubeePalette.ink.opacity(0.28))
                    .padding(side * 0.1)
            }
        }
        .frame(width: side, height: side)
    }
}

private struct PictureCard: View {
    let side: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(NubeePalette.surface)
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(NubeePalette.stroke))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .frame(width: side, height: side)
    }
}

// ======================================================
// MARK: - 2. Demo (animated hand)
// ======================================================

private struct TutorialDemoPage: View {
    private enum Phase: CaseIterable { case rest, lift, move, drop }

    var body: some View {
        GeometryReader { geo in
            let c = TutorialCanvas(k: TutorialCanvas.scale(for: geo.size.width))

            VStack(spacing: 22) {
                Text("Drag the picture onto its shadow")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                    .multilineTextAlignment(.center)

                ZStack(alignment: .topLeading) {
                    PictureCard(side: c.card).position(c.picture)

                    // Shadow slots; the lion "lands" in the top one on .drop.
                    PhaseAnimator(Phase.allCases) { phase in
                        ZStack(alignment: .topLeading) {
                            ShadowSlot(item: "shadow_lion", side: c.shadow, revealed: phase == .drop, highlighted: phase == .move)
                                .position(c.topShadow)
                            ShadowSlot(item: "shadow_frog", side: c.shadow)
                                .position(c.bottomShadow)

                            let at = phase == .move || phase == .drop ? c.topShadow : c.picture
                            Image("shadow_lion")
                                .resizable().scaledToFit()
                                .frame(width: c.card * 0.8, height: c.card * 0.8)
                                .scaleEffect(phase == .lift || phase == .move ? 1.1 : 1)
                                .shadow(color: .black.opacity(phase == .rest ? 0.05 : 0.25), radius: phase == .rest ? 3 : 12, y: 8)
                                .opacity(phase == .drop ? 0 : 1)
                                .position(at)

                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 44 * c.k))
                                .foregroundStyle(NubeePalette.purple)
                                .shadow(color: .white, radius: 2)
                                .opacity(phase == .rest || phase == .drop ? 0 : 1)
                                .position(x: at.x + 26 * c.k, y: at.y + 34 * c.k)
                        }
                    } animation: { phase in
                        switch phase {
                        case .rest: return .linear(duration: 0.01).delay(1.1)      // hold the "matched" frame, then reset
                        case .lift: return .easeOut(duration: 0.3).delay(0.5)
                        case .move: return .easeInOut(duration: 0.9)
                        case .drop: return .spring(response: 0.35, dampingFraction: 0.6)
                        }
                    }
                }
                .frame(width: c.size.width, height: c.size.height)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("A hand drags the lion onto the lion's shadow.")

                Text("Look for the shape that matches!")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(NubeePalette.inkSoft)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { NubeeSpeech.shared.speak("Drag the picture onto its shadow.") }
    }
}

// ======================================================
// MARK: - 3. Practice (the child's turn)
// ======================================================

private struct TutorialPracticePage: View {
    @Binding var done: Bool

    @State private var dragOffset: CGSize = .zero
    @State private var dragging = false
    @State private var hovering: String? = nil
    @State private var owlShake: CGFloat = 0
    @State private var triedWrong = false

    private let space = "tutorialPractice"

    var body: some View {
        GeometryReader { geo in
            let c = TutorialCanvas(k: TutorialCanvas.scale(for: geo.size.width))

            VStack(spacing: 22) {
                Text(done ? "You did it! 🎉" : "Your turn! Drag the fox onto its shadow")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(done ? NubeePalette.mint : NubeePalette.ink)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                ZStack(alignment: .topLeading) {
                    PictureCard(side: c.card).position(c.picture)

                    ShadowSlot(item: "shadow_owl", side: c.shadow, highlighted: hovering == "owl")
                        .modifier(NubeeShakeEffect(travel: 10, animatableData: owlShake))
                        .position(c.topShadow)
                        .onTapGesture { drop(on: "owl") }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Shadow")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("tutorial.target.owl")

                    ShadowSlot(item: "shadow_fox", side: c.shadow, revealed: done, highlighted: hovering == "fox" || (triedWrong && !done))
                        .position(c.bottomShadow)
                        .onTapGesture { drop(on: "fox", canvas: c) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(done ? "Fox" : "Shadow")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("tutorial.target.fox")

                    if !done {
                        Image("shadow_fox")
                            .resizable().scaledToFit()
                            .frame(width: c.card * 0.8, height: c.card * 0.8)
                            .scaleEffect(dragging ? 1.1 : 1)
                            .shadow(color: .black.opacity(dragging ? 0.25 : 0.06), radius: dragging ? 14 : 4, y: dragging ? 10 : 3)
                            .offset(dragOffset)
                            .position(c.picture)
                            .gesture(
                                DragGesture(coordinateSpace: .named(space))
                                    .onChanged { v in
                                        dragging = true
                                        dragOffset = v.translation
                                        hovering = target(at: v.location, canvas: c)
                                    }
                                    .onEnded { v in
                                        dragging = false
                                        hovering = nil
                                        if let t = target(at: v.location, canvas: c) {
                                            drop(on: t, canvas: c)
                                        } else {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { dragOffset = .zero }
                                        }
                                    }
                            )
                            .accessibilityLabel("Fox")
                            .accessibilityIdentifier("tutorial.fox")

                        if !dragging {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 40 * c.k))
                                .foregroundStyle(NubeePalette.purple)
                                .shadow(color: .white, radius: 2)
                                .phaseAnimator([0.0, 14.0]) { content, d in content.offset(x: d, y: d * 0.6) }
                                    animation: { _ in .easeInOut(duration: 0.7) }
                                .position(x: c.picture.x + 30 * c.k, y: c.picture.y + 40 * c.k)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .frame(width: c.size.width, height: c.size.height)
                .coordinateSpace(name: space)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { NubeeSpeech.shared.speak("Your turn! Drag the fox onto its shadow.") }
    }

    private func target(at p: CGPoint, canvas c: TutorialCanvas) -> String? {
        func hit(_ center: CGPoint) -> Bool {
            CGRect(x: center.x - c.shadow / 2, y: center.y - c.shadow / 2, width: c.shadow, height: c.shadow).contains(p)
        }
        if hit(c.bottomShadow) { return "fox" }
        if hit(c.topShadow) { return "owl" }
        return nil
    }

    private func drop(on id: String, canvas c: TutorialCanvas? = nil) {
        guard !done else { return }
        if id == "fox" {
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            if let c {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    dragOffset = CGSize(width: c.bottomShadow.x - c.picture.x, height: c.bottomShadow.y - c.picture.y)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { done = true }
                NubeeSpeech.shared.speak("Fox! You did it!")
            }
        } else {
            // Gentle nudge, no penalty: shake, return, and light up the right shadow.
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif
            withAnimation(.linear(duration: 0.4)) { owlShake += 1 }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { dragOffset = .zero; triedWrong = true }
            NubeeSpeech.shared.speak("That's the owl. Try the other one!")
        }
    }
}
