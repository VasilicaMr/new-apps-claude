import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

/// Step 1 — Add media. iOS imports from Photos or records in-app; macOS browses
/// files directly via Finder (spec §F1, §F2 — F2 is iOS-only in v1; Mac users
/// import existing footage rather than film with a laptop camera). PhotosPicker
/// is iOS-only — it isn't a reliable Mac idiom, and Mac users' footage usually
/// lives in a folder on disk rather than in Photos.app. Each clip shows a trim
/// button (scissors icon) to open the per-clip trim editor.
struct MediaStepView: View {
    @Bindable var model: EditorFlowModel
    let coordinator: AppCoordinator

    #if os(iOS)
    @State private var showPicker = false
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showAddDialog = false
    @State private var showAccessDenied = false
    #endif
    #if os(macOS)
    @State private var isDropTargeted = false
    @State private var showImportError = false
    #endif
    @State private var trimmingClip: MediaClip?       // non-nil → trim sheet shown

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: Theme.Spacing.s)]
    private let resolver = AVAssetResolver()

    private var mediaSubtitle: LocalizedStringKey {
        #if os(macOS)
        "Browse for video and photo files, or drag them in from Finder."
        #else
        "Import from Photos or record in-app."
        #endif
    }

    var body: some View {
        StepScaffold(route: .media) {
            SectionHeader(title: "Add your footage", subtitle: mediaSubtitle)

            if model.project.clips.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
                    ForEach(model.project.orderedClips) { clip in
                        clipCell(clip)
                    }
                    addTile
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", systemImage: "arrow.right",
                          isEnabled: !model.project.clips.isEmpty, accessibilityID: "Continue") {
                coordinator.advance(from: .media)
            }
        }
        #if os(iOS)
        // Photos picker — PHAsset local identifiers where available, never bytes
        // (spec §5). Falls back to loading the file directly per-item when no
        // identifier is available (see `importPicked` — this is what was making
        // import silently do nothing).
        .photosPicker(isPresented: $showPicker, selection: $pickerSelection,
                      maxSelectionCount: 0, matching: .any(of: [.videos, .images]))
        .onChange(of: pickerSelection) { _, newValue in
            guard !newValue.isEmpty else { return }
            let picked = newValue
            pickerSelection = []
            Task { await importPicked(picked) }
        }
        // In-app camera (full-screen) — iOS only, see spec note above.
        .fullScreenCover(isPresented: $showCamera) {
            CaptureView(
                onFinish: { clips in
                    let offset = (model.project.clips.map(\.order).max() ?? -1) + 1
                    for var clip in clips {
                        clip.order += offset
                        model.project.clips.append(clip)
                    }
                    model.autosave()
                    showCamera = false
                },
                onCancel: { showCamera = false }
            )
        }
        #endif
        // Trim editor sheet
        .sheet(item: $trimmingClip) { clip in
            TrimEditorView(
                clip: clip,
                resolver: resolver,
                onApply: { updated in
                    if let idx = model.project.clips.firstIndex(where: { $0.id == updated.id }) {
                        model.project.clips[idx] = updated
                        model.autosave()
                    }
                    trimmingClip = nil
                },
                onCancel: { trimmingClip = nil }
            )
        }
        #if os(iOS)
        .alert("Photo Access Needed", isPresented: $showAccessDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable photo library access in Settings to import your clips.")
        }
        #endif
        #if os(macOS)
        // Finder drag-and-drop — the natural Mac import path (F1): realtors and
        // photographers usually have raw footage sitting in a folder, not in
        // Photos.app. Accepts individual files or a whole dropped folder.
        .dropDestination(for: URL.self) { urls, _ in
            importDropped(urls)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .strokeBorder(Theme.Palette.accent, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .padding(Theme.Spacing.s)
                    .allowsHitTesting(false)
            }
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't import the selected item(s). Make sure they're video or photo files.")
        }
        #endif
        #if os(iOS)
        .confirmationDialog("Add Media", isPresented: $showAddDialog) {
            Button("Import from Photos") { Task { await requestAndPick() } }
            Button("Record with Camera") { showCamera = true }
            Button("Cancel", role: .cancel) {}
        }
        #endif
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "film.stack")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("No clips yet")
                .font(.headline).foregroundStyle(Theme.Palette.textPrimary)
            #if os(macOS)
            Text("Browse for video and photo files, or drag them (or a whole folder) in from Finder.")
                .font(.subheadline).multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textSecondary)
            #else
            Text("Import from your photo library or record new clips directly.")
                .font(.subheadline).multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textSecondary)
            #endif

            HStack(spacing: Theme.Spacing.m) {
                #if os(iOS)
                SecondaryButton(title: "Import", systemImage: "photo.on.rectangle", accessibilityID: "Import") {
                    Task { await requestAndPick() }
                }
                PrimaryButton(title: "Record", systemImage: "video.fill", accessibilityID: "Record") {
                    showCamera = true
                }
                #else
                PrimaryButton(title: "Import", systemImage: "folder", accessibilityID: "Import") {
                    chooseFilesFromFinder()
                }
                #endif
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    // MARK: - Clip cell

    private func clipCell(_ clip: MediaClip) -> some View {
        ZStack(alignment: .topTrailing) {
            AssetThumbnailView(localIdentifier: clip.sourceIdentifier, side: 100)

            // Remove button
            Button { model.removeClip(clip) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .padding(4)
            }
        }
        .overlay(alignment: .bottomLeading) {
            // Media-kind badge
            Image(systemName: clip.kind == .photo ? "photo" : "play.fill")
                .font(.caption2)
                .padding(4)
                .foregroundStyle(.white)
        }
        .overlay(alignment: .bottomTrailing) {
            // Trim button (scissors)
            Button {
                trimmingClip = clip
            } label: {
                Image(systemName: "scissors")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(Theme.Palette.accent.opacity(0.85), in: Circle())
            }
            .padding(4)
        }
        // Trim indicator dot
        .overlay(alignment: .topLeading) {
            if clip.trimStart != nil || clip.trimEnd != nil {
                Circle()
                    .fill(Theme.Palette.accent)
                    .frame(width: 8, height: 8)
                    .padding(6)
            }
        }
    }

    // MARK: - Add tile

    private var addTile: some View {
        Button {
            #if os(iOS)
            showAddDialog = true
            #else
            chooseFilesFromFinder()
            #endif
        } label: {
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .strokeBorder(Theme.Palette.textSecondary,
                              style: StrokeStyle(lineWidth: 1, dash: [5]))
                .frame(height: 100)
                .overlay {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(Theme.Palette.accent)
                }
        }
    }

    // MARK: - Helpers

    #if os(iOS)
    private func requestAndPick() async {
        let granted = await model.requestPhotoAccess()
        if granted { showPicker = true } else { showAccessDenied = true }
    }

    /// `PhotosPickerItem.itemIdentifier` (the PHAsset local identifier the rest
    /// of the pipeline prefers — spec §5, zero-copy) is only populated when the
    /// app already holds full Photos library authorization; it's `nil`
    /// otherwise, which was making import silently do nothing. Prefer the
    /// identifier when available; fall back to loading the file directly per
    /// item so a pick always produces a clip (never fails silently, spec §9).
    private func importPicked(_ items: [PhotosPickerItem]) async {
        var identifiers: [String] = []
        var fallbackClips: [MediaClip] = []
        var order = (model.project.clips.map(\.order).max() ?? -1) + 1

        for item in items {
            if let id = item.itemIdentifier {
                identifiers.append(id)
                continue
            }
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            if isVideo, let movie = try? await item.loadTransferable(type: TransferableMovie.self) {
                fallbackClips.append(MediaClip(sourceIdentifier: "file:\(movie.url.path)",
                                               kind: .video, order: order))
                order += 1
            } else if let data = try? await item.loadTransferable(type: Data.self) {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("import_\(UUID().uuidString).jpg")
                if (try? data.write(to: url, options: .atomic)) != nil {
                    fallbackClips.append(MediaClip(sourceIdentifier: "file:\(url.path)",
                                                   kind: .photo, order: order))
                    order += 1
                }
            }
        }

        if !identifiers.isEmpty {
            model.addPickedMedia(localIdentifiers: identifiers)
        }
        if !fallbackClips.isEmpty {
            model.project.clips.append(contentsOf: fallbackClips)
            model.autosave()
        }
        if identifiers.isEmpty && fallbackClips.isEmpty {
            showAccessDenied = true
        }
    }
    #endif

    #if os(macOS)
    // MARK: - File browsing & Finder drag-and-drop (macOS only)

    /// "Import" button action — a native Finder file browser, not PhotosPicker
    /// (which isn't a reliable Mac idiom and isn't where Mac users' footage
    /// tends to live anyway). Supports selecting files or a whole folder in one
    /// go; shares the same import pipeline as drag-and-drop below.
    private func chooseFilesFromFinder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.movie, .image]
        panel.prompt = String(localized: "Import")
        panel.message = String(localized: "Choose video and photo files, or a folder of footage, to import.")
        panel.begin { response in
            guard response == .OK else { return }
            importDropped(panel.urls)
        }
    }

    /// Entry point for both the Finder browser above and `.dropDestination`
    /// below — kicks off async import and returns immediately so neither the
    /// panel callback nor the drop gesture is blocked.
    private func importDropped(_ urls: [URL]) {
        Task { await addDroppedFiles(urls) }
    }

    private func addDroppedFiles(_ urls: [URL]) async {
        let mediaURLs = expandedMediaURLs(from: urls)
        guard !mediaURLs.isEmpty else {
            showImportError = true
            return
        }

        var order = (model.project.clips.map(\.order).max() ?? -1) + 1
        var newClips: [MediaClip] = []
        for url in mediaURLs {
            guard let kind = mediaKind(for: url), let copied = copyIntoImportsFolder(url) else { continue }
            newClips.append(MediaClip(sourceIdentifier: "file:\(copied.path)", kind: kind, order: order))
            order += 1
        }
        guard !newClips.isEmpty else {
            showImportError = true
            return
        }
        model.project.clips.append(contentsOf: newClips)
        model.autosave()
    }

    /// A dropped folder is expanded one level deep (its immediate children) —
    /// deliberately shallow so a large export/media folder doesn't recurse
    /// forever or pull in unrelated nested project folders.
    private func expandedMediaURLs(from urls: [URL]) -> [URL] {
        var result: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            if exists && isDirectory.boolValue {
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                result.append(contentsOf: children.filter { mediaKind(for: $0) != nil })
            } else if mediaKind(for: url) != nil {
                result.append(url)
            }
        }
        return result
    }

    private func mediaKind(for url: URL) -> MediaKind? {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .image) { return .photo }
        return nil
    }

    /// Copies the dropped file into the app's own storage rather than keeping a
    /// reference to its original Finder location — matches the precedent set by
    /// `TransferableMovie` above (the Photos-picker fallback path) and avoids
    /// needing a persisted security-scoped bookmark for a location the user
    /// might later move or rename.
    private func copyIntoImportsFolder(_ url: URL) -> URL? {
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer { if needsScopedAccess { url.stopAccessingSecurityScopedResource() } }

        let importsDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DroppedImports", isDirectory: true)
        try? FileManager.default.createDirectory(at: importsDir, withIntermediateDirectories: true)

        let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension
        let dest = importsDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            return nil
        }
    }
    #endif
}
