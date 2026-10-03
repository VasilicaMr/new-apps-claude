import Foundation

/// The ordered steps of the create-a-video flow (spec §6 happy path), plus
/// standalone destinations. Value-typed so it drives a SwiftUI `NavigationStack`.
enum AppRoute: Hashable {
    case media          // 1. add media
    case template       // 2. pick template
    case propertyInfo   // 3. enter property info
    case branding       // 4. confirm branding
    case music          // 5. pick music
    case preview        // 6. preview
    case export         // 7. export

    /// The next step in the wizard, or nil at the end.
    var next: AppRoute? {
        switch self {
        case .media:        return .template
        case .template:     return .propertyInfo
        case .propertyInfo: return .branding
        case .branding:     return .music
        case .music:        return .preview
        case .preview:      return .export
        case .export:       return nil
        }
    }

    var title: String {
        switch self {
        case .media:        return String(localized: "Add Media", comment: "Step navigation title")
        case .template:     return String(localized: "Choose a Style", comment: "Step navigation title")
        case .propertyInfo: return String(localized: "Property Details", comment: "Step navigation title")
        case .branding:     return String(localized: "Your Branding", comment: "Step navigation title")
        case .music:        return String(localized: "Add Music", comment: "Step navigation title")
        case .preview:      return String(localized: "Preview", comment: "Step navigation title")
        case .export:       return String(localized: "Export", comment: "Step navigation title")
        }
    }

    var stepIndex: Int {
        switch self {
        case .media: return 1
        case .template: return 2
        case .propertyInfo: return 3
        case .branding: return 4
        case .music: return 5
        case .preview: return 6
        case .export: return 7
        }
    }

    static let totalSteps = 7
}
