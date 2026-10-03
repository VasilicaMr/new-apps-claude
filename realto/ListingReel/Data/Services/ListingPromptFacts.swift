import Foundation

/// The listing facts given to the on-device model, one per line, shared by every prompt so
/// the voiceover and the caption describe the home the same way.
enum ListingPromptFacts {
    static func lines(for info: PropertyInfo, agentName: String?, brokerage: String?) -> [String] {
        var facts: [String] = []
        if !info.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            facts.append("Address: \(info.address)")
        }
        if let price = info.price, !price.isEmpty { facts.append("Asking price: \(price)") }
        if let beds = info.beds { facts.append("Bedrooms: \(beds)") }
        if let baths = info.baths { facts.append("Bathrooms: \(baths.formatted())") }
        if info.squareFeet != nil { facts.append("Size: \(info.specsLine)") }
        if let headline = info.headline, !headline.isEmpty { facts.append("Headline: \(headline)") }
        if let agentName {
            facts.append("Listing agent: \(agentName)" + (brokerage.map { ", \($0)" } ?? ""))
        }
        return facts
    }

    /// Fair Housing: describe the property, never the people it suits.
    static let fairHousingRule = """
        Describe the property only — never who it would suit (families, couples, retirees, \
        students and so on), and never mention the neighbors, religion, race, nationality, \
        disability, gender or age.
        """
}
