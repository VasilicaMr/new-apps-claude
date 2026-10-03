import Foundation

/// Shared filesystem locations for the Mac Inbox feature. Pulled out as
/// plain, non-isolated statics (rather than actor-isolated computed
/// properties on `MacInboxSettingsStore`) so the composition root can
/// reference them synchronously while wiring dependencies in `DIContainer.init`.
enum MacInboxPaths {
    static var baseDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("ListingReel/MacInbox", isDirectory: true)
    }

    /// Durable storage for footage copied out of a watched folder — not
    /// `NSTemporaryDirectory()` (that's what the wizard's Finder-drop import
    /// uses); this needs to survive relaunches (spec §5).
    static var importsDirectory: URL {
        baseDirectory.appendingPathComponent("Imports", isDirectory: true)
    }
}
