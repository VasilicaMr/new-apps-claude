import Foundation

/// The central aggregate: a single listing video project.
/// Pure Swift — no AVFoundation, no SwiftUI, no PhotoKit.
struct Project: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var propertyInfo: PropertyInfo
    var clips: [MediaClip]                // ordered by `order`
    var templateID: Template.ID
    var musicTrackID: MusicTrack.ID?
    var brandProfileID: BrandProfile.ID?
    var exportSettings: ExportSettings
    /// The agent's AI voiceover. Mixed into the preview and export when the feature is
    /// available on this device; otherwise ignored.
    var voiceover: Voiceover?
    /// Set when this video announces an open house (made with "New Open House Post").
    var openHouse: OpenHouseSchedule?
    /// The social post caption to paste alongside the video; nil until written or edited.
    var socialCaption: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Untitled Listing",
        propertyInfo: PropertyInfo = .init(),
        clips: [MediaClip] = [],
        templateID: Template.ID,
        musicTrackID: MusicTrack.ID? = nil,
        brandProfileID: BrandProfile.ID? = nil,
        exportSettings: ExportSettings = .init(),
        voiceover: Voiceover? = nil,
        openHouse: OpenHouseSchedule? = nil,
        socialCaption: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.propertyInfo = propertyInfo
        self.clips = clips
        self.templateID = templateID
        self.musicTrackID = musicTrackID
        self.brandProfileID = brandProfileID
        self.exportSettings = exportSettings
        self.voiceover = voiceover
        self.openHouse = openHouse
        self.socialCaption = socialCaption
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Clips in playback order.
    var orderedClips: [MediaClip] { clips.sorted { $0.order < $1.order } }

    var isReadyToExport: Bool { !clips.isEmpty }
}

/// A narration script (drafted by the on-device model, edited by the agent) and the voice
/// that reads it.
struct Voiceover: Codable, Equatable {
    var script: String
    /// A system speech voice identifier; nil = the default voice for the device language.
    var voiceID: String?

    var hasScript: Bool { !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// The property being marketed. Rendered into the intro/outro cards.
struct PropertyInfo: Codable, Equatable {
    var address: String
    var price: String?
    var beds: Int?
    var baths: Double?
    var squareFeet: Int?
    var headline: String?     // "Just Listed", "Open House Sat 2–4"

    init(
        address: String = "",
        price: String? = nil,
        beds: Int? = nil,
        baths: Double? = nil,
        squareFeet: Int? = nil,
        headline: String? = nil
    ) {
        self.address = address
        self.price = price
        self.beds = beds
        self.baths = baths
        self.squareFeet = squareFeet
        self.headline = headline
    }

    /// e.g. "3 bd · 2 ba · 1,850 ft²" in imperial locales, "3 ch · 2 sdb · 172 m²" in metric
    /// ones — the area unit follows the device's `Locale.measurementSystem` (spec: localize
    /// units/currency by locale rather than hardcoding US conventions).
    var specsLine: String { specsLine(locale: .current) }

    /// `locale` is injectable (rather than always reading `.current`) so this stays unit-testable
    /// across both the imperial and metric branches without depending on the test runner's locale.
    func specsLine(locale: Locale) -> String {
        var parts: [String] = []
        if let beds {
            parts.append(String(localized: "\(beds) bd",
                                comment: "Abbreviated bedroom count on the video title card, e.g. '3 bd'"))
        }
        if let baths {
            let formatted = baths.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(baths)) : String(baths)
            parts.append(String(localized: "\(formatted) ba",
                                comment: "Abbreviated bathroom count on the video title card, e.g. '2 ba'"))
        }
        if let squareFeet {
            parts.append(Self.formattedArea(squareFeet, locale: locale))
        }
        return parts.joined(separator: "  ·  ")
    }

    /// Renders a square-footage value in whichever unit (ft² / m²) matches `locale`'s
    /// measurement system, with locale-correct number formatting.
    private static func formattedArea(_ squareFeet: Int, locale: Locale) -> String {
        let measurement = Measurement(value: Double(squareFeet), unit: UnitArea.squareFeet)
        let display = locale.measurementSystem == .us
            ? measurement
            : measurement.converted(to: .squareMeters)
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter.string(from: display)
    }
}
