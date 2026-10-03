import Foundation

/// Target social aspect ratios (spec §1.4.6 — one-tap multi-format export).
enum AspectRatio: String, Codable, CaseIterable, Identifiable, Equatable {
    case vertical9x16 = "9:16"   // Reels / Stories / TikTok
    case square1x1    = "1:1"    // Feed
    case wide16x9     = "16:9"   // YouTube

    var id: String { rawValue }

    var ratio: CGFloat {
        switch self {
        case .vertical9x16: return 9.0 / 16.0
        case .square1x1:    return 1.0
        case .wide16x9:     return 16.0 / 9.0
        }
    }

    var displayName: String {
        switch self {
        case .vertical9x16: return String(localized: "Vertical · Reels/Stories", comment: "Aspect ratio option")
        case .square1x1:    return String(localized: "Square · Feed", comment: "Aspect ratio option")
        case .wide16x9:     return String(localized: "Wide · YouTube", comment: "Aspect ratio option")
        }
    }

    /// Render pixel size for a given resolution tier. Even dimensions required by codecs.
    func renderSize(for resolution: Resolution) -> CGSize {
        let longEdge = resolution.longEdge
        let size: CGSize
        switch self {
        case .vertical9x16: size = CGSize(width: longEdge * 9 / 16, height: longEdge)
        case .square1x1:    size = CGSize(width: longEdge, height: longEdge)
        case .wide16x9:     size = CGSize(width: longEdge, height: longEdge * 9 / 16)
        }
        return CGSize(width: AspectRatio.even(size.width),
                      height: AspectRatio.even(size.height))
    }

    /// Round down to the nearest even integer (codecs reject odd dimensions).
    static func even(_ value: CGFloat) -> CGFloat {
        (value / 2).rounded(.down) * 2
    }
}

enum Resolution: String, Codable, CaseIterable, Identifiable, Equatable {
    case hd1080
    case uhd4K

    var id: String { rawValue }

    /// The long edge in pixels.
    var longEdge: CGFloat {
        switch self {
        case .hd1080: return 1920
        case .uhd4K:  return 3840
        }
    }

    var displayName: String {
        switch self {
        case .hd1080: return String(localized: "1080p HD", comment: "Export resolution option")
        case .uhd4K:  return String(localized: "4K Ultra HD", comment: "Export resolution option")
        }
    }
}

enum VideoCodec: String, Codable, Equatable {
    case hevc    // preferred (spec §4.4)
    case h264    // fallback for compatibility / older devices
}

/// User's chosen export configuration.
struct ExportSettings: Codable, Equatable {
    var aspectRatios: Set<AspectRatio>
    var resolution: Resolution
    var codec: VideoCodec
    var includeWatermark: Bool          // tier-dependent (free = true)

    init(
        aspectRatios: Set<AspectRatio> = [.vertical9x16],
        resolution: Resolution = .hd1080,
        codec: VideoCodec = .hevc,
        includeWatermark: Bool = true
    ) {
        self.aspectRatios = aspectRatios
        self.resolution = resolution
        self.codec = codec
        self.includeWatermark = includeWatermark
    }

    /// The single ratio the Preview step renders and sizes itself against.
    /// `aspectRatios` is a `Set` (no order) and export renders one file per
    /// entry, but the live preview only ever plays one — this picks it the
    /// same way every time so the composer and the preview UI never disagree
    /// about which shape is on screen.
    var previewAspectRatio: AspectRatio {
        aspectRatios.sorted { $0.rawValue < $1.rawValue }.first ?? .vertical9x16
    }
}

/// A rendered output file, one per requested aspect ratio.
struct ExportedFile: Identifiable, Equatable {
    let id: UUID
    let aspectRatio: AspectRatio
    let url: URL
    let fileSizeBytes: Int64

    init(id: UUID = UUID(), aspectRatio: AspectRatio, url: URL, fileSizeBytes: Int64) {
        self.id = id
        self.aspectRatio = aspectRatio
        self.url = url
        self.fileSizeBytes = fileSizeBytes
    }
}
