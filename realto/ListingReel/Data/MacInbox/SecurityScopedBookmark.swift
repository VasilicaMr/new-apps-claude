import Foundation

/// Wraps the security-scoped bookmark dance for the one folder the Mac Inbox
/// feature watches. Under App Sandbox, the one-shot grant an `NSOpenPanel`
/// pick gives you doesn't survive a relaunch — a persisted, security-scoped
/// bookmark does. Works under the app's existing
/// `com.apple.security.files.user-selected.read-write` entitlement; no
/// additional entitlement is required for `.withSecurityScope` bookmarks.
enum SecurityScopedBookmark {

    /// Creates bookmark data for a folder the user just picked via `NSOpenPanel`.
    static func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: .withSecurityScope,
                             includingResourceValuesForKeys: nil,
                             relativeTo: nil)
    }

    /// Resolves previously-saved bookmark data back to a URL and starts
    /// security-scoped access. Call `stopAccessing` on the returned handle
    /// when done (or let it deinit — see `AccessHandle`).
    static func resolve(_ bookmark: Data) throws -> AccessHandle {
        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmark,
                          options: .withSecurityScope,
                          relativeTo: nil,
                          bookmarkDataIsStale: &isStale)
        guard url.startAccessingSecurityScopedResource() else {
            throw ResolutionError.accessDenied
        }
        return AccessHandle(url: url, isStale: isStale)
    }

    enum ResolutionError: LocalizedError {
        case accessDenied
        var errorDescription: String? {
            String(localized: "Realto lost access to the watched folder. Choose it again in Settings.")
        }
    }

    /// Balances `startAccessingSecurityScopedResource()`; stops access when
    /// the caller is done (explicitly, or on deinit as a safety net).
    final class AccessHandle {
        let url: URL
        /// True when the bookmark should be re-created (the folder moved,
        /// was renamed, or its volume changed) — the caller should persist a
        /// fresh bookmark for `url` if so.
        let isStale: Bool
        private var stopped = false

        fileprivate init(url: URL, isStale: Bool) {
            self.url = url
            self.isStale = isStale
        }

        func stopAccessing() {
            guard !stopped else { return }
            stopped = true
            url.stopAccessingSecurityScopedResource()
        }

        deinit { stopAccessing() }
    }
}
