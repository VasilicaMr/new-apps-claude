import Foundation
import Vision

/// On-device OCR for earnings screenshots (Vision). Nothing leaves the iPhone.
struct ScreenshotTextReader: Sendable {
    enum ReadError: LocalizedError {
        case noText

        var errorDescription: String? { "No text found in this image. Use a screenshot of the earnings screen." }
    }

    /// Returns text fragments with positions (origin top-left).
    func fragments(in imageData: Data) async throws -> [TextFragment] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let preferred = [Locale.Language(identifier: "ro-RO"), Locale.Language(identifier: "en-US")]
        let supported = Set(request.supportedRecognitionLanguages.map(\.minimalIdentifier))
        request.recognitionLanguages = preferred.filter { supported.contains($0.minimalIdentifier) }

        let observations = try await request.perform(on: imageData)
        let fragments = observations.compactMap { observation -> TextFragment? in
            guard let text = observation.topCandidates(1).first?.string, !text.isEmpty else { return nil }
            let box = observation.boundingBox.cgRect // normalized, origin bottom-left
            return TextFragment(text: text, minX: box.minX, midY: 1 - box.midY, height: box.height)
        }
        guard !fragments.isEmpty else { throw ReadError.noText }
        return fragments
    }
}
