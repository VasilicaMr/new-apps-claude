import Foundation

/// Stores the single reusable brand profile as JSON, and logo images as files,
/// in the app-support directory (spec §5). Actor-isolated for thread safety.
actor FileBrandProfileRepository: BrandProfileRepository {

    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("ListingReel", isDirectory: true)
    }
    private var profileURL: URL { baseDirectory.appendingPathComponent("brand.json") }
    private var logosDirectory: URL { baseDirectory.appendingPathComponent("logos", isDirectory: true) }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: logosDirectory, withIntermediateDirectories: true)
    }

    func load() async throws -> BrandProfile? {
        guard let data = try? Data(contentsOf: profileURL) else { return nil }
        return try? JSONDecoder().decode(BrandProfile.self, from: data)
    }

    func save(_ profile: BrandProfile) async throws {
        try ensureDirectories()
        let data = try JSONEncoder().encode(profile)
        try data.write(to: profileURL, options: .atomic)
    }

    func storeLogo(_ data: Data) async throws -> String {
        try ensureDirectories()
        let id = UUID().uuidString
        try data.write(to: logosDirectory.appendingPathComponent(id), options: .atomic)
        return id
    }

    func loadLogo(id: String) async throws -> Data? {
        try? Data(contentsOf: logosDirectory.appendingPathComponent(id))
    }
}
