import Foundation

/// Bring media into a project from a Finder folder (Mac Inbox). The direct
/// counterpart to `ImportMediaUseCase.appendClips(localIdentifiers:to:)` in
/// `Domain/UseCases/ProjectUseCases.swift` — same shape, different source.
struct ImportFolderMediaUseCase {
    let importer: FileMediaImporting

    /// Appends clips built from `urls` to `project`, preserving existing order.
    func appendClips(fromFileURLs urls: [URL], to project: inout Project) {
        let startOrder = (project.clips.map(\.order).max() ?? -1) + 1
        let newClips = importer.makeClips(fromFileURLs: urls, startingOrder: startOrder)
        project.clips.append(contentsOf: newClips)
    }
}
