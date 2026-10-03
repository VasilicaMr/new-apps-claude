import CoreTransferable
import UniformTypeIdentifiers

/// Extracts a playable file URL from a `PhotosPickerItem` that represents a
/// video.
///
/// `PhotosPickerItem.itemIdentifier` (the PHAsset local identifier the rest of
/// the import pipeline prefers — spec §5, zero-copy) is only populated when
/// the app already holds full Photos library authorization; it comes back
/// `nil` otherwise. Without this fallback, a video picked in that state was
/// silently dropped — nothing imported, no error, the wizard just sat there.
/// `MediaStepView` uses this as a fallback so import always produces a clip.
struct TransferableMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("import_\(UUID().uuidString)")
                .appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}
