import Foundation

/// Reads property details off a photo of a printed listing sheet / flyer / MLS printout.
/// Domain owns the interface; the on-device OCR + language model lives in Data.
protocol ListingSheetReader {
    /// False on devices without Apple Intelligence (or with it turned off) — the UI hides
    /// the feature entirely rather than offering something that can't work.
    var isAvailable: Bool { get }
    /// Returns only what's actually printed on the sheet; missing fields stay nil.
    func readPropertyInfo(fromImage imageData: Data) async throws -> PropertyInfo
}

enum ListingSheetScanError: LocalizedError, Equatable {
    case unavailable
    case noTextFound
    case noDetailsFound
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: "Scanning needs Apple Intelligence, which isn't available on this device.")
        case .noTextFound:
            return String(localized: "Couldn't find any text in that image. Try a sharper, well-lit photo of the sheet.")
        case .noDetailsFound:
            return String(localized: "Couldn't find property details on that sheet.")
        case .failed:
            return String(localized: "Couldn't read that sheet. Please try again.")
        }
    }
}
