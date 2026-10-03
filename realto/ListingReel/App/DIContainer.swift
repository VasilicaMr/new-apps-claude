import Foundation
import SwiftData

/// Composition root (spec §3.3). Wires concrete Data-layer implementations to the
/// Domain protocols, and hands ViewModels their dependencies. This is the only
/// place that knows about concrete types.
@MainActor
final class DIContainer {

    // Infrastructure
    let modelContainer: ModelContainer

    // Repositories (Domain protocols, concrete here)
    let projectRepository: ProjectRepository
    let templateRepository: TemplateRepository
    let musicRepository: MusicRepository
    let brandRepository: BrandProfileRepository
    let mediaRepository: MediaRepository
    let renderer: VideoRenderer
    let previewComposer: PreviewComposer
    let subscriptionManager: SubscriptionManager
    let listingSheetReader: ListingSheetReader
    let voiceoverScriptWriter: VoiceoverScriptWriter
    let postCaptionWriter: PostCaptionWriter

    // Mac Inbox (macOS only — watched-folder auto-import + background batch
    // export, behind its own Settings-toggle feature flag, off by default).
    // Wired here like any other long-lived service; everything it depends on
    // lives under Domain/Data/Presentation's `MacInbox` groupings, excluded
    // from the iOS target in project.yml (spec §3.7).
    #if os(macOS)
    let inboxModel: InboxViewModel
    #endif

    init() {
        // SwiftData store — fall back to in-memory if the on-disk store can't open,
        // so the app still launches (reliability over a hard crash).
        let container: ModelContainer
        do {
            container = try ModelContainer(for: ProjectRecord.self)
        } catch {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: ProjectRecord.self, configurations: config)
        }
        self.modelContainer = container

        let brand = FileBrandProfileRepository()
        self.brandRepository = brand
        let projects = SwiftDataProjectRepository(modelContainer: container)
        self.projectRepository = projects
        let templates = DefaultTemplateRepository()
        self.templateRepository = templates
        let music = DefaultMusicRepository()
        self.musicRepository = music
        let media = PhotoKitMediaService()
        self.mediaRepository = media
        let videoRenderer = AVVideoCompositionService(brandRepository: brand)
        self.renderer = videoRenderer
        self.previewComposer = PreviewComposer(resolver: AVAssetResolver(), brandRepository: brand)
        let subscriptions = SubscriptionManager()
        self.subscriptionManager = subscriptions
        if #available(iOS 26.0, macOS 26.0, *) {
            self.listingSheetReader = FoundationModelsListingSheetReader()
            self.postCaptionWriter = FoundationModelsPostCaptionWriter()
        } else {
            self.listingSheetReader = UnavailableListingSheetReader()
            self.postCaptionWriter = UnavailablePostCaptionWriter()
        }
        // AI voiceover is a product decision for iOS 27 / macOS 27 and later only — the
        // writer itself would compile against 26, but the feature isn't offered there.
        let scriptWriter: VoiceoverScriptWriter
        if #available(iOS 27.0, macOS 27.0, *) {
            scriptWriter = FoundationModelsVoiceoverScriptWriter()
        } else {
            scriptWriter = UnavailableVoiceoverScriptWriter()
        }
        self.voiceoverScriptWriter = scriptWriter

        #if os(macOS)
        let macInboxSettings = MacInboxSettingsStore()
        self.inboxModel = InboxViewModel(
            settingsRepository: macInboxSettings,
            manageProjects: ManageProjectsUseCase(repository: projects, templates: templates),
            importFolderMedia: ImportFolderMediaUseCase(
                importer: FileMediaImportService(importsDirectory: MacInboxPaths.importsDirectory)),
            batchExportQueue: BatchExportQueueUseCase(
                exportUseCase: ExportVideoUseCase(renderer: videoRenderer, templates: templates,
                                                  music: music, brandProfiles: brand, media: media,
                                                  narration: NarrateVoiceoverUseCase(
                                                      writer: scriptWriter,
                                                      renderer: SpeechNarrationAudioRenderer())),
                manageProjects: ManageProjectsUseCase(repository: projects, templates: templates),
                archiver: WatchedFolderExportArchiver(settingsRepository: macInboxSettings),
                notifier: UserNotificationExportNotifier()),
            subscriptionManager: subscriptions)
        #endif
    }

    // MARK: - Use cases

    func makeManageProjectsUseCase() -> ManageProjectsUseCase {
        ManageProjectsUseCase(repository: projectRepository, templates: templateRepository)
    }

    func makeExportUseCase() -> ExportVideoUseCase {
        ExportVideoUseCase(renderer: renderer, templates: templateRepository,
                           music: musicRepository, brandProfiles: brandRepository,
                           media: mediaRepository, narration: makeNarrateVoiceoverUseCase())
    }

    /// Voiceover audio for preview/export — a no-op wherever the AI voiceover isn't offered.
    func makeNarrateVoiceoverUseCase() -> NarrateVoiceoverUseCase {
        NarrateVoiceoverUseCase(writer: voiceoverScriptWriter, renderer: SpeechNarrationAudioRenderer())
    }

    func makeWritePostCaptionUseCase() -> WritePostCaptionUseCase {
        WritePostCaptionUseCase(writer: postCaptionWriter)
    }

    func makeBrandUseCase() -> ManageBrandProfileUseCase {
        ManageBrandProfileUseCase(repository: brandRepository)
    }

    func makeImportMediaUseCase() -> ImportMediaUseCase {
        ImportMediaUseCase(media: mediaRepository)
    }

    // MARK: - ViewModels

    func makeHomeModel() -> HomeViewModel {
        HomeViewModel(manageProjects: makeManageProjectsUseCase())
    }

    func makeEditorFlow(project: Project?) -> EditorFlowModel {
        EditorFlowModel(
            project: project ?? makeManageProjectsUseCase().newProject(),
            templates: templateRepository,
            music: musicRepository,
            importMedia: makeImportMediaUseCase(),
            manageProjects: makeManageProjectsUseCase(),
            manageBrand: makeBrandUseCase(),
            scanListingSheet: ScanListingSheetUseCase(reader: listingSheetReader),
            writeVoiceoverScript: WriteVoiceoverScriptUseCase(writer: voiceoverScriptWriter),
            writePostCaption: makeWritePostCaptionUseCase(),
            narrateVoiceover: makeNarrateVoiceoverUseCase(),
            voiceCatalog: SpeechVoiceCatalog(),
            previewComposer: previewComposer)
    }

    func makeOpenHouseModel(source: Project) -> OpenHouseViewModel {
        OpenHouseViewModel(
            source: source,
            createPost: CreateOpenHousePostUseCase(
                writeVoiceover: WriteVoiceoverScriptUseCase(writer: voiceoverScriptWriter),
                writeCaption: makeWritePostCaptionUseCase()),
            manageProjects: makeManageProjectsUseCase(),
            manageBrand: makeBrandUseCase())
    }

    func makeExportModel(project: Project) -> ExportViewModel {
        ExportViewModel(project: project,
                        exportUseCase: makeExportUseCase(),
                        manageProjects: makeManageProjectsUseCase())
    }
}
