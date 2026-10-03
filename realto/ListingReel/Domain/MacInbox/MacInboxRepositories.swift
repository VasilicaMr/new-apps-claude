import Foundation

/// Persistence of the Mac Inbox feature flag + watched folder (Domain owns
/// the interface — mirrors `BrandProfileRepository`/`ProjectRepository`).
protocol MacInboxSettingsRepository {
    func load() async throws -> MacInboxSettings
    func save(_ settings: MacInboxSettings) async throws
}

/// Reports batch-export completion. The concrete `UNUserNotificationCenter`
/// implementation lives in `Data/MacInbox` — Domain never imports
/// UserNotifications, same seam as `VideoRenderer` keeps AVFoundation out.
protocol ExportNotifying {
    func notifyBatchFinished(succeeded: Int, failed: Int) async
}

/// Classifies, durably copies, and builds `MediaClip`s for local file URLs —
/// the Finder-folder counterpart to `MediaRepository.makeClips(fromLocalIdentifiers:)`.
/// Concrete implementation (UTType classification, FileManager copy) lives in
/// `Data/MacInbox`; Domain only sees the seam.
protocol FileMediaImporting {
    /// Skips any URL that isn't recognizable video/photo media rather than
    /// throwing — a folder drop may contain non-media files (spec §9: never
    /// fail silently applies to *not losing* the media that IS valid, too).
    func makeClips(fromFileURLs urls: [URL], startingOrder: Int) -> [MediaClip]
}

/// Archives a finished batch export's output files somewhere durable once
/// rendering succeeds. The concrete implementation copies into a subfolder of
/// the watched Inbox folder itself (Data/MacInbox) — unattended batch export
/// has no user present to pick a destination via NSOpenPanel the way the
/// single-project "Save to Folder" flow does.
protocol ExportedFileArchiving {
    func archive(_ files: [ExportedFile], for project: Project) async throws
}
