import SwiftUI

@Observable
@MainActor
final class HomeViewModel {
    var projects: [Project] = []
    var isLoading = false
    var errorMessage: String?

    private let manageProjects: ManageProjectsUseCase

    init(manageProjects: ManageProjectsUseCase) {
        self.manageProjects = manageProjects
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            projects = try await manageProjects.all()
        } catch {
            errorMessage = String(localized: "Couldn't load your projects. \(error.localizedDescription)")
        }
    }

    func delete(_ project: Project) async {
        do {
            try await manageProjects.delete(project.id)
            projects.removeAll { $0.id == project.id }
        } catch {
            errorMessage = String(localized: "Couldn't delete that project.")
        }
    }
}
