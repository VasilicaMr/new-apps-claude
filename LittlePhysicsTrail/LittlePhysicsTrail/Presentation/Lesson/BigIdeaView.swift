//
//  BigIdeaView.swift
//  LittlePhysicsTrail
//
//  The concept card shown on the first visit to a stop (and from the 💡 button in the game):
//  headline, a short explanation (read aloud), the bins the child will sort into,
//  and a safe "try at home" experiment for a grown-up and child to do together.
//

import SwiftUI
import TrailDomain

struct BigIdeaView: View {
    let viewModel: LessonViewModel
    let onClose: () -> Void

    @State private var appeared = false

    private var stop: JourneyStop { viewModel.stop }
    private var idea: BigIdea { stop.bigIdea }

    var body: some View {
        ZStack {
            NubeeBackground()
            stop.color.opacity(0.10).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Spacer()
                        Button(action: viewModel.isReviewingIdea ? viewModel.startPlaying : onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(NubeePalette.inkSoft)
                                .frame(width: 44, height: 44)
                                .background(NubeePalette.surface, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }

                    Text(stop.emoji)
                        .font(.system(size: 96))
                        .scaleEffect(appeared ? 1 : 0.4)
                        .phaseAnimator([0.0, -10.0]) { content, y in content.offset(y: y) }
                            animation: { _ in .easeInOut(duration: 1.1) }
                        .accessibilityHidden(true)

                    Label("Big idea", systemImage: "lightbulb.fill")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(stop.color, in: Capsule())

                    Text(idea.headline)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(NubeePalette.ink)
                        .multilineTextAlignment(.center)

                    explanationCard
                    binsPreview
                    tryAtHomeCard

                    NubeePillButton(
                        title: viewModel.isReviewingIdea ? "Back to the game" : "Let's play!",
                        symbol: "play.fill",
                        color: stop.color,
                        fullWidth: true,
                        action: viewModel.startPlaying
                    )
                    .accessibilityIdentifier("intro.play")
                    .padding(.top, 6)

                    if !viewModel.isReviewingIdea {
                        Button("Maybe later", action: onClose)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(NubeePalette.inkSoft)
                            .accessibilityIdentifier("intro.later")
                    }
                }
                .padding(NubeeMetrics.gutter)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
            viewModel.readBigIdea()
        }
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(idea.explanation)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(NubeePalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            readButton(title: "Read to me", action: viewModel.readBigIdea)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nubeeSurface(radius: 24, padding: 18)
    }

    private var binsPreview: some View {
        VStack(spacing: 10) {
            Text("You'll sort things into:")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(NubeePalette.inkSoft)
            HStack(spacing: 12) {
                ForEach(stop.bins) { bin in
                    VStack(spacing: 4) {
                        Text(bin.emoji).font(.system(size: 34))
                        Text(bin.title)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(NubeePalette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(NubeePalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(stop.color.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 6])))
                }
            }
        }
    }

    private var tryAtHomeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Try at home with a grown-up", systemImage: "house.fill")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(stop.color)
            Text(idea.tryAtHome)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(NubeePalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            readButton(title: "Read to me", action: viewModel.readTryAtHome)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nubeeSurface(radius: 24, padding: 18)
    }

    private func readButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .padding(.horizontal, 14)
                .frame(height: 36)
        }
        .buttonStyle(NubeeChunkyButtonStyle(color: stop.color, radius: 18, depth: 3))
    }
}
