import Foundation
import UniformTypeIdentifiers

/// Concrete `FileMediaImporting`: classifies local file URLs by `UTType` and
/// copies recognized media into the durable Imports folder, building
/// `MediaClip`s with the same `"file:<path>"` `sourceIdentifier` convention
/// the wizard's Finder-drop import already uses (`MediaStepView.swift`) —
/// consumed unchanged by `AVAssetResolver` at render time.
///
/// Unlike the wizard's drop handler (which copies into
/// `NSTemporaryDirectory()`), this copies into `MacInboxSettingsStore`'s
/// `importsDirectory` so footage survives an app relaunch — the watcher may
/// discover a project's clips long before anyone opens the app to export them.
struct FileMediaImportService: FileMediaImporting {
    let importsDirectory: URL
    private let fileManager = FileManager.default

    func makeClips(fromFileURLs urls: [URL], startingOrder: Int) -> [MediaClip] {
        try? fileManager.createDirectory(at: importsDirectory, withIntermediateDirectories: true)

        var order = startingOrder
        var clips: [MediaClip] = []
        for url in urls {
            guard let kind = mediaKind(for: url), let copied = copyIntoImportsFolder(url) else { continue }
            clips.append(MediaClip(sourceIdentifier: "file:\(copied.path)", kind: kind, order: order))
            order += 1
        }
        return clips
    }

    private func mediaKind(for url: URL) -> MediaKind? {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .image) { return .photo }
        return nil
    }

    private func copyIntoImportsFolder(_ url: URL) -> URL? {
        let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension
        let dest = importsDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        do {
            try fileManager.copyItem(at: url, to: dest)
            return dest
        } catch {
            return nil
        }
    }
}
