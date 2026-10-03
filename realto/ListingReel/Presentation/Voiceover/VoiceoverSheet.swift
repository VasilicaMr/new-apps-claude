import SwiftUI

/// AI voiceover (Apple Intelligence, iOS 27 / macOS 27+). Label the rooms, let the on-device
/// model draft a ~30-second narration, edit it and pick a voice — the agent's own, if they've
/// set up Personal Voice. The narration is mixed into the preview and the exported video.
struct VoiceoverSheet: View {
    @Bindable var model: VoiceoverViewModel
    /// Rebuilds the preview with the narration mixed in and plays it from the top.
    let onPlay: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditingScript: Bool
    @State private var isPreparingPlayback = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    roomOrderSection
                    scriptSection
                    voiceSection
                }
                .padding(Theme.Spacing.l)
            }
            .safeAreaInset(edge: .bottom) { playBar }
            .screenBackground()
            .navigationTitle("AI Voiceover")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear { model.scriptEditingEnded() }
        .onChange(of: isEditingScript) { _, editing in
            if !editing { model.scriptEditingEnded() }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    // MARK: - Room order

    private var roomOrderSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Room order",
                          subtitle: "Tag what each clip shows so the narration follows the tour.")
            ForEach(Array(model.clips.enumerated()), id: \.element.id) { index, clip in
                HStack(spacing: Theme.Spacing.m) {
                    AssetThumbnailView(localIdentifier: clip.sourceIdentifier, side: 44)
                    Text(verbatim: "\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.Palette.textSecondary)
                    roomMenu(for: clip)
                    Spacer()
                }
            }
        }
    }

    private func roomMenu(for clip: MediaClip) -> some View {
        Menu {
            Button("No label") { model.setRoomLabel(nil, for: clip) }
            // Keep a custom label (e.g. from the capture shot list) pickable.
            if let current = clip.roomLabel, !VoiceoverViewModel.roomSuggestions.contains(current) {
                Button(current) { model.setRoomLabel(current, for: clip) }
            }
            ForEach(VoiceoverViewModel.roomSuggestions, id: \.self) { room in
                Button(room) { model.setRoomLabel(room, for: clip) }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Text(clip.roomLabel ?? String(localized: "Add room"))
                    .foregroundStyle(clip.roomLabel == nil ? Theme.Palette.textSecondary : Theme.Palette.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    // MARK: - Script

    private var scriptSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Script",
                          subtitle: "Written on your device from the property details. Edit anything before it's read.")

            Button {
                Task { await model.generateScript() }
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    if model.isWriting {
                        ProgressView()
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(model.isWriting ? "Writing…" : (model.hasScript ? "Rewrite script" : "Write script"))
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.m)
                .background(Theme.Palette.surfaceElevated)
                .foregroundStyle(Theme.Palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            }
            .buttonStyle(.plain)
            .disabled(model.isWriting)
            .accessibilityIdentifier("voiceover.writeScript")

            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.danger)
            }

            if model.hasScript || model.isWriting {
                TextEditor(text: $model.script)
                    .focused($isEditingScript)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(Theme.Spacing.s)
                    .background(Theme.Palette.surface)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .disabled(model.isWriting)
                    .accessibilityIdentifier("voiceover.script")

                Text("About \(model.estimatedSeconds) seconds read aloud")
                    .font(.caption)
                    .foregroundStyle(model.estimatedSeconds > 35 ? Theme.Palette.danger : Theme.Palette.textSecondary)
            }

            if model.hasScript {
                Label("Added to your exported video. Narration longer than the video is cut off at the end.",
                      systemImage: "film")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Button("Remove voiceover", role: .destructive) {
                    model.removeVoiceover()
                }
                .font(.caption)
                .accessibilityIdentifier("voiceover.remove")
            }
        }
    }

    // MARK: - Voice

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Voice")

            if !model.voices.isEmpty {
                Picker("Voice", selection: $model.selectedVoiceID) {
                    ForEach(model.voices) { voice in
                        Text(voice.isPersonalVoice
                             ? String(localized: "\(voice.name) (your Personal Voice)")
                             : voice.name)
                            .tag(Optional(voice.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.Palette.accent)
            }

            switch model.personalVoiceAccess {
            case .notDetermined:
                Button {
                    Task { await model.requestPersonalVoice() }
                } label: {
                    Label("Read it in my own voice", systemImage: "person.wave.2")
                }
                .tint(Theme.Palette.accent)
                Text("Uses the Personal Voice you've set up in Settings › Accessibility.")
                    .font(.caption).foregroundStyle(Theme.Palette.textSecondary)
            case .authorized where !model.voices.contains(where: \.isPersonalVoice):
                Text("No Personal Voice found. Create one in Settings › Accessibility › Personal Voice.")
                    .font(.caption).foregroundStyle(Theme.Palette.textSecondary)
            case .denied:
                Text("To use your own voice, allow Personal Voice access for Realto in Settings.")
                    .font(.caption).foregroundStyle(Theme.Palette.textSecondary)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Play

    private var playBar: some View {
        PrimaryButton(title: isPreparingPlayback ? "Preparing…" : "Play in preview", systemImage: "play.fill",
                      isEnabled: model.hasScript && !model.isWriting,
                      isLoading: isPreparingPlayback,
                      accessibilityID: "voiceover.play") {
            isEditingScript = false
            model.scriptEditingEnded()
            isPreparingPlayback = true
            Task {
                await onPlay()
                isPreparingPlayback = false
            }
        }
        .padding(Theme.Spacing.l)
        .background(.ultraThinMaterial)
    }
}
