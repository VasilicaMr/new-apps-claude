import SwiftUI
import Photos
import AVFoundation
import UniformTypeIdentifiers

/// Loads and shows a square thumbnail for a PHAsset local identifier.
struct AssetThumbnailView: View {
    let localIdentifier: String
    var side: CGFloat = 88

    @State private var image: PlatformImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.Palette.surfaceElevated)
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .task(id: localIdentifier) { await load() }
    }

    private func load() async {
        if localIdentifier.hasPrefix("file:") {
            image = await thumbnailFromFile(String(localIdentifier.dropFirst(5)))
        } else {
            image = await thumbnailFromPhotoKit(localIdentifier)
        }
    }

    private func thumbnailFromFile(_ path: String) async -> PlatformImage? {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        // Still-image file clips (Finder drag-and-drop, Photos-picker fallback) —
        // AVAssetImageGenerator below only understands movie files.
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) {
            return PlatformImage(contentsOfFile: path)
        }
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: side * 3, height: side * 3)
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        guard let cg = try? await gen.image(at: time).image else { return nil }
        return PlatformImage(cgImage: cg)
    }

    private func thumbnailFromPhotoKit(_ id: String) async -> PlatformImage? {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        let target = CGSize(width: side * 3, height: side * 3)

        return await withCheckedContinuation { continuation in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: target, contentMode: .aspectFill, options: options
            ) { img, _ in
                if let img, !resumed {
                    resumed = true
                    continuation.resume(returning: img)
                }
            }
        }
    }
}
