import Photos
import Foundation

/// `MediaRepository` backed by PhotoKit. Bridges PHAssets ↔ domain `MediaClip`s
/// and writes finished exports back to the library. No bytes copied into app storage.
struct PhotoKitMediaService: MediaRepository {

    func requestAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let new = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return new == .authorized || new == .limited
        default:
            return false
        }
    }

    func makeClips(fromLocalIdentifiers ids: [String], startingOrder: Int) -> [MediaClip] {
        guard !ids.isEmpty else { return [] }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)

        // Preserve the order the user picked, not PhotoKit's fetch order.
        var byID: [String: PHAsset] = [:]
        fetch.enumerateObjects { asset, _, _ in byID[asset.localIdentifier] = asset }

        var order = startingOrder
        return ids.compactMap { id in
            guard let asset = byID[id] else { return nil }
            let kind: MediaKind = (asset.mediaType == .video) ? .video : .photo
            defer { order += 1 }
            return MediaClip(sourceIdentifier: id, kind: kind, order: order)
        }
    }

    func saveToPhotoLibrary(fileURL: URL) async throws {
        let granted = await requestAuthorization()
        guard granted else {
            throw RenderError.exportFailed(reason: String(localized: "Photo library access is needed to save your video."))
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: fileURL, options: nil)
        }
    }
}
