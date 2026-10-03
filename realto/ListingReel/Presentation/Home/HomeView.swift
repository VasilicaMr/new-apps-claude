import SwiftUI

/// Home — list of past projects + a prominent "New Video" CTA. First-run empty
/// state invites creation with ZERO account friction (spec §6 design rules).
struct HomeView: View {
    @Bindable var model: HomeViewModel
    let coordinator: AppCoordinator
    @State private var projectPendingDelete: Project?

    #if os(macOS)
    // Mac Inbox is feature-flagged and off by default (spec §3.7) — reading
    // it live from the environment means flipping the Settings toggle shows
    // or hides this button immediately, no relaunch needed.
    @Environment(InboxViewModel.self) private var inboxModel
    @Environment(\.openWindow) private var openWindow
    #endif

    #if DEBUG
    // Pulled out of the toolbar builder below — inlining this Binding's
    // closures there overwhelmed the type checker ("unable to type-check
    // this expression in reasonable time").
    private var demoDataBinding: Binding<Bool> {
        Binding(get: { coordinator.isDemoModeEnabled },
                set: { coordinator.isDemoModeEnabled = $0 })
    }
    #endif

    var body: some View {
        Group {
            if model.projects.isEmpty && !model.isLoading {
                emptyState
            } else {
                projectList
            }
        }
        .navigationTitle("Realto")
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "New Video", systemImage: "plus", accessibilityID: "home.newVideoButton") {
                coordinator.startNewProject()
            }
            .padding(Theme.Spacing.l)
            .background(.ultraThinMaterial)
        }
        #if os(macOS)
        .toolbar {
            if inboxModel.isEnabled {
                ToolbarItem {
                    Button {
                        openWindow(id: "mac-inbox")
                    } label: {
                        Label("Inbox", systemImage: "tray.and.arrow.down")
                    }
                }
            }
        }
        // The watcher creates drafts on a background task independent of
        // whichever window is open — refresh if one lands while Home is visible.
        .onReceive(NotificationCenter.default.publisher(for: .macInboxDidCreateProject)) { _ in
            Task { await model.load() }
        }
        #endif
        #if DEBUG
        // Dev-only convenience (never compiled into Release, see
        // DemoMode.swift): fills the list with realistic fake listings so
        // the app can be demoed/screenshotted without real Photos footage.
        .toolbar {
            ToolbarItem {
                Toggle(isOn: demoDataBinding) {
                    Label("Demo Data", systemImage: "sparkles")
                }
                .toggleStyle(.button)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .demoDataDidChange)) { _ in
            Task { await model.load() }
        }
        #endif
        .task { await model.load() }
        // `HomeView`'s `.task` above only ever runs once, on first appearance
        // — the wizard's steps are pushed onto the *same* NavigationStack, so
        // Home is never removed/re-added while creating, editing, or
        // exporting a project, just covered up. Without this, finishing a
        // project ("Done" after export, or backing all the way out) would
        // leave the list showing whatever it was before that project existed.
        // Reload every time we're back at the root, on any platform.
        // (`NavigationPath` itself isn't `Equatable`, so watch its count.)
        .onChange(of: coordinator.path.count) { _, newCount in
            if newCount == 0 {
                Task { await model.load() }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Palette.accent)
            Text("Turn raw walkthroughs into\nbranded listing videos")
                .multilineTextAlignment(.center)
                .font(.title3.bold())
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("No account. Works offline. Under 5 minutes.")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
        }
        .padding(Theme.Spacing.xl)
    }

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.m) {
                ForEach(model.projects) { project in
                    projectRow(project)
                }
            }
            .padding(Theme.Spacing.l)
        }
        // Single confirmation flow shared by the corner X and the long-press
        // context menu below — deleting a project can't be undone, and the
        // X sits close enough to the open-project tap target to fat-finger.
        .confirmationDialog(
            "Delete this listing?",
            isPresented: Binding(
                get: { projectPendingDelete != nil },
                set: { if !$0 { projectPendingDelete = nil } }
            ),
            presenting: projectPendingDelete
        ) { project in
            Button("Delete", role: .destructive) {
                Task { await model.delete(project) }
            }
        } message: { _ in
            Text("This removes the listing and its clips. This can't be undone.")
        }
    }

    private func projectRow(_ project: Project) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                coordinator.openProject(project)
            } label: {
                HStack(spacing: Theme.Spacing.m) {
                    if let first = project.orderedClips.first {
                        AssetThumbnailView(localIdentifier: first.sourceIdentifier, side: 64)
                    } else {
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .fill(Theme.Palette.surfaceElevated)
                            .frame(width: 64, height: 64)
                            .overlay { Image(systemName: "film").foregroundStyle(Theme.Palette.textSecondary) }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.propertyInfo.address.isEmpty ? project.name : project.propertyInfo.address)
                            .font(.headline).foregroundStyle(Theme.Palette.textPrimary)
                            .lineLimit(1)
                        Text(clipsSubtitle(for: project))
                            .font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.Palette.textSecondary)
                }
                .padding(Theme.Spacing.m)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    coordinator.startOpenHousePost(from: project)
                } label: {
                    Label("New Open House Post", systemImage: "calendar.badge.plus")
                }
                Button(role: .destructive) {
                    projectPendingDelete = project
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            Button {
                projectPendingDelete = project
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.Palette.textSecondary, Theme.Palette.surfaceElevated)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel("Delete listing")
            .accessibilityIdentifier("home.deleteProjectButton")
        }
    }

    private func clipsSubtitle(for project: Project) -> String {
        let date = project.updatedAt.formatted(date: .abbreviated, time: .omitted)
        let count = project.clips.count
        let clipsPart = count == 1 ? String(localized: "1 clip") : String(localized: "\(count) clips")
        return "\(clipsPart) · \(date)"
    }
}
