import Foundation

/// Watches one folder for new files using `DispatchSource`, not polling.
/// Debounces bursts of activity and waits for a file's size to stop changing
/// before reporting it — AirDrop/large-file copies fire write events well
/// before the file is finished, and importing a half-copied video would be
/// exactly the kind of silent-failure the render pipeline works hard to avoid
/// (spec §4.5). Classification (media vs. not) happens downstream in
/// `FileMediaImportService`; this service only decides *when* a file is safe
/// to hand off.
final class FolderWatcherService {
    typealias NewFilesHandler = (_ urls: [URL]) -> Void

    private let debounce: TimeInterval
    private let queue = DispatchQueue(label: "com.adaptiveservices.realto.macinbox.folderwatcher")

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var pendingWork: DispatchWorkItem?
    private var watchedFolderURL: URL?
    private var onNewFiles: NewFilesHandler?

    /// Filenames already reported (or confirmed not to be media) — never
    /// re-reported for the lifetime of this `start`/`stop` cycle. The
    /// caller reads `knownFilenames` after handling a batch and persists it
    /// into `WatchedFolder.knownFilenames` so a relaunch doesn't rescan them.
    private(set) var seenFilenames: Set<String>
    /// Files seen but not yet size-stable across two scans.
    private var pendingSizes: [String: Int] = [:]

    private(set) var isWatching = false

    init(debounce: TimeInterval = 2.0) {
        self.debounce = debounce
        self.seenFilenames = []
    }

    /// Starts watching `folderURL`, which must already have active
    /// security-scoped access (see `SecurityScopedBookmark`) for the
    /// lifetime of the watch. `knownFilenames` seeds what's already been
    /// imported so the first scan doesn't re-report old footage.
    func start(watching folderURL: URL, knownFilenames: Set<String>, onNewFiles: @escaping NewFilesHandler) {
        stop()
        watchedFolderURL = folderURL
        seenFilenames = knownFilenames
        self.onNewFiles = onNewFiles

        let fd = open(folderURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: queue)
        src.setEventHandler { [weak self] in self?.scheduleScan() }
        src.setCancelHandler { [weak self] in
            guard let self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }
        src.resume()
        source = src
        isWatching = true

        scheduleScan()   // catch files already present when watching begins
    }

    func stop() {
        pendingWork?.cancel()
        pendingWork = nil
        source?.cancel()
        source = nil
        watchedFolderURL = nil
        onNewFiles = nil
        pendingSizes = [:]
        isWatching = false
    }

    private func scheduleScan() {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.scan() }
        pendingWork = work
        queue.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    private func scan() {
        guard let folderURL = watchedFolderURL else { return }
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: folderURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])) ?? []
        let candidates = entries.filter { !seenFilenames.contains($0.lastPathComponent) }

        var confirmed: [URL] = []
        var stillPending: [String: Int] = [:]
        for url in candidates {
            let name = url.lastPathComponent
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? -1
            if let previousSize = pendingSizes[name], previousSize == size {
                confirmed.append(url)
                seenFilenames.insert(name)
            } else {
                stillPending[name] = size
            }
        }
        pendingSizes = stillPending

        if !confirmed.isEmpty {
            onNewFiles?(confirmed)
        }
        if !pendingSizes.isEmpty {
            scheduleScan()   // still-copying files — check size stability again shortly
        }
    }

    deinit { stop() }
}
