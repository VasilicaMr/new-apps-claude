import SwiftUI

/// "New Open House Post": one listing, many posts. Reuses the listing's footage, style,
/// music and branding; the agent only picks the date and time.
struct OpenHouseSheet: View {
    @Bindable var model: OpenHouseViewModel
    let onCreated: (Project) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    SectionHeader(title: "When is it?",
                                  subtitle: "Uses the footage, style and music from \(model.listingTitle).")
                    timeSection
                    badgePreview
                    aiNote
                    if let error = model.errorMessage {
                        Text(error).font(.caption).foregroundStyle(Theme.Palette.danger)
                    }
                    if let notice = model.notice {
                        Label(notice, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .safeAreaInset(edge: .bottom) { createBar }
            .screenBackground()
            .navigationTitle("New Open House Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(model.isCreating)
                }
            }
        }
        .interactiveDismissDisabled(model.isCreating)
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 440)
        #endif
    }

    private var timeSection: some View {
        VStack(spacing: Theme.Spacing.s) {
            DatePicker("Starts", selection: $model.start, displayedComponents: [.date, .hourAndMinute])
            DatePicker("Ends", selection: $model.end, displayedComponents: .hourAndMinute)
            if !model.schedule.isValid {
                Text("The end time needs to be after the start.")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(Theme.Spacing.m)
        .cardSurface(radius: Theme.Radius.control)
        .disabled(model.isCreating || model.createdProject != nil)
    }

    private var badgePreview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("On the title card")
                .font(.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(model.schedule.isValid ? model.schedule.badge().uppercased() : "—")
                .font(.headline)
                .foregroundStyle(Theme.Palette.accent)
        }
    }

    @ViewBuilder
    private var aiNote: some View {
        if model.writesWithAppleIntelligence {
            Label(model.writesVoiceover
                  ? LocalizedStringKey("Apple Intelligence writes a new narration and post caption on your device.")
                  : LocalizedStringKey("Apple Intelligence writes the post caption on your device."),
                  systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        } else {
            Label("Comes with a ready-to-paste post caption.", systemImage: "text.quote")
                .font(.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    @ViewBuilder
    private var createBar: some View {
        Group {
            if let project = model.createdProject {
                PrimaryButton(title: "Open Post", systemImage: "arrow.right",
                              accessibilityID: "openHouse.openButton") {
                    onCreated(project)
                }
            } else {
                PrimaryButton(title: model.isCreating ? "Writing your post…" : "Create Post",
                              systemImage: "calendar.badge.plus",
                              isEnabled: model.canCreate,
                              isLoading: model.isCreating,
                              accessibilityID: "openHouse.createButton") {
                    Task {
                        if let project = await model.create() { onCreated(project) }
                    }
                }
            }
        }
        .padding(Theme.Spacing.l)
        .background(.ultraThinMaterial)
    }
}
