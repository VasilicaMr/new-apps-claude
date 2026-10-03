//
//  PackIntroView.swift
//  ShadowMatch
//
//  First visit to a journey stop: the pack's pictures pop in one by one (tap to hear
//  each name), then "Let's play!" — or "Maybe later" back to the journey. Never forced.
//  PackFlowView chains the intro into the game inside one full-screen cover.
//

import SwiftUI

struct PackFlowView: View {
    let pack: ShadowPack
    @State var showingIntro: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if showingIntro {
            PackIntroView(pack: pack) {
                withAnimation(.easeInOut(duration: 0.35)) { showingIntro = false }
            } onLater: {
                dismiss()
            }
            .transition(.opacity)
        } else {
            ShadowMatchView(pack: pack)
                .transition(.opacity)
        }
    }
}

struct PackIntroView: View {
    @EnvironmentObject private var progress: GameProgress

    let pack: ShadowPack
    let onPlay: () -> Void
    let onLater: () -> Void

    @State private var shown = 0
    @State private var tapped: String? = nil

    var body: some View {
        ZStack {
            NubeeBackground()
            pack.color.opacity(0.10).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Spacer()
                        Button(action: onLater) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(NubeePalette.inkSoft)
                                .frame(width: 44, height: 44)
                                .background(NubeePalette.surface, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }

                    Image(systemName: pack.symbol)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(pack.color, in: Circle())
                        .phaseAnimator([1.0, 1.08]) { c, s in c.scaleEffect(s) } animation: { _ in .easeInOut(duration: 0.9) }

                    VStack(spacing: 6) {
                        Text(pack.title)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(NubeePalette.ink)
                            .multilineTextAlignment(.center)
                        Text("Meet your new friends! Tap one to hear its name.")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(NubeePalette.inkSoft)
                            .multilineTextAlignment(.center)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                        ForEach(Array(pack.items.enumerated()), id: \.element.id) { i, item in
                            Button {
                                NubeeSpeech.shared.speak(item.name)
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { tapped = item.id }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(.spring()) { if tapped == item.id { tapped = nil } }
                                }
                            } label: {
                                Image(item.id)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(8)
                                    .background(NubeePalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .scaleEffect(i < shown ? (tapped == item.id ? 1.15 : 1) : 0.3)
                                    .opacity(i < shown ? 1 : 0)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.name)
                        }
                    }
                    .padding(14)
                    .background(pack.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                    NubeePillButton(title: "Let's play!", symbol: "play.fill", color: pack.color, fullWidth: true, action: onPlay)
                        .frame(maxWidth: 380)
                        .accessibilityIdentifier("intro.play")

                    Button("Maybe later", action: onLater)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(NubeePalette.inkSoft)
                        .accessibilityIdentifier("intro.later")
                }
                .padding(NubeeMetrics.gutter)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .task {
            progress.markIntroSeen(pack)
            NubeeSpeech.shared.speak(pack.title)
            for i in 1...pack.items.count {
                try? await Task.sleep(for: .milliseconds(140))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { shown = i }
            }
        }
    }
}
