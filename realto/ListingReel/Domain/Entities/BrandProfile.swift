import Foundation

/// The agent's reusable branding. Entered once, reused across projects (spec §6).
struct BrandProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var agentName: String
    var phone: String?
    var brokerage: String?
    var email: String?
    var logoAssetID: String?         // reference to an image stored in app support
    var primaryColorHex: String
    var accentColorHex: String

    init(
        id: UUID = UUID(),
        agentName: String = "",
        phone: String? = nil,
        brokerage: String? = nil,
        email: String? = nil,
        logoAssetID: String? = nil,
        primaryColorHex: String = "#0A2540",
        accentColorHex: String = "#C9A227"
    ) {
        self.id = id
        self.agentName = agentName
        self.phone = phone
        self.brokerage = brokerage
        self.email = email
        self.logoAssetID = logoAssetID
        self.primaryColorHex = primaryColorHex
        self.accentColorHex = accentColorHex
    }

    var isComplete: Bool { !agentName.trimmingCharacters(in: .whitespaces).isEmpty }
}
