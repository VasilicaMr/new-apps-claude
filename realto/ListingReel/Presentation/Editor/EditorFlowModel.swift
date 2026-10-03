import SwiftUI
import AVFoundation

/// Shared state for the create-a-video wizard. One instance lives for the whole
/// flow so every step edits the same working `Project`. Views are dumb and bind
/// to this; all mutation goes through use cases (Clean Architecture).
@Observable
@MainActor
final class EditorFlowModel {
    // Working state
    var project: Project
    var brand: BrandProfile = BrandProfile()

    // UI feedback
    var isImporting = false
    var isScanningListingSheet = false
    var listingSheetScanMessage: String?
    var errorMessage: String?
    var isWritingCaption = false
    var captionMessage: String?

    // Dependencies (Domain use cases / protocols only)
    private let templatesRepo: TemplateRepository
    private let musicRepo: MusicRepository
    private let importMedia: ImportMediaUseCase
    private let manageProjects: ManageProjectsUseCase
    private let manageBrand: ManageBrandProfileUseCase
    private let scanListingSheetUseCase: ScanListingSheetUseCase
    private let writeVoiceoverScript: WriteVoiceoverScriptUseCase
    private let writePostCaptionUseCase: WritePostCaptionUseCase
    private let narrateVoiceover: NarrateVoiceoverUseCase
    private let voiceCatalog: NarrationVoiceCatalog
    let previewComposer: PreviewComposer

    init(project: Project,
         templates: TemplateRepository,
         music: MusicRepository,
         importMedia: ImportMediaUseCase,
         manageProjects: ManageProjectsUseCase,
         manageBrand: ManageBrandProfileUseCase,
         scanListingSheet: ScanListingSheetUseCase,
         writeVoiceoverScript: WriteVoiceoverScriptUseCase,
         writePostCaption: WritePostCaptionUseCase,
         narrateVoiceover: NarrateVoiceoverUseCase,
         voiceCatalog: NarrationVoiceCatalog,
         previewComposer: PreviewComposer) {
        self.project = project
        self.templatesRepo = templates
        self.musicRepo = music
        self.importMedia = importMedia
        self.manageProjects = manageProjects
        self.manageBrand = manageBrand
        self.scanListingSheetUseCase = scanListingSheet
        self.writeVoiceoverScript = writeVoiceoverScript
        self.writePostCaptionUseCase = writePostCaption
        self.narrateVoiceover = narrateVoiceover
        self.voiceCatalog = voiceCatalog
        self.previewComposer = previewComposer
    }

    // MARK: - Derived

    var templates: [Template] { templatesRepo.allTemplates() }
    var musicTracks: [MusicTrack] { musicRepo.allTracks() }
    var selectedTemplate: Template? { templatesRepo.template(id: project.templateID) }
    var selectedMusic: MusicTrack? { project.musicTrackID.flatMap { musicRepo.track(id: $0) } }

    // MARK: - Lifecycle

    func onAppear() async {
        if let saved = try? await manageBrand.load() {
            brand = saved
            project.brandProfileID = saved.id
        }
    }

    // MARK: - Media (step 1)

    func requestPhotoAccess() async -> Bool {
        await importMedia.requestAccess()
    }

    func addPickedMedia(localIdentifiers: [String]) {
        guard !localIdentifiers.isEmpty else { return }
        isImporting = true
        importMedia.appendClips(localIdentifiers: localIdentifiers, to: &project)
        isImporting = false
        autosave()
    }

    func removeClip(_ clip: MediaClip) {
        project.clips.removeAll { $0.id == clip.id }
        reindexClips()
        autosave()
    }

    func moveClips(from offsets: IndexSet, to destination: Int) {
        var ordered = project.orderedClips
        ordered.move(fromOffsets: offsets, toOffset: destination)
        project.clips = ordered
        reindexClips()
        autosave()
    }

    private func reindexClips() {
        var ordered = project.orderedClips
        for i in ordered.indices { ordered[i].order = i }
        project.clips = ordered
    }

    // MARK: - Template (step 2)

    func selectTemplate(_ template: Template) {
        project.templateID = template.id
        autosave()
    }

    // MARK: - Property info (step 3)  — bound directly to project.propertyInfo

    var canScanListingSheet: Bool { scanListingSheetUseCase.isAvailable }

