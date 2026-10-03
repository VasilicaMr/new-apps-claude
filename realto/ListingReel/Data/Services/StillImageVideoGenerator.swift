import AVFoundation

/// Turns a still photo into a short video segment so photos can live on the same
/// AVMutableComposition video track as real clips (spec §4.1, §4.5 photos checklist).
/// Uses AVAssetWriter — fully offline, no network.
struct StillImageVideoGenerator {

    enum GeneratorError: Error { case setupFailed, writeFailed }

    /// Renders `image` as an H.264 video of `duration` seconds at `size`.
    /// Returns the temp file URL. Caller owns cleanup.
    func makeVideo(from image: PlatformImage, duration: TimeInterval, size: CGSize) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("still_\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input, sourcePixelBufferAttributes: attrs)

        guard writer.canAdd(input) else { throw GeneratorError.setupFailed }
        writer.add(input)

        guard writer.startWriting() else { throw GeneratorError.setupFailed }
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let frameCount = max(1, Int(duration * Double(fps)))
        guard let buffer = pixelBuffer(from: image, size: size, attrs: attrs) else {
            writer.cancelWriting()
            throw GeneratorError.writeFailed
        }

        // The same buffer is presented for every frame; motion (Ken Burns) is applied
        // later as a layer transform in the video composition, keeping memory flat.
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            let time = CMTime(value: CMTimeValue(frame), timescale: fps)
            adaptor.append(buffer, withPresentationTime: time)
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            throw GeneratorError.writeFailed
        }
        return url
    }

    private func pixelBuffer(from image: PlatformImage, size: CGSize, attrs: [String: Any]) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, Int(size.width), Int(size.height),
            kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pb)
        guard status == kCVReturnSuccess, let buffer = pb else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        // Aspect-fill the image into the buffer, centered.
        context.setFillColor(PlatformColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        if let cg = image.cgImage {
            let imgSize = CGSize(width: cg.width, height: cg.height)
            let scale = max(size.width / imgSize.width, size.height / imgSize.height)
            let drawSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
            let origin = CGPoint(x: (size.width - drawSize.width) / 2,
                                 y: (size.height - drawSize.height) / 2)
            context.draw(cg, in: CGRect(origin: origin, size: drawSize))
        }
        return buffer
    }
}
