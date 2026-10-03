import Foundation

/// Copies a finished batch export's output files into
/// `<watched folder>/Exports/<listing>/` — unattended batch export has no
/// user present to pick a destination the way the single-project "Save to
/// Folder" flow does (`ExportViewModel.saveAllToFolder`, which this
/// deliberately mirrors rather than reaches into, to keep Mac Inbox
/// self-contained). Drop footage in, find finished videos back in the same
/// place.
struct WatchedFolderExportArchiver: ExportedFileArchiving {
    let settingsRepository: MacInboxSettingsRepository

    func archive(_ files: [ExportedFile], for project: Project) async throws {
        let settings = try await settingsRepository.load()
        // No watched folder configured — nothing to archive into. Rendered
        // files still exist at their temp `ExportedFile.url`; this is only
        // reachable via the Inbox queue, which always operates on
        // Inbox-created drafts, so a missing folder here means the user
        // cleared it mid-run. Not an error worth surfacing per-file.
        guard let watchedFolder = settings.watchedFolder else { return }

        let handle = try SecurityScopedBookmark.resolve(watchedFolder.bookmark)
        defer { handle.stopAccessing() }

        let destinationDir = handle.url
            .appendingPathComponent("Exports", isDirectory: true)
            .appendingPathComponent(folderFileBaseName(for: project), isDirectory: true)
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)

        for file in files {
            let dest = destinationDir.appendingPathComponent(file.url.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)   // overwrite on re-export
            try FileManager.default.copyItem(at: file.url, to: dest)
        }
    }

    /// A friendly, filesystem-safe folder name — mirrors
    /// `ExportViewModel.folderFileBaseName()`'s convention (listing address
    /// when there is one) so Finder output looks the same either way.
    private func folderFileBaseName(for project: Project) -> String {
        let address = project.propertyInfo.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = address.isEmpty ? project.name : address
        return raw.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
    }
}
