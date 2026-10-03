import Foundation

#if DEBUG
extension Notification.Name {
    /// Fired after Demo Mode seeds or clears its fake projects, so `HomeView`
    /// (already showing the list) knows to reload — same reload-on-change
    /// shape as `.macInboxDidCreateProject`.
    static let demoDataDidChange = Notification.Name("demoDataDidChange")
}

/// DEBUG-only feature flag: seeds the project list with a handful of
/// realistic-looking fake listings — reusing the same bundled fixture clips
/// as `-UITestSeedClips` — so the app can be demoed, screenshotted, or
/// eyeballed without needing real Photos footage or a manually-built
/// project. Compiled out of Release entirely: the toggle, the seeding
/// logic, and its storage all live behind this file's `#if DEBUG`.
extension AppCoordinator {
    private static let enabledKey = "demoModeEnabled"
    private static let seededIDsKey = "demoModeSeededProjectIDs"

    var isDemoModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            Task { newValue ? await seedDemoData() : await clearDemoData() }
        }
    }

    private var seededProjectIDs: [UUID] {
        get {
            let raw = UserDefaults.standard.stringArray(forKey: Self.seededIDsKey) ?? []
            return raw.compactMap(UUID.init)
        }
        set { UserDefaults.standard.set(newValue.map(\.uuidString), forKey: Self.seededIDsKey) }
    }

    /// Three fake listings across the three built-in templates, each with a
    /// different first clip (rotated fixture order) so their thumbnails in
    /// the project list don't all look identical.
    private static let fixtureNames = ["uitest_clip1", "uitest_clip2", "uitest_clip3"]

    private struct FakeListing {
        let address: String
        let price: String
        let beds: Int
        let baths: Double
        let squareFeet: Int
        let headline: String?
        let templateID: String
    }

    private static let fakeListings: [FakeListing] = [
        FakeListing(address: "482 Willow Creek Dr, Austin, TX", price: "$625,000",
                    beds: 4, baths: 2.5, squareFeet: 2400, headline: "Just Listed",
                    templateID: "classic"),
        FakeListing(address: "1210 Harbor View Ln, Seattle, WA", price: "$899,900",
                    beds: 3, baths: 2, squareFeet: 1850, headline: "Open House Sat 1–4",
                    templateID: "bold"),
        FakeListing(address: "77 Magnolia Ct, Charlotte, NC", price: "$412,500",
                    beds: 3, baths: 2, squareFeet: 1620, headline: nil,
                    templateID: "minimal"),
    ]

    func seedDemoData() async {
        let (manageProjects, manageBrand) = demoModeDependencies()

        // Only fill in branding if none is set yet — demo mode shouldn't
        // clobber a real profile someone's actually testing with.
        var brand = (try? await manageBrand.load()) ?? BrandProfile()
        if !brand.isComplete {
            brand = BrandProfile(id: brand.id, agentName: "Jordan Blake",
                                  phone: "(555) 019-2842", brokerage: "Blake & Co. Realty")
            try? await manageBrand.save(brand)
        }

        let fixtureURLs = Self.fixtureNames.compactMap {
            Bundle.main.url(forResource: $0, withExtension: "mp4")
        }
        guard !fixtureURLs.isEmpty else { return }

        var newIDs: [UUID] = []
        for (index, listing) in Self.fakeListings.enumerated() {
            let rotation = index % fixtureURLs.count
            let rotated = Array(fixtureURLs[rotation...] + fixtureURLs[..<rotation])
            let clips = rotated.enumerated().map { order, url in
                MediaClip(sourceIdentifier: "file:\(url.path)", kind: .video, order: order)
            }
            let project = Project(
                propertyInfo: PropertyInfo(address: listing.address, price: listing.price,
                                            beds: listing.beds, baths: listing.baths,
                                            squareFeet: listing.squareFeet, headline: listing.headline),
                clips: clips,
                templateID: listing.templateID,
                brandProfileID: brand.id)
            newIDs.append(project.id)
            try? await manageProjects.save(project)
        }

        seededProjectIDs = newIDs
        NotificationCenter.default.post(name: .demoDataDidChange, object: nil)
    }

    func clearDemoData() async {
        let (manageProjects, _) = demoModeDependencies()
        for id in seededProjectIDs {
            try? await manageProjects.delete(id)
        }
        seededProjectIDs = []
        NotificationCenter.default.post(name: .demoDataDidChange, object: nil)
    }
}
#endif
