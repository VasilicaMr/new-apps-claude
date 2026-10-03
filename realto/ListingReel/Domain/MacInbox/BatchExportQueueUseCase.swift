import Foundation

/// Runs export for several draft projects unattended (Mac Inbox batch
/// export). Reuses the existing, unmodified `ExportVideoUseCase` per project
/// — this queue only adds sequencing, persistence, archiving, and a
/// completion notification around it.
struct BatchExportQueueUseCase {
    struct Outcome {
        let projectID: Project.ID
        let result: Result<[ExportedFile], RenderError>
    }

    let exportUseCase: ExportVideoUseCase
    let manageProjects: ManageProjectsUseCase
    let archiver: ExportedFileArchiving
    let notifier: ExportNotifying

    /// Renders every project in turn — sequential, same memory discipline
    /// rationale as spec §4.3's per-format sequencing, just one level up.
    /// One project failing never aborts the rest (spec §4.5 "never fail
    /// silently" applies to the whole queue, not just a single render).
    func run(projects: [Project]) async -> [Outcome] {
        var outcomes: [Outcome] = []
        for project in projects {
            do {
                let files = try await exportUseCase(project: project) { _ in }
                try? await manageProjects.save(project)
                try? await archiver.archive(files, for: project)
                outcomes.append(Outcome(projectID: project.id, result: .success(files)))
            } catch let error as RenderError {
                outcomes.append(Outcome(projectID: project.id, result: .failure(error)))
            } catch {
                outcomes.append(Outcome(projectID: project.id,
                                        result: .failure(.unknown(error.localizedDescription))))
            }
        }
        let succeeded = outcomes.filter {
            if case .success = $0.result { return true }
            return false
        }.count
        await notifier.notifyBatchFinished(succeeded: succeeded, failed: outcomes.count - succeeded)
        return outcomes
    }
}
