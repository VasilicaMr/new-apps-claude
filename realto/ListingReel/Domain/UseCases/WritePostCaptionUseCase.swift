import Foundation

/// The caption posted alongside the video. Apple Intelligence writes the hook, the short
/// description and the hashtags; the facts block (open house time, address, price, specs,
/// contact) is always assembled here from what the agent entered, so it's never wrong.
/// Where the model isn't available, `basicCaption` gives a plain caption from the facts alone.
struct WritePostCaptionUseCase {
    let writer: PostCaptionWriter

    /// Instagram allows 30; a handful of relevant tags reads better and performs as well.
    static let maxHashtags = 6

    var isAvailable: Bool { writer.isAvailable }

    func makeRequest(project: Project, brand: BrandProfile?) -> PostCaptionRequest {
        PostCaptionRequest(
            propertyInfo: project.propertyInfo,
            roomOrder: WriteVoiceoverScriptUseCase.roomOrder(of: project),
            agentName: brand?.agentName.nilIfBlank,
            brokerage: brand?.brokerage?.nilIfBlank,
            openHouseWhen: project.openHouse?.spokenWhen())
    }

    func write(project: Project, brand: BrandProfile?) async throws -> String {
        guard writer.isAvailable else { throw PostCaptionError.unavailable }
        let caption = try await writer.writeCaption(for: makeRequest(project: project, brand: brand))
        guard caption.hook.nilIfBlank != nil || caption.body.nilIfBlank != nil else {
            throw PostCaptionError.failed
        }
        return Self.assemble(caption, project: project, brand: brand)
    }

    /// A caption from the facts alone — no model needed.
    static func basicCaption(project: Project, brand: BrandProfile?) -> String {
        let hook = project.propertyInfo.headline?.nilIfBlank ?? (project.openHouse == nil
            ? String(localized: "Just listed 🏡", comment: "Opening line of a plain social caption for a new listing")
            : String(localized: "You're invited to an open house 🏡", comment: "Opening line of a plain social caption for an open house"))
        return assemble(PostCaption(hook: hook, body: "", hashtags: []), project: project, brand: brand)
    }

    static func assemble(_ caption: PostCaption, project: Project, brand: BrandProfile?) -> String {
        let paragraphs = [
            caption.hook.nilIfBlank,
            caption.body.nilIfBlank,
            factLines(project: project, brand: brand).joined(separator: "\n").nilIfBlank,
            hashtags(caption.hashtags, isOpenHouse: project.openHouse != nil).joined(separator: " ").nilIfBlank,
        ]
        return paragraphs.compactMap { $0 }.joined(separator: "\n\n")
    }

    static func factLines(project: Project, brand: BrandProfile?) -> [String] {
        let info = project.propertyInfo
        var lines: [String] = []
        if let when = project.openHouse?.spokenWhen() {
            lines.append("📅 " + String(localized: "Open House: \(when)",
                                       comment: "Caption line with the open house date and time"))
        }
        if let address = info.address.nilIfBlank { lines.append("📍 " + address) }
        let specs = [info.price?.nilIfBlank, info.specsLine.replacingOccurrences(of: "  ·  ", with: " · ").nilIfBlank]
            .compactMap { $0 }
        if !specs.isEmpty { lines.append("🏡 " + specs.joined(separator: " · ")) }
        if let brand, let agent = brand.agentName.nilIfBlank {
            let contact = [agent, brand.brokerage?.nilIfBlank, brand.phone?.nilIfBlank].compactMap { $0 }
            lines.append("📞 " + contact.joined(separator: " · "))
        }
        return lines
    }

    /// The moment's own tags first, then the model's — cleaned up, deduplicated, capped.
    static func hashtags(_ suggested: [String], isOpenHouse: Bool) -> [String] {
        let defaults = isOpenHouse
            ? [String(localized: "OpenHouse", comment: "Default hashtag (no #, no spaces) on open house captions"),
               String(localized: "RealEstate", comment: "Default hashtag (no #, no spaces) on listing captions")]
            : [String(localized: "JustListed", comment: "Default hashtag (no #, no spaces) on new listing captions"),
               String(localized: "RealEstate", comment: "Default hashtag (no #, no spaces) on listing captions")]
        var seen = Set<String>()
        var tags: [String] = []
        for raw in defaults + suggested {
            let word = String(raw.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
            guard !word.isEmpty, seen.insert(word.lowercased()).inserted else { continue }
            tags.append("#" + word)
            if tags.count == maxHashtags { break }
        }
        return tags
    }
}
