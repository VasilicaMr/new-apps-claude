import SwiftUI

/// Owns navigation for the whole app (Coordinator pattern). Views never push each
/// other directly — they ask the coordinator. It also owns the lifetime of the
/// current editing session so wizard steps share one working `Project`.
@Observable
@MainActor
final class AppCoordinator {
    var path = NavigationPath()
    var editor: EditorFlowModel?
    /// Drives the "New Open House Post" sheet; non-nil while it's shown.
    var openHouseModel: OpenHouseViewModel?

    private let container: DIContainer

    init(container: DIContainer) {
        self.container = container
    }

    // MARK: - Flow control

    func startNewProject() {
        editor = container.makeEditorFlow(project: nil)
        Task { await editor?.onAppear() }
        #if DEBUG
        seedUITestClipsIfRequested()
        #endif
        path.append(AppRoute.media)
    }

    #if DEBUG
    /// UI-test-only seam: launch with `-UITestSeedClips` to skip the Photos
    /// picker and pre-populate the new project with the 3 bundled fixture
    /// clips (`ListingReel/Resources/UITestFixtures`), exercised end-to-end
    /// by `ListingReelUITests`.
    private func seedUITestClipsIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-UITestSeedClips"),
              let editor else { return }
        let names = ["uitest_clip1", "uitest_clip2", "uitest_clip3"]
        let urls = names.compactMap { Bundle.main.url(forResource: $0, withExtension: "mp4") }
        for (index, url) in urls.enumerated() {
            editor.project.clips.append(MediaClip(
                sourceIdentifier: "file:\(url.path)", kind: .video, order: index))
        }
    }
    #endif

    #if DEBUG
    /// Exposes just enough of `container` for `DemoMode.swift`'s extension to
    /// seed/clear fake projects, without widening `container`'s access from
    /// `private` — kept here since `container` is only reachable within this
    /// file.
    func demoModeDependencies() -> (ManageProjectsUseCase, ManageBrandProfileUseCase) {
        (container.makeManageProjectsUseCase(), container.makeBrandUseCase())
    }
    #endif

    func openProject(_ project: Project) {
        editor = container.makeEditorFlow(project: project)
        Task { await editor?.onAppear() }
        path.append(AppRoute.media)
    }

    /// Starts an open house announcement that reuses `project`'s footage and branding.
    func startOpenHousePost(from project: Project) {
        openHouseModel = container.makeOpenHouseModel(source: project)
    }

    /// Opens a freshly made open house post on its preview, so the agent sees the result
    /// first; Back leads to the media step like any other project.
    func openCreatedPost(_ project: Project) {
        openHouseModel = nil
        path = NavigationPath()
        editor = container.makeEditorFlow(project: project)
        Task { await editor?.onAppear() }
        path.append(AppRoute.media)
        path.append(AppRoute.preview)
    }

    /// Advance to the next wizard step (or finish).
    func advance(from route: AppRoute) {
        if let next = route.next {
            path.append(next)
        }
    }

    func push(_ route: AppRoute) { path.append(route) }

    func makeExportModel(project: Project) -> ExportViewModel {
        container.makeExportModel(project: project)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func finishAndReturnHome() {
        path = NavigationPath()
        editor = nil
    }

    // MARK: - View factory (keeps `View` types out of call sites)

    @ViewBuilder
    func view(for route: AppRoute) -> some View {
        if let editor {
            switch route {
            case .media:        MediaStepView(model: editor, coordinator: self)
            case .template:     TemplateStepView(model: editor, coordinator: self)
            case .propertyInfo: PropertyInfoStepView(model: editor, coordinator: self)
            case .branding:     BrandingStepView(model: editor, coordinator: self)
            case .music:        MusicStepView(model: editor, coordinator: self)
            case .preview:      PreviewStepView(model: editor, coordinator: self)
            case .export:       ExportStepView(model: editor, coordinator: self)
            }
        } else {
            // Session ended out from under us — bail to home.
            Color.clear.onAppear { self.finishAndReturnHome() }
        }
    }
}
