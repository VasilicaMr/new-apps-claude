import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Step 7 — Export. Choose formats/resolution, render (progress, cancellable),
/// then save to Photos / share. Never fails silently (spec §4.4).
struct ExportStepView: View {
    @Bindable var model: EditorFlowModel
    let coordinator: AppCoordinator

    @Environment(SubscriptionManager.self) private var subscription

    @State private var exportModel: ExportViewModel?
    @State private var showPaywall = false
    @State private var didCopyCaption = false
    @FocusState private var isEditingCaption: Bool

    var body: some View {
        StepScaffold(route: .export) {
            switch exportModel?.phase {
            case .none, .idle:
                settings
            case .rendering(let progress):
                renderingView(progress)
            case .finished(let files):
                resultsView(files)
            case .failed(let error):
                failureView(error)
            }
        } footer: {
            footer
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(onDismiss: { showPaywall = false })
        }
    }

    // MARK: - Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            SectionHeader(title: "Formats",
                          subtitle: "Export every size you need in one tap.")
            VStack(spacing: Theme.Spacing.s) {
                ForEach(AspectRatio.allCases) { ratio in
                    aspectRow(ratio)
                }
            }

            SectionHeader(title: "Quality")
            Picker("Resolution", selection: Binding(
                get: { model.project.exportSettings.resolution },
                set: { model.setResolution($0) })) {
                ForEach(Resolution.allCases) { res in
                    Text(res.displayName).tag(res)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!subscription.isUnlocked && model.project.exportSettings.resolution == .uhd4K)

            watermarkBanner
        }
    }

    @ViewBuilder
    private var watermarkBanner: some View {
        if subscription.isUnlocked {
            Label("No watermark — full version unlocked", systemImage: "checkmark.seal.fill")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.success)
        } else {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "drop.fill").foregroundStyle(Theme.Palette.textSecondary)
                Text("Free exports include a small watermark.")
                    .font(.footnote).foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Button("Unlock →") { showPaywall = true }
                    .font(.footnote.bold())
                    .foregroundStyle(Theme.Palette.accent)
            }
            .padding(Theme.Spacing.m)
            .cardSurface(radius: Theme.Radius.control)
        }
    }

    private func aspectRow(_ ratio: AspectRatio) -> some View {
        let selected = model.project.exportSettings.aspectRatios.contains(ratio)
        return Button {
            model.toggleAspectRatio(ratio)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: iconName(ratio))
                    .foregroundStyle(Theme.Palette.accent).frame(width: 28)
                Text(ratio.displayName).foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? Theme.Palette.accent : Theme.Palette.textSecondary)
            }
            .padding(Theme.Spacing.m)
            .cardSurface(radius: Theme.Radius.control)
        }
    }

    private func iconName(_ ratio: AspectRatio) -> String {
        switch ratio {
        case .vertical9x16: return "rectangle.portrait"
        case .square1x1:    return "square"
        case .wide16x9:     return "rectangle"
        }
    }

    // MARK: - Rendering

    private func renderingView(_ progress: RenderProgress) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            SectionHeader(
                title: "Rendering…",
                subtitle: "Format \(progress.currentFormatIndex + 1) of \(progress.totalFormats) · \(progress.currentAspectRatio.rawValue)")
            ProgressView(value: progress.fractionComplete)
                .tint(Theme.Palette.accent)
            Text("\(progress.overallPercent)%")
                .font(.largeTitle.bold().monospacedDigit())
                .foregroundStyle(Theme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    // MARK: - Results

    private func resultsView(_ files: [ExportedFile]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionHeader(title: "Done! 🎉",
                          subtitle: files.count == 1 ? "1 video ready." : "\(files.count) videos ready.")
                .accessibilityIdentifier("export.resultsHeader")
            ForEach(files) { file in
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Palette.success)
                    VStack(alignment: .leading) {
                        Text(file.aspectRatio.displayName).foregroundStyle(Theme.Palette.textPrimary)
                        Text(byteString(file.fileSizeBytes))
                            .font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Spacer()
                    #if os(macOS)
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                    } label: {
                        Image(systemName: "folder")
                    }
                    .accessibilityLabel(Text("Reveal in Finder"))
                    #endif
                    ShareLink(item: file.url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .padding(Theme.Spacing.m)
                .cardSurface(radius: Theme.Radius.control)
            }
            if let exportModel, exportModel.savedToPhotos {
                Label("Saved to Photos", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.Palette.success)
            }
            if let saveError = exportModel?.saveError {
                Text(saveError).font(.caption).foregroundStyle(Theme.Palette.danger)
            }
            postCaptionSection
            if model.project.openHouse == nil {
                openHouseCard
            }
            #if os(macOS)
            if let exportModel, exportModel.savedToFolder {
                Label("Saved to folder", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.Palette.success)
            }
            if let folderSaveError = exportModel?.folderSaveError {
                Text(folderSaveError).font(.caption).foregroundStyle(Theme.Palette.danger)
            }
            #endif
        }
    }

    // MARK: - Post caption

    private var postCaptionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Post caption",
                          subtitle: "Paste it when you post the video. Edit anything you like.")
            TextEditor(text: $model.postCaption)
                .focused($isEditingCaption)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 160)
                .padding(Theme.Spacing.s)
                .background(Theme.Palette.surface)
                .foregroundStyle(Theme.Palette.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                .disabled(model.isWritingCaption)
                .accessibilityIdentifier("export.caption")
            HStack(spacing: Theme.Spacing.m) {
                Button {
                    copyCaption()
                } label: {
                    Label(didCopyCaption ? LocalizedStringKey("Copied") : LocalizedStringKey("Copy caption"),
                          systemImage: didCopyCaption ? "checkmark" : "doc.on.doc")
                }
                .accessibilityIdentifier("export.copyCaption")
                Spacer()
                if model.canWriteCaptionWithAI {
                    Button {
                        isEditingCaption = false
                        Task { await model.writePostCaption() }
                    } label: {
                        if model.isWritingCaption {
                            ProgressView()
                        } else {
                            Label(model.project.socialCaption == nil ? LocalizedStringKey("Write with AI") : LocalizedStringKey("Rewrite"),
                                  systemImage: "sparkles")
                        }
                    }
                    .disabled(model.isWritingCaption)
                    .accessibilityIdentifier("export.writeCaption")
                }
            }
            .font(.subheadline.weight(.medium))
            .tint(Theme.Palette.accent)
            if let message = model.captionMessage {
                Text(message).font(.caption).foregroundStyle(Theme.Palette.danger)
            }
        }
        .padding(.top, Theme.Spacing.m)
        .onChange(of: isEditingCaption) { _, editing in
            if !editing { model.autosave() }
        }
    }

    private func copyCaption() {
        isEditingCaption = false
        model.autosave()
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.postCaption, forType: .string)
        #else
        UIPasteboard.general.string = model.postCaption
        #endif
        didCopyCaption = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            didCopyCaption = false
        }
    }

    /// One listing, many posts: offer the open house announcement while the agent is
    /// already thinking about posting.
    private var openHouseCard: some View {
        Button {
            model.autosave()
            coordinator.startOpenHousePost(from: model.project)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(Theme.Palette.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hosting an open house?")
                        .font(.headline).foregroundStyle(Theme.Palette.textPrimary)
                    Text("Make the announcement reel from this footage.")
                        .font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(Theme.Spacing.m)
            .cardSurface(radius: Theme.Radius.card)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("export.openHousePost")
    }

    // MARK: - Failure (never silent, spec §4.4)

    private func failureView(_ error: RenderError) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44)).foregroundStyle(Theme.Palette.danger)
            Text("Export failed").font(.headline).foregroundStyle(Theme.Palette.textPrimary)
            Text(error.errorDescription ?? String(localized: "Something went wrong."))
                .font(.subheadline).multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        switch exportModel?.phase {
        case .none, .idle:
            PrimaryButton(
                title: model.project.exportSettings.aspectRatios.count == 1
                    ? "Render 1 format" : "Render \(model.project.exportSettings.aspectRatios.count) formats",
                systemImage: "wand.and.stars",
                accessibilityID: "export.renderButton"
            ) {
                // Apply subscription-aware watermark flag before snapshotting.
                var projectCopy = model.project
                projectCopy.exportSettings.includeWatermark = !subscription.isUnlocked
                let vm = coordinator.makeExportModel(project: projectCopy)
                exportModel = vm
                vm.start()
            }
        case .rendering:
            SecondaryButton(title: "Cancel", systemImage: "xmark", accessibilityID: "Cancel") { exportModel?.cancel() }
        case .finished:
            VStack(spacing: Theme.Spacing.s) {
                #if os(macOS)
                PrimaryButton(
                    title: exportModel?.savedToFolder == true ? "Saved to Folder" : "Save to Folder…",
                    systemImage: "folder",
                    isEnabled: exportModel?.savedToFolder != true,
                    accessibilityID: "export.saveToFolderButton") {
                    chooseFolderAndSave()
                }
                SecondaryButton(
                    title: exportModel?.savedToPhotos == true ? "Saved to Photos" : "Save to Photos",
                    systemImage: "square.and.arrow.down",
                    accessibilityID: "export.saveToPhotosButton") {
                    Task { await exportModel?.saveAllToPhotos() }
                }
                #else
                PrimaryButton(
                    title: exportModel?.savedToPhotos == true ? "Saved to Photos" : "Save to Photos",
                    systemImage: "square.and.arrow.down",
                    isEnabled: exportModel?.savedToPhotos != true,
                    accessibilityID: "export.saveToPhotosButton") {
                    Task { await exportModel?.saveAllToPhotos() }
                }
                #endif
                SecondaryButton(title: "Done", accessibilityID: "export.doneButton") { coordinator.finishAndReturnHome() }
            }
        case .failed(let error):
            VStack(spacing: Theme.Spacing.s) {
                if error.isRetryable {
                    PrimaryButton(title: "Retry", systemImage: "arrow.clockwise", accessibilityID: "Retry") {
                        exportModel?.retry()
                    }
                }
                SecondaryButton(title: "Back", accessibilityID: "Back") { exportModel = nil }
            }
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    #if os(macOS)
    private func chooseFolderAndSave() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Save")
        panel.message = String(localized: "Choose a folder to save your exported videos.")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            exportModel?.saveAllToFolder(url)
        }
    }
    #endif
}
