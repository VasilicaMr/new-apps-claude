import Foundation

/// Ships templates as DATA (spec §1.4.5). Built-in defaults are defined here and
/// can be overridden/extended by a bundled `templates.json` without code changes.
struct DefaultTemplateRepository: TemplateRepository {

    private let templates: [Template]

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "templates", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Template].self, from: data),
           !decoded.isEmpty {
            self.templates = decoded
        } else {
            self.templates = Self.builtIn
        }
    }

    func allTemplates() -> [Template] { templates }

    func template(id: Template.ID) -> Template? { templates.first { $0.id == id } }

    // MARK: - Built-in defaults

    static let builtIn: [Template] = [
        Template(
            id: "classic",
            displayName: String(localized: "Classic Listing", comment: "Template name"),
            summary: String(localized: "Elegant serif title card, calm cross-dissolves, gold accents.", comment: "Template description"),
            intro: TemplateSegment(duration: 3.0, layout: .centered, animation: .fade),
            body: BodyStyle(transition: .crossDissolve, clipPacing: 4.0,
                            showLowerThird: true, contentMode: .fit),
            outro: TemplateSegment(duration: 3.5, layout: .splitContact, animation: .slideUp),
            defaultAspectRatios: [.vertical9x16, .square1x1, .wide16x9],
            fontTokens: FontTokens(displayFontName: "Georgia-Bold", bodyFontName: "Georgia",
                                   displaySize: 76, bodySize: 40),
            colorTokens: ColorTokens(backgroundHex: "#0A2540",
                                     primaryTextHex: "#FFFFFF", accentHex: "#C9A227")),
        Template(
            id: "bold",
            displayName: String(localized: "Bold & Modern", comment: "Template name"),
            summary: String(localized: "Punchy sans headline, fast hard cuts, high-contrast banner.", comment: "Template description"),
            intro: TemplateSegment(duration: 2.5, layout: .lowerBanner, animation: .slideUp),
            body: BodyStyle(transition: .hardCut, clipPacing: 3.0,
                            showLowerThird: false, contentMode: .fit),
            outro: TemplateSegment(duration: 3.0, layout: .centered, animation: .scaleIn),
            defaultAspectRatios: [.vertical9x16, .square1x1],
            fontTokens: FontTokens(displayFontName: "HelveticaNeue-Bold",
                                   bodyFontName: "HelveticaNeue-Medium",
                                   displaySize: 84, bodySize: 42),
            colorTokens: ColorTokens(backgroundHex: "#111111",
                                     primaryTextHex: "#FFFFFF", accentHex: "#FF375F")),
        Template(
            id: "minimal",
            displayName: String(localized: "Minimal White", comment: "Template name"),
            summary: String(localized: "Clean, airy, editorial. Lets the property speak.", comment: "Template description"),
            intro: TemplateSegment(duration: 2.8, layout: .centered, animation: .fade),
            body: BodyStyle(transition: .crossDissolve, clipPacing: 4.5,
                            showLowerThird: true, contentMode: .fit),
            outro: TemplateSegment(duration: 3.2, layout: .splitContact, animation: .fade),
            defaultAspectRatios: [.vertical9x16, .square1x1, .wide16x9],
            fontTokens: FontTokens(displayFontName: "AvenirNext-DemiBold",
                                   bodyFontName: "AvenirNext-Regular",
                                   displaySize: 72, bodySize: 38),
            colorTokens: ColorTokens(backgroundHex: "#F5F3EF",
                                     primaryTextHex: "#1A1A1A", accentHex: "#8A7B5C"))
    ]
}
