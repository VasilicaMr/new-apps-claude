import Foundation

/// Owns the Mac Inbox feature end to end: the flag + watched-folder settings,
/// the folder watcher's lifecycle, turning newly discovered footage into
/// draft projects, and running the batch export queue. Long-lived — created
/// once in `DIContainer` (like `SubscriptionManager`) and shared by the
/// Settings scene and the Inbox window, so watching keeps running
/// independent of whichever window happens to be open.
@Observable
@MainActor
final class InboxViewModel {
    var settings = MacInboxSettings()
    var projects: [Project] = []
    var selectedProjectIDs: Set<Project.ID> = []
    var isRunningBatch = false
    var lastBatchSummary: String?
    var folderAccessError: String?

    private let settingsRepository: MacInboxSettingsRepository
    private let manageProjects: ManageProjectsUseCase
    private let importFolderMedia: ImportFolderMediaUseCase
    private let batchExportQueue: BatchExportQueueUseCase
    private let subscriptionManager: SubscriptionManager
    private let watcher = FolderWatcherService()
    private var folderAccessHandle: SecurityScopedBookmark.AccessHandle?

    init(
        settingsRepository: MacInboxSettingsRepository,
        manageProjects: ManageProjectsUseCase,
        importFolderMedia: ImportFolderMediaUseCase,
        batchExportQueue: BatchExportQueueUseCase,
        subscriptionManager: SubscriptionManager
    ) {
        self.settingsRepository = settingsRepository
        self.manageProjects = manageProjects
        self.importFolderMedia = importFolderMedia
        self.batchExportQueue = batchExportQueue
        self.subscriptionManager = subscriptionManager
    }

    var isEnabled: Bool { settings.isEnabled }

    // MARK: - Lifecycle

    /// Safe to call more than once (Settings and the Inbox window both call
    /// it on appear) — just reloads the current state.
    func onAppear() async {
        settings = (try? await settingsRepository.load()) ?? MacInboxSettings()
        await reloadProjects()
        syncWatcherToSettings()
    }

    func reloadProjects() async {
        projects = (try? await manageProjects.all()) ?? []
    }

    // MARK: - Settings

    func setEnabled(_ enabled: Bool) {
        settings.isEnabled = enabled
        persistSettings()
        syncWatcherToSettings()
    }

    func chooseFolder(_ url: URL) {
        do {
            let bookmark = try SecurityScopedBookmark.makeBookmark(for: url)
            settings.watchedFolder = WatchedFolder(bookmark: bookmark, displayPath: url.path)
            folderAccessError = nil
            persistSettings()
            syncWatcherToSettings()
        } catch {
            folderAccessError = error.localizedDescription
        }
    }

    func stopWatchingFolder() {
        settings.watchedFolder = nil
        persistSettings()
        syncWatcherToSettings()
    }

    private func persistSettings() {
        let snapshot = settings
        Task { try? await settingsRepository.save(snapshot) }
    }

    // MARK: - Watching

    private func syncWatcherToSettings() {
        folderAccessHandle?.stopAccessing()
        folderAccessHandle = nil
        watcher.stop()

        guard settings.isEnabled, let watchedFolder = settings.watchedFolder else { return }
        do {
            let handle = try SecurityScopedBookmark.resolve(watchedFolder.bookmark)
            folderAccessHandle = handle
            watcher.start(watching: handle.url, knownFilenames: watchedFolder.knownFilenames) { [weak self] urls in
                Task { @MainActor in
                    await self?.handleNewFiles(urls)
                }
            }
            folderAccessError = nil
        } catch {
            folderAccessError = error.localizedDescription
        }
    }

    private func handleNewFiles(_ urls: [URL]) async {
        var project = manageProjects.newProject()
        project.name = String(localized:
            "Inbox Import — \(Date.now.formatted(date: .abbreviated, time: .shortened))")
        importFolderMedia.appendClips(fromFileURLs: urls, to: &project)

        // Mark every discovered filename as seen either way — a non-media
        // file (e.g. a stray .DS_Store) should never be retried on every
        // scan (spec §9 "never fail silently" is about losing real media,
        // not about re-flagging junk forever).
        settings.watchedFolder?.knownFilenames = watcher.seenFilenames
        persistSettings()

        guard !project.clips.isEmpty else { return }
        try? await manageProjects.save(project)
        await reloadProjects()
        NotificationCenter.default.post(name: .macInboxDidCreateProject, object: nil)
    }

    // MARK: - Batch export

    func toggleSelection(_ id: Project.ID) {
        if selectedProjectIDs.contains(id) { selectedProjectIDs.remove(id) }
        else { selectedProjectIDs.insert(id) }
    }

    func exportSelected() async {
        await runBatch(projects.filter { selectedProjectIDs.contains($0.id) && $0.isReadyToExport })
    }

    func exportAllDrafts() async {
        await runBatch(projects.filter(\.isReadyToExport))
    }

    private func runBatch(_ toExport: [Project]) async {
        guard !toExport.isEmpty, !isRunningBatch else { return }
        isRunningBatch = true
        lastBatchSummary = nil

        // Apply subscription-aware watermark flag before rendering — same
        // pattern as the interactive `ExportStepView` footer.
        let watermarked = toExport.map { project -> Project in
            var copy = project
            copy.exportSettings.includeWatermark = !subscriptionManager.isUnlocked
            return copy
        }

        let outcomes = await batchExportQueue.run(projects: watermarked)
        isRunningBatch = false

        let succeeded = outcomes.filter {
            if case .success = $0.result { return true }
            return false
        }.count
        lastBatchSummary = succeeded == outcomes.count
            ? String(localized: "Exported \(succeeded) of \(outcomes.count).")
            : String(localized: "Exported \(succeeded) of \(outcomes.count) — open a failed project to see why and retry.")

        await reloadProjects()
    }
}

extension Notification.Name {
    /// Posted whenever the watcher creates a draft project, so `HomeView`
    /// can refresh its list without polling.
    static let macInboxDidCreateProject = Notification.Name("com.adaptiveservices.realto.macInboxDidCreateProject")
}
