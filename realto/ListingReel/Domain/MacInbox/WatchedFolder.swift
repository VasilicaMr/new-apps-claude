import Foundation

/// A single Finder folder the Mac Inbox feature watches for new footage.
/// Pure Swift — no AppKit, no security-scope APIs here (those live in
/// `Data/MacInbox/SecurityScopedBookmark.swift`); this is just the persisted
/// shape of "which folder, and what have we already imported from it."
struct WatchedFolder: Codable, Equatable {
    /// A security-scoped bookmark (`URL.bookmarkData(options: .withSecurityScope, ...)`)
    /// for the user-chosen folder — required to keep read access across app
    /// relaunches under App Sandbox (the one-shot NSOpenPanel grant alone
    /// doesn't survive a relaunch).
    var bookmark: Data
    /// Human-readable path, shown in Settings — best-effort display only;
    /// the bookmark, not this string, is the source of truth for access.
    var displayPath: String
    /// Filenames already turned into a draft project, so a relaunch (or a
    /// debounce re-scan) doesn't re-import the same footage twice.
    var knownFilenames: Set<String>

    init(bookmark: Data, displayPath: String, knownFilenames: Set<String> = []) {
        self.bookmark = bookmark
        self.displayPath = displayPath
        self.knownFilenames = knownFilenames
    }
}

/// Persisted Mac Inbox feature state: the flag itself, plus the watched
/// folder once one has been chosen. Kept as one small struct so
/// `MacInboxSettingsRepository` has a single value to load/save (mirrors how
/// `BrandProfileRepository` persists one `BrandProfile`).
struct MacInboxSettings: Codable, Equatable {
    /// The visible Settings toggle ("Inbox (Beta)"). Off by default — this is
    /// the feature flag: when `false`, the Home toolbar entry point and the
    /// Inbox window are never shown (see `HomeView`/`InboxViewModel`).
    var isEnabled: Bool
    var watchedFolder: WatchedFolder?

    init(isEnabled: Bool = false, watchedFolder: WatchedFolder? = nil) {
        self.isEnabled = isEnabled
        self.watchedFolder = watchedFolder
    }
}