    /// Fills blank property fields from a photo of a listing sheet (on-device OCR + model).
    func scanListingSheet(imageData: Data) async {
        isScanningListingSheet = true
        listingSheetScanMessage = nil
        defer { isScanningListingSheet = false }
        do {
            let scanned = try await scanListingSheetUseCase.scan(imageData: imageData)
            // Merge against the fields as they are now — the agent may have typed while it ran.
            let current = project.propertyInfo
            project.propertyInfo = current.fillingBlanks(from: scanned)
            let filled = project.propertyInfo.filledFieldCount - current.filledFieldCount
            listingSheetScanMessage = filled == 0
                ? String(localized: "Nothing new found — your fields were already filled in.")
                : String(localized: "Filled in from the sheet — please double-check the details.")
            autosave()
        } catch {
            listingSheetScanMessage = (error as? ListingSheetScanError)?.errorDescription
                ?? ListingSheetScanError.failed.errorDescription
        }
    }

    // MARK: - Branding (step 4)

    func saveBrand() async {
        do {
            try await manageBrand.save(brand)
            project.brandProfileID = brand.id
            autosave()
        } catch {
            errorMessage = String(localized: "Couldn't save your branding. \(error.localizedDescription)")
        }
    }

    func setLogo(data: Data) async {
        do {
            let id = try await manageBrand.storeLogo(data)
            brand.logoAssetID = id
        } catch {
            errorMessage = String(localized: "Couldn't save the logo image.")
        }
    }

    // MARK: - Music (step 5)

    func selectMusic(_ track: MusicTrack?) {
        project.musicTrackID = track?.id
        autosave()
    }

    // MARK: - Preview (step 6)

    func makePreviewItem() async -> AVPlayerItem? {
        guard let template = selectedTemplate else { return nil }
        do {
            return try await previewComposer.makePreviewItem(
                project: project, template: template, brand: brand, music: selectedMusic,
                narration: await previewNarration())
        } catch {
            errorMessage = (error as? RenderError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    // MARK: - AI voiceover (preview step; iOS 27 / macOS 27+ with Apple Intelligence)

    var canUseVoiceover: Bool { writeVoiceoverScript.isAvailable }

    func makeVoiceoverModel() -> VoiceoverViewModel {
        VoiceoverViewModel(editor: self, writeScript: writeVoiceoverScript, voiceCatalog: voiceCatalog)
    }

    /// The last voiceover rendered for the preview, reused until the script or voice changes
    /// (speech takes a few seconds to render). The file must outlive the player item using it.
    private var previewNarrationCache: (voiceover: Voiceover, url: URL)?

    private func previewNarration() async -> URL? {
        guard narrateVoiceover.willNarrate(project), let voiceover = project.voiceover else { return nil }
        if let cached = previewNarrationCache, cached.voiceover == voiceover {
            return cached.url
        }
        let old = previewNarrationCache?.url
        previewNarrationCache = nil
        guard let url = await narrateVoiceover.audio(for: project) else { return nil }
        previewNarrationCache = (voiceover, url)
        old.map { try? FileManager.default.removeItem(at: $0) }
        return url
    }

    // MARK: - Post caption (export step)

    var canWriteCaptionWithAI: Bool { writePostCaptionUseCase.isAvailable }

    /// The caption to paste with the video: the agent's (or the model's) if written, else a
    /// plain one built from the listing details, so there's always something to copy.
    var postCaption: String {
        get { project.socialCaption ?? WritePostCaptionUseCase.basicCaption(project: project, brand: brand) }
        set { project.socialCaption = newValue }
    }

    func writePostCaption() async {
        isWritingCaption = true
        captionMessage = nil
        defer { isWritingCaption = false }
        do {
            project.socialCaption = try await writePostCaptionUseCase.write(project: project, brand: brand)
            autosave()
        } catch {
            captionMessage = (error as? PostCaptionError)?.errorDescription
                ?? PostCaptionError.failed.errorDescription
        }
    }

    // MARK: - Export settings

    func toggleAspectRatio(_ ratio: AspectRatio) {
        if project.exportSettings.aspectRatios.contains(ratio) {
            if project.exportSettings.aspectRatios.count > 1 {
                project.exportSettings.aspectRatios.remove(ratio)
            }
        } else {
            project.exportSettings.aspectRatios.insert(ratio)
        }
        autosave()
    }

    func setResolution(_ resolution: Resolution) {
        project.exportSettings.resolution = resolution
        autosave()
    }

    // MARK: - Persistence

    func autosave() {
        let snapshot = project
        Task { try? await manageProjects.save(snapshot) }
    }
}
