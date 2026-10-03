import Foundation
import Observation

/// Drives the "New Open House Post" sheet: the agent picks when the open house runs, and
/// a new project is made from the listing's footage with the time on the title card and,
/// where Apple Intelligence is available, a fresh narration and caption.
@Observable
@MainActor
final class OpenHouseViewModel: Identifiable {
    let source: Project
    private let createPost: CreateOpenHousePostUseCase
    private let manageProjects: ManageProjectsUseCase
    private let manageBrand: ManageBrandProfileUseCase

    /// Moving the start moves the end with it, keeping the length — so changing the day
    /// never leaves the end time on the old day.
    var start: Date {
        didSet { end = end.addingTimeInterval(start.timeIntervalSince(oldValue)) }
    }
    var end: Date

    private(set) var isCreating = false
    var errorMessage: String?
    /// Set when the post was made but part of the AI copy couldn't be written.
    private(set) var notice: String?
    private(set) var createdProject: Project?

    init(source: Project,
         createPost: CreateOpenHousePostUseCase,
         manageProjects: ManageProjectsUseCase,
         manageBrand: ManageBrandProfileUseCase) {
        self.source = source
        self.createPost = createPost
        self.manageProjects = manageProjects
        self.manageBrand = manageBrand
        let suggested = OpenHouseSchedule.suggested()
        self.start = suggested.start
        self.end = suggested.end
    }

    var schedule: OpenHouseSchedule { OpenHouseSchedule(start: start, end: end) }
    var listingTitle: String { source.propertyInfo.address.nilIfBlank ?? source.name }
    var writesWithAppleIntelligence: Bool { createPost.writesWithAppleIntelligence }
    var writesVoiceover: Bool { createPost.writeVoiceover.isAvailable }
    var canCreate: Bool { schedule.isValid && !isCreating && createdProject == nil }

    /// Returns the saved project when it's ready to open straight away; nil when there's
    /// an error or a notice the agent should read first.
    func create() async -> Project? {
        guard canCreate else { return nil }
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        let brand = try? await manageBrand.load()
        let result = await createPost.create(from: source, schedule: schedule, brand: brand)
        do {
            try await manageProjects.save(result.project)
        } catch {
            errorMessage = String(localized: "Couldn't save the open house post. \(error.localizedDescription)")
            return nil
        }
        guard let notice = result.notice else { return result.project }
        self.notice = notice
        createdProject = result.project
        return nil
    }
}
