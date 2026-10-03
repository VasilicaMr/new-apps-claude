import SwiftUI
import AVFoundation

/// A horizontal strip of video frame thumbnails generated from an `AVAsset`.
/// Uses the async `AVAssetImageGenerator` API (iOS 16+). Each frame is
/// equally spaced across the full duration.
struct VideoThumbnailStrip: View {
    let asset: AVAsset
    let duration: TimeInterval
    var frameCount: Int = 12
    var height: CGFloat = 80

    @State private var frames: [PlatformImage?] = []

    var body: some View {
        GeometryReader { geo in
            let frameWidth = geo.size.width / CGFloat(frameCount)
            HStack(spacing: 0) {
                ForEach(0..<frameCount, id: \.self) { i in
                    Group {
                        if frames.indices.contains(i), let img = frames[i] {
                            Image(platformImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay {
                                    if frames.isEmpty {
                                        ProgressView().scaleEffect(0.5)
                                    }
                                }
                        }
                    }
                    .frame(width: frameWidth, height: height)
                    .clipped()
                }
            }
        }
        .frame(height: height)
        .task(id: ObjectIdentifier(asset)) { await generate() }
    }

    private func generate() async {
        frames = Array(repeating: nil, count: frameCount)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 100, height: 100)

        let step = max(duration / Double(frameCount - 1), 0.001)
        for i in 0..<frameCount {
            let t = CMTime(seconds: Double(i) * step, preferredTimescale: 600)
            if let cg = try? await generator.image(at: t).image {
                var updated = frames
                updated[i] = PlatformImage(cgImage: cg)
                frames = updated
            }
        }
    }
}
