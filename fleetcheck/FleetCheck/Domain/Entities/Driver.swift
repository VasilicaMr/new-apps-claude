import Foundation

struct Driver: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let phone: String
    let hireDate: Date
    let licenseExpiry: Date
    let assignedVehicleId: String?

    var initials: String {
        name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined()
    }
}
