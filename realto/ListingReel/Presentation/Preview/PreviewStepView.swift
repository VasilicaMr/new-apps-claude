import SwiftUI
import AVKit

/// Step 6 — Preview. Plays the REAL composition (same assembly path as export),
/// so there are no surprises after export (spec §6).
///
/// Full-screen by design, not `StepScaffold`'s scrolling card layout — a
/// review screen for a vertical/square/wide video wants as much of the
/// window as it can get, the same way Capture is full-screen (spec §6),
/// not a small mockup floating in whitespace.
struct PreviewStepView: View {
    @Bindable var model: EditorFlowModel
    let coordinator: AppCoordinator

    @State private var player: AVPlayer?
    @State private var isBuilding = true
    @State private var voiceover: VoiceoverViewModel?
    /// The voiceover the current player item was built with.
    @State private var builtVoiceover: Voiceover?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // `.aspectRatio(_, contentMode: .fit)` sizes against whatever
            // this ZStack proposes — which, unlike inside `StepScaffold`'s
            // ScrollView, is the actual bounded window/screen size — so the
            // video grows to fill as much of it as the real export ratio
            // allows, with no manual size math needed.
            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(model.project.exportSettings.previewAspectRatio.ratio, contentMode: .fit)
            } else if isBuilding {
                ProgressView("Building preview…").tint(.white)
            } else {
                Text(model.errorMessage ?? String(localized: "Couldn't build preview."))
                    .foregroundStyle(.white)
                    .padding()
            }

            VStack {
                Spacer()
                PrimaryButton(title: "Export", systemImage: "square.and.arrow.up", accessibilityID: "Export") {
                    player?.pause()
                    coordinator.advance(from: .preview)
                }
                .padding(Theme.Spacing.l)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Preview")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        // The video sits on black in both appearances, so the bar stays dark too.
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .toolbar {
            if model.canUseVoiceover {
                ToolbarItem(placement: .primaryAction) {
                    Button("AI Voiceover", systemImage: "waveform.and.person.filled") {
                        voiceover = model.makeVoiceoverModel()
                    }
                    .accessibilityIdentifier("preview.aiVoiceover")
                }
            }
        }
        .sheet(item: $voiceover, onDismiss: rebuildIfVoiceoverChanged) { voiceover in
            VoiceoverSheet(model: voiceover, onPlay: playWithVoiceover)
                #if os(iOS)
                // Medium detent keeps the video visible above while it plays.
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                #endif
        }
        .task { await buildPreview() }
        .onDisappear { player?.pause() }
    }

    // MARK: - Voiceover

    /// Rebuilds the preview with the current voiceover mixed in — the same audio the export
    /// will have — and plays it from the top.
    private func playWithVoiceover() async {
        await buildPreview()
    }

    private func rebuildIfVoiceoverChanged() {
        guard model.project.voiceover != builtVoiceover else { return }
        Task { await buildPreview() }
    }

    private func buildPreview() async {
        isBuilding = true
        player?.pause()
        builtVoiceover = model.project.voiceover
        if let item = await model.makePreviewItem() {
            PlaybackAudioSession.activate()
            let player = AVPlayer(playerItem: item)
            player.isMuted = false
            self.player = player
            player.play()
        }
        isBuilding = false
    }
}
