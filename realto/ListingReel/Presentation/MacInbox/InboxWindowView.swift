import SwiftUI

/// The "Inbox" window (opened from Home's toolbar button, or ⌘, → enable →
/// reopen): watched-folder status plus a checklist of draft projects you can
/// batch-export unattended. Deliberately doesn't reach into the wizard
/// (`AppCoordinator`/`AppRoute`) — a draft that needs property info, a
/// template, or music is edited the normal way from Home's project list
/// (every Inbox-created draft already appears there, since it's saved
/// through the same `ManageProjectsUseCase`). This window is purely the
/// batch-management surface.
struct InboxWindowView: View {
    @Bindable var model: InboxViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            SectionHeader(title: "Inbox", subtitle: statusSubtitle)

            if !model.isEnabled {
                disabledState
            } else if model.projects.isEmpty {
                emptyState
            } else {
                projectList
                footer
            }
        }
        .padding(Theme.Spacing.l)
        .frame(minWidth: 460, minHeight: 420)
        .screenBackground()
        .task { await model.onAppear() }
    }

    private var statusSubtitle: LocalizedStringKey {
        guard model.isEnabled else { return "Turn this on in Settings to start watching a folder." }
        if let folder = model.settings.watchedFolder {
            return "Watching \(folder.displayPath)"
        }
        return "Choose a folder to watch in Settings (⌘,)."
    }

    private var disabledState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Inbox is off")
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Enable it in Settings to auto-create drafts from a watched folder.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("No projects yet")
                .font(.headline)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Drop footage into the watched folder — a draft appears here automatically.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var projectList: some View {
        List(model.projects) { project in
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: model.selectedProjectIDs.contains(project.id) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(model.selectedProjectIDs.contains(project.id)
                        ? Theme.Palette.accent : Theme.Palette.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.propertyInfo.address.isEmpty ? project.name : project.propertyInfo.address)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(project.clips.count == 1
                        ? String(localized: "1 clip") : String(localized: "\(project.clips.count) clips"))
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                if !project.isReadyToExport {
                    Text("No clips").font(.caption2).foregroundStyle(Theme.Palette.danger)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { model.toggleSelection(project.id) }
        }
        .listStyle(.inset)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if model.isRunningBatch {
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Exporting…").foregroundStyle(Theme.Palette.textSecondary)
                }
            } else if let summary = model.lastBatchSummary {
                Text(summary).font(.footnote).foregroundStyle(Theme.Palette.textSecondary)
            }
            HStack(spacing: Theme.Spacing.m) {
                SecondaryButton(
                    title: "Export Selected (\(model.selectedProjectIDs.count))",
                    systemImage: "wand.and.stars",
                    accessibilityID: "inbox.exportSelectedButton"
                ) {
                    Task { await model.exportSelected() }
                }
                .disabled(model.selectedProjectIDs.isEmpty || model.isRunningBatch)

                PrimaryButton(
                    title: "Export All Drafts",
                    systemImage: "wand.and.stars",
                    isEnabled: !model.isRunningBatch,
                    accessibilityID: "inbox.exportAllButton"
                ) {
                    Task { await model.exportAllDrafts() }
                }
            }
        }
    }
}
