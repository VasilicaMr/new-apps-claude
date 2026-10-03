import Foundation
import ImageIO
import Vision
import FoundationModels

/// `ListingSheetReader` backed entirely on-device: Vision OCRs the photo, then the Apple
/// Intelligence language model (Foundation Models) structures that text into a
/// `PropertyInfo`. Nothing leaves the device, in keeping with the offline pitch (spec §1.4).
@available(iOS 26.0, macOS 26.0, *)
final class FoundationModelsListingSheetReader: ListingSheetReader {

    /// The on-device model's context window is small (~4K tokens, shared by instructions,
    /// prompt and response). A listing sheet's useful details are near the top anyway.
    private static let maxOCRCharacters = 6_000

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func readPropertyInfo(fromImage imageData: Data) async throws -> PropertyInfo {
        guard isAvailable else { throw ListingSheetScanError.unavailable }

        let text = try recognizeText(in: imageData)
        guard !text.isEmpty else { throw ListingSheetScanError.noTextFound }

        let session = LanguageModelSession(instructions: """
            You extract real estate listing details from OCR text of a printed listing sheet, \
            flyer or MLS printout. Use only information that appears in the text. \
            If a detail isn't in the text, leave that field null — never guess or invent one.
            """)
        do {
            let response = try await session.respond(
                to: "OCR text of the listing sheet:\n\n\(text.prefix(Self.maxOCRCharacters))",
                generating: ExtractedListing.self,
                options: GenerationOptions(sampling: .greedy))
            return response.content.propertyInfo
        } catch let error as LanguageModelSession.GenerationError {
            if case .assetsUnavailable = error { throw ListingSheetScanError.unavailable }
            throw ListingSheetScanError.failed
        }
    }

    // MARK: - OCR

    private func recognizeText(in imageData: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ListingSheetScanError.noTextFound
        }
        // Photos are usually stored rotated with an EXIF orientation flag; OCR needs it upright.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? UInt32)
            .flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        do {
            try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
        } catch {
            throw ListingSheetScanError.failed
        }
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}

// MARK: - Generable schema

@available(iOS 26.0, macOS 26.0, *)
@Generable
private struct ExtractedListing {
    @Guide(description: "The property's street address, with city/postcode if printed on the same lines")
    var address: String?

    @Guide(description: "Asking price exactly as printed, including currency symbol, e.g. \"$749,000\" or \"749.000 €\"")
    var price: String?

    @Guide(description: "Number of bedrooms")
    var bedrooms: Int?

    @Guide(description: "Number of bathrooms; a half bath counts as 0.5, e.g. 2.5")
    var bathrooms: Double?

    @Guide(description: "Interior living area as a number, without the unit")
    var livingArea: Double?

    @Guide(description: "The unit livingArea is printed in")
    var livingAreaUnit: AreaUnit?

    @Guide(description: "Short marketing banner printed on the sheet, such as \"Just Listed\", \"Open House Sat 2–4\" or \"Price Reduced\"")
    var headline: String?

    @Generable
    enum AreaUnit {
        case squareFeet
        case squareMeters
    }

    /// `PropertyInfo` always stores square feet; the card converts back to m² by locale.
    var propertyInfo: PropertyInfo {
        let squareFeet = livingArea.map { area -> Int in
            livingAreaUnit == .squareMeters ? Int((area * 10.7639).rounded()) : Int(area.rounded())
        }
        return PropertyInfo(
            address: address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            price: price?.trimmingCharacters(in: .whitespacesAndNewlines),
            beds: bedrooms,
            baths: bathrooms,
            squareFeet: squareFeet.flatMap { $0 > 0 ? $0 : nil },
            headline: headline?.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// Used on OS versions without Foundation Models; the UI hides scanning entirely.
struct UnavailableListingSheetReader: ListingSheetReader {
    var isAvailable: Bool { false }

    func readPropertyInfo(fromImage imageData: Data) async throws -> PropertyInfo {
        throw ListingSheetScanError.unavailable
    }
}
