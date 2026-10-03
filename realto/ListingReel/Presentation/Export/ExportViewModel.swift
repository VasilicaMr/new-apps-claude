import SwiftUI

@Observable
@MainActor
final class ExportViewModel {

    enum Phase: Equatable {
        case idle
        case rendering(RenderProgress)
        case finished([ExportedFile])
        case failed(RenderError)
    }

    var phase: Phase = .idle
    var savedToPhotos = false
    var saveError: String?
    #if os(macOS)
    var savedToFolder = false
    var folderSaveError: String?
    #endif

    let project: Project
    private let exportUseCase: ExportVideoUseCase
    private let manageProjects: ManageProjectsUseCase
    private var task: Task<Void, Never>?

    init(project: Project, exportUseCase: ExportVideoUseCase, manageProjects: ManageProjectsUseCase) {
        self.project = project
        self.exportUseCase = exportUseCase
        self.manageProjects = manageProjects
    }

    var isRendering: Bool { if case .rendering = phase { return true }; return false }

    var exportedFiles: [ExportedFile] {
        if case .finished(let files) = phase { return files }
        return []
    }

    func start() {
        guard !isRendering else { return }
        savedToPhotos = false
        phase = .rendering(RenderProgress(currentAspectRatio: .vertical9x16,
                                          currentFormatIndex: 0, totalFormats: 1, fractionComplete: 0))

        task = Task {
            do {
                let files = try await exportUseCase(project: project) { [weak self] progress in
                    Task { @MainActor in
                        guard let self, self.isRendering else { return }
                        self.phase = .rendering(progress)
                    }
                }
                try? await manageProjects.save(project)
                phase = .finished(files)
            } catch is CancellationError {
                phase = .idle
            } catch let error as RenderError {
                phase = error == .cancelled ? .idle : .failed(error)
            } catch {
                phase = .failed(.unknown(error.localizedDescription))
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    func retry() { start() }

    func saveAllToPhotos() async {
        guard case .finished(let files) = phase else { return }
        do {
            try await exportUseCase.saveToLibrary(files)
            savedToPhotos = true
        } catch {
            saveError = (error as? RenderError)?.errorDescription ?? error.localizedDescription
        }
    }

    #if os(macOS)
    /// Copies every rendered file into a user-chosen Finder folder — the native
    /// Mac equivalent of "Save to Photos" (spec F8): a realtor exporting several
    /// formats wants them in a listing folder they can drag into email, an MLS
    /// upload, or a social scheduler, not buried in the Photos library.
    func saveAllToFolder(_ destination: URL) {
        guard case .finished(let files) = phase else { return }
        let baseName = folderFileBaseName()
        do {
            for file in files {
                let suffix = file.aspectRatio.rawValue.replacingOccurrences(of: ":", with: "x")
                var dest = destination
                    .appendingPathComponent("\(baseName)-\(suffix)")
                    .appendingPathExtension(file.url.pathExtension)
                var attempt = 2
                while FileManager.default.fileExists(atPath: dest.path) {
                    dest = destination
                        .appendingPathComponent("\(baseName)-\(suffix)-\(attempt)")
                        .appendingPathExtension(file.url.pathExtension)
                    attempt += 1
                }
                try FileManager.default.copyItem(at: file.url, to: dest)
            }
            savedToFolder = true
            folderSaveError = nil
        } catch {
            folderSaveError = error.localizedDescription
        }
    }

    /// A friendly, filesystem-safe file stem — the listing address when there is
    /// one, so Finder shows "123 Main St-9x16.mp4" rather than a UUID.
    private func folderFileBaseName() -> String {
        let address = project.propertyInfo.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = address.isEmpty ? "ListingReel Export" : address
        return raw.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
    }
    #endif
}
