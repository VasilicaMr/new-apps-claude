import Foundation

/// A listing template: intro card → body (clip pacing + overlays) → outro card.
/// Templates are DATA, not code (spec §1.4.5) so they can ship as JSON and be
/// added without an app update later.
struct Template: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var summary: String
    var intro: TemplateSegment
    var body: BodyStyle
    var outro: TemplateSegment
    var defaultAspectRatios: [AspectRatio]
    var fontTokens: FontTokens
    var colorTokens: ColorTokens
}

/// A title/contact card (intro or outro).
struct TemplateSegment: Codable, Equatable {
    var duration: TimeInterval          // seconds the card is on screen
    var layout: CardLayout
    var animation: CardAnimation
}

enum CardLayout: String, Codable, Equatable {
    case centered           // headline + address stacked, centered
    case lowerBanner        // banner across the bottom third
    case splitContact       // logo left, contact right (outro)
}

enum CardAnimation: String, Codable, Equatable {
    case fade
    case slideUp
    case scaleIn
}

/// How the clips in the middle are paced and decorated.
struct BodyStyle: Codable, Equatable {
    var transition: TransitionStyle
    var clipPacing: TimeInterval?       // if set, each clip is capped to this length
    var showLowerThird: Bool            // persistent branding strip during clips
    var contentMode: ClipContentMode    // fill (interiors) vs fit
}

enum TransitionStyle: String, Codable, Equatable {
    case hardCut
    case crossDissolve
}

enum ClipContentMode: String, Codable, Equatable {
    case fill   // realtors want fill for interiors (spec §4.3)
    case fit
}

// MARK: - Design tokens

struct FontTokens: Codable, Equatable {
    var displayFontName: String     // e.g. "HelveticaNeue-Bold"
    var bodyFontName: String
    var displaySize: CGFloat        // point size at 1080p reference height
    var bodySize: CGFloat
}

struct ColorTokens: Codable, Equatable {
    var backgroundHex: String
    var primaryTextHex: String
    var accentHex: String
}
