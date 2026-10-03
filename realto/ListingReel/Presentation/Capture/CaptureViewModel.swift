import AVFoundation
import SwiftUI

/// Drives the in-app camera capture flow.
/// Shot list auto-advances after each recording; user can also skip manually.
@Observable
@MainActor
final class CaptureViewModel {

    // MARK: - Shot list

    nonisolated static let defaultShots = [
        String(localized: "Exterior — front of home", comment: "Guided shot-list prompt during in-app capture"),
        String(localized: "Living Room", comment: "Guided shot-list prompt during in-app capture"),
        String(localized: "Kitchen", comment: "Guided shot-list prompt during in-app capture"),
        String(localized: "Primary Bedroom", comment: "Guided shot-list prompt during in-app capture"),
        String(localized: "Bathrooms", comment: "Guided shot-list prompt during in-app capture"),
        String(localized: "Outdoor / Back yard", comment: "Guided shot-list prompt during in-app capture"),
    ]

    let shotList: [String]
    private(set) var currentShotIndex = 0

    var currentShotTitle: String {
        shotList.indices.contains(currentShotIndex)
            ? shotList[currentShotIndex]
            : String(localized: "Extra clips", comment: "Shown once the guided shot list is complete but the user keeps recording")
    }
    var nextShotTitle: String? {
        let next = currentShotIndex + 1
        return shotList.indices.contains(next) ? shotList[next] : nil
    }
    var allShotsComplete: Bool { currentShotIndex >= shotList.count }

    // MARK: - Recording state

    let service = CaptureService()
    private(set) var isRecording = false
    private(set) var recordedURLs: [URL] = []
    /// The shot-list prompt each recording was made for (parallel to `recordedURLs`);
    /// nil once past the list. Becomes the clip's room label for the AI voiceover.
    private var recordedShotTitles: [String?] = []
    private(set) var elapsedSeconds: Double = 0
    private var recordingTimer: Timer?

    // Camera controls — mirrored from service after mutations.
    private(set) var isFrontCamera = false
    private(set) var isTorchOn = false
    private(set) var isTorchAvailable = false
    private(set) var zoomFactor: CGFloat = 1.0

    // Screen-space point for the focus crosshair overlay.
    private(set) var focusIndicatorPoint: CGPoint?

    // Setup / error
    var setupError: String?
    var showErrorAlert = false
    private(set) var isReady = false

    // MARK: - Init

    init(shotList: [String] = defaultShots) {
        self.shotList = shotList
        service.onRecordingFinished = { [weak self] result in
            Task { @MainActor in self?.handleRecordingFinished(result) }
        }
    }

    // MARK: - Lifecycle

    func onAppear() async {
        #if targetEnvironment(simulator)
        isReady = true      // no camera in simulator; CaptureView shows a placeholder
        #else
        do {
            try await service.requestAndConfigure(position: .back)
            service.start()
            isTorchAvailable = service.isTorchAvailable
            isReady = true
        } catch {
            setupError = (error as? CaptureService.CaptureError)?.errorDescription
                ?? error.localizedDescription
            showErrorAlert = true
        }
        #endif
    }

    func onDisappear() {
        stopTimer()
        if isRecording {
            service.stopRecording()
            isRecording = false
        }
        service.stop()
    }

    // MARK: - Recording

    func toggleRecording() {
        guard isReady else { return }
        if isRecording {
            service.stopRecording()
            isRecording = false
            stopTimer()
            haptic(.medium)
        } else {
            do {
                try service.startRecording()
                isRecording = true
                elapsedSeconds = 0
                startTimer()
                haptic(.heavy)
            } catch {
                setupError = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func handleRecordingFinished(_ result: Result<URL, Error>) {
        isRecording = false
        stopTimer()
        switch result {
        case .success(let url):
            recordedURLs.append(url)
            recordedShotTitles.append(shotList.indices.contains(currentShotIndex) ? shotList[currentShotIndex] : nil)
            advanceShot()
        case .failure(let error):
            setupError = error.localizedDescription
            showErrorAlert = true
        }
    }

    // MARK: - Shot navigation

    func skipShot() {
        guard !isRecording else { return }
        advanceShot()
    }

    private func advanceShot() {
        if currentShotIndex < shotList.count {
            currentShotIndex += 1
        }
    }

    // MARK: - Camera controls

    func flipCamera() async {
        await service.switchCamera()
        isFrontCamera = service.currentPosition == .front
        if isFrontCamera { isTorchOn = false }
        isTorchAvailable = service.isTorchAvailable
        zoomFactor = 1.0
        service.setZoom(1.0)
    }

    func toggleTorch() {
        guard isTorchAvailable, !isFrontCamera else { return }
        service.toggleTorch()
        isTorchOn = service.isTorchActive
    }

    func setZoomLevel(_ factor: CGFloat) {
        let clamped = max(1, min(factor, 8))
        zoomFactor = clamped
        service.setZoom(clamped)
    }

    // Cycles 1× → 2× → 3× → back to 1×.
    func tapZoomCycle() {
        let presets: [CGFloat] = [1, 2, 3]
        let next = presets.first(where: { $0 > zoomFactor + 0.1 }) ?? 1
        zoomFactor = next
        service.setZoom(next)
    }

    /// Call with live pinch scale and the zoom level captured at gesture start.
    func onPinch(scale: CGFloat, baseZoom: CGFloat) {
        let clamped = max(1, min(baseZoom * scale, 8))
        zoomFactor = clamped
        service.setZoom(clamped)
    }

    /// `devicePoint` is in AVFoundation coords [0,1]. `previewPoint` is screen-space for the overlay.
    func focus(devicePoint: CGPoint, previewPoint: CGPoint) {
        service.focusAndExpose(at: devicePoint)
        focusIndicatorPoint = previewPoint
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            focusIndicatorPoint = nil
        }
    }

    // MARK: - Commit to project

    func finishedClips(startingOrder: Int) -> [MediaClip] {
        recordedURLs.enumerated().map { idx, url in
            MediaClip(
                sourceIdentifier: "file:\(url.path)",
                kind: .video,
                order: startingOrder + idx,
                roomLabel: recordedShotTitles.indices.contains(idx) ? recordedShotTitles[idx] : nil
            )
        }
    }

    // MARK: - Private helpers

    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.elapsedSeconds += 0.1 }
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        elapsedSeconds = 0
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
