import Foundation
import Observation
import Photos
import UIKit

/// Finds new earnings screenshots in Photos and reads them automatically, so the driver only taps "Add".
///
/// Only screenshots (not photos) taken in the last 3 days are looked at, at most a few per run, and only
/// those whose text looks like an earnings screen are offered. Images are read on the iPhone and never stored.
@MainActor
@Observable
final class ScreenshotInbox {
    struct Item: Identifiable {
        let id: String
        let takenAt: Date
        let result: ScreenshotEarnings
        let shift: Shift?
    }

    private(set) var items: [Item] = []
    private(set) var isScanning = false
    private(set) var authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    private let processedKey = "screenshotInbox.processedIDs"
    private let lastScanKey = "screenshotInbox.lastScan"
    private var processed: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: processedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue.suffix(300)), forKey: processedKey) }
    }

    var isEnabled: Bool { UserDefaults.standard.object(forKey: SettingsKeys.autoImportScreenshots) as? Bool ?? true }
    var hasAccess: Bool { authorization == .authorized || authorization == .limited }

    func requestAccess() async {
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func scanRecent(data: DriverData, useAppleIntelligence: Bool) async {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard isEnabled, hasAccess, !isScanning else { return }
        // Don't rescan more than once a minute when the app goes back and forth.
        if let last = UserDefaults.standard.object(forKey: lastScanKey) as? Date, Date.now.timeIntervalSince(last) < 60 { return }
        UserDefaults.standard.set(Date.now, forKey: lastScanKey)
        isScanning = true
        defer { isScanning = false }

        let options = PHFetchOptions()
        let since = Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now
        options.predicate = NSPredicate(format: "(mediaSubtypes & %d) != 0 AND creationDate > %@",
                                        PHAssetMediaSubtype.photoScreenshot.rawValue, since as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 8
        let assets = PHAsset.fetchAssets(with: .image, options: options)

        var seen = processed
        for index in 0..<assets.count {
            let asset = assets.object(at: index)
            guard !seen.contains(asset.localIdentifier), !items.contains(where: { $0.id == asset.localIdentifier }) else { continue }
            seen.insert(asset.localIdentifier)
            guard let imageData = await Self.imageData(for: asset) else { continue }
            await ingest(imageData, id: asset.localIdentifier, takenAt: asset.creationDate ?? .now,
                         data: data, useAppleIntelligence: useAppleIntelligence)
        }
        processed = seen
    }

    /// Reads one image and offers it on Home if it shows earnings. Returns whether it was offered.
    @discardableResult
    func ingest(_ imageData: Data, id: String, takenAt: Date, data: DriverData, useAppleIntelligence: Bool) async -> Bool {
        let scanner = EarningsScreenshotScanner(useAppleIntelligence: useAppleIntelligence)
        guard let result = try? await scanner.scan(imageData),
              EarningsTextParser().looksLikeEarningsScreen(result.recognizedLines), !result.isEmpty else { return false }
        items.append(Item(id: id, takenAt: takenAt, result: result, shift: data.shift(at: takenAt)))
        return true
    }

    /// Saves the screenshot's earnings, linked to the shift it was taken during or right after.
    func accept(_ item: Item, data: DriverData) {
        let result = item.result
        let draft = EarningDraft(platform: result.platform ?? .uber, fares: result.fares ?? result.total ?? 0,
                                 tips: result.tips ?? 0, bonus: result.bonus ?? 0, trips: result.trips ?? 0)
        data.add(draft, date: result.date ?? item.takenAt, shift: item.shift)
        items.removeAll { $0.id == item.id }
    }

    func dismiss(_ item: Item) {
        items.removeAll { $0.id == item.id }
    }

    private static func imageData(for asset: PHAsset) async -> Data? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
}

extension EarningsTextParser {
    /// True when the text has the vocabulary of an earnings screen, so random screenshots with prices are skipped.
    func looksLikeEarningsScreen(_ lines: [String]) -> Bool {
        let folded = lines.joined(separator: " ").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let words = Set(folded.split { !$0.isLetter }.map(String.init))
        let vocabulary: Set<String> = ["earnings", "fare", "fares", "tips", "tip", "trips", "promotions", "castiguri", "tarif",
                                       "bacsis", "bacsisuri", "curse", "promotii", "rides", "uber", "bolt", "freenow"]
        return words.intersection(vocabulary).count >= 2
    }
}
