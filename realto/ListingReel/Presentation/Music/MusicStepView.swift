import SwiftUI

/// Step 5 — Pick music. Bundled, licensed tracks; auto-fit to video length.
struct MusicStepView: View {
    @Bindable var model: EditorFlowModel
    let coordinator: AppCoordinator

    var body: some View {
        StepScaffold(route: .music) {
            SectionHeader(title: "Add music",
                          subtitle: "Licensed tracks, auto-fit to your video length.")

            noneRow

            ForEach(model.musicTracks) { track in
                trackRow(track)
            }
        } footer: {
            PrimaryButton(title: "Continue", systemImage: "arrow.right", accessibilityID: "Continue") {
                coordinator.advance(from: .music)
            }
        }
    }

    private var noneRow: some View {
        row(title: String(localized: "No music"), subtitle: String(localized: "Keep original clip audio"),
            icon: "speaker.slash", selected: model.project.musicTrackID == nil) {
            model.selectMusic(nil)
        }
    }

    private func trackRow(_ track: MusicTrack) -> some View {
        row(title: track.title, subtitle: "\(track.mood) · \(Int(track.durationSeconds))s",
            icon: "music.note", selected: model.project.musicTrackID == track.id) {
            model.selectMusic(track)
        }
    }

    private func row(title: String, subtitle: String, icon: String,
                     selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Theme.Palette.textPrimary)
                    Text(subtitle).font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.Palette.accent : Theme.Palette.textSecondary)
            }
            .padding(Theme.Spacing.m)
            .cardSurface(radius: Theme.Radius.control)
        }
    }
}
