import AVFoundation
import Foundation

/// Manages `AVCaptureSession` lifecycle: camera/mic input, orientation-aware
/// recording, zoom, torch, tap-to-focus/expose, and front/rear switching.
/// All session mutations run on `sessionQueue`.
final class CaptureService: NSObject {

    enum CaptureError: LocalizedError {
        case accessDenied(AVMediaType)
        case setupFailed(String)

        var errorDescription: String? {
            switch self {
            case .accessDenied(.video):
                return String(localized: "Camera access is required. Enable it in Settings → Privacy → Camera.")
            case .accessDenied(.audio):
                return String(localized: "Microphone access is required. Enable it in Settings → Privacy → Microphone.")
            case .accessDenied:
                return String(localized: "Media access denied.")
            case .setupFailed(let msg):
                return String(localized: "Camera setup failed: \(msg)")
            }
        }
    }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.adaptiveservices.realto.capture", qos: .userInitiated)
    private var movieOutput: AVCaptureMovieFileOutput?

    // Mutable device tracking — only mutated on `queue`, read elsewhere racy-but-ok for UI hints.
    private(set) var currentCamera: AVCaptureDevice?
    private(set) var currentPosition: AVCaptureDevice.Position = .back

    /// Called on the main actor when a recording file is finalized.
    var onRecordingFinished: ((Result<URL, Error>) -> Void)?

    // MARK: - Public state helpers (read from any thread; values are approximate)

    var isTorchAvailable: Bool { currentCamera?.hasTorch ?? false }
    var isTorchActive: Bool    { currentCamera?.torchMode == .on }
    var isRecording: Bool      { movieOutput?.isRecording ?? false }
    var maxZoom: CGFloat       { min(currentCamera?.activeFormat.videoMaxZoomFactor ?? 1, 8) }

    // MARK: - Setup

    func requestAndConfigure(position: AVCaptureDevice.Position = .back) async throws {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            throw CaptureError.accessDenied(.video)
        }
        await AVCaptureDevice.requestAccess(for: .audio)   // best-effort

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async {
                do { try self.buildSession(position: position); cont.resume() }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    private func buildSession(position: AVCaptureDevice.Position) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let camIn = try? AVCaptureDeviceInput(device: cam),
              session.canAddInput(camIn) else {
            throw CaptureError.setupFailed(String(localized: "No camera available on this device."))
        }
        session.addInput(camIn)
        currentCamera = cam
        currentPosition = position

        if let mic = AVCaptureDevice.default(for: .audio),
           let micIn = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(micIn) {
            session.addInput(micIn)
        }

        let output = AVCaptureMovieFileOutput()
        guard session.canAddOutput(output) else {
            throw CaptureError.setupFailed(String(localized: "Could not attach movie output."))
        }
        session.addOutput(output)
        movieOutput = output

        // Stabilisation — only available on physical iOS devices.
        #if !targetEnvironment(simulator)
        if let conn = output.connection(with: .video),
           conn.isVideoStabilizationSupported {
            conn.preferredVideoStabilizationMode = .auto
        }
        #endif
    }

    // MARK: - Lifecycle

    func start() { queue.async { self.session.startRunning() } }
    func stop()  { queue.async { self.session.stopRunning()  } }

    // MARK: - Camera flip

    /// Switches between front and back camera without stopping the session.
    func switchCamera() async {
        let newPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                guard let self else { cont.resume(); return }
                self.session.beginConfiguration()

                // Remove existing video inputs.
                self.session.inputs
                    .compactMap { $0 as? AVCaptureDeviceInput }
                    .filter { $0.device.hasMediaType(.video) }
                    .forEach { self.session.removeInput($0) }

                // Add the opposite camera.
                if let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                   let input = try? AVCaptureDeviceInput(device: cam),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentCamera = cam
                    self.currentPosition = newPosition
                }

                self.session.commitConfiguration()
                cont.resume()
            }
        }
    }

    // MARK: - Torch

    func toggleTorch() {
        queue.async { [weak self] in
            guard let device = self?.currentCamera, device.hasTorch else { return }
            try? device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            device.unlockForConfiguration()
        }
    }

    func setTorch(on: Bool) {
        queue.async { [weak self] in
            guard let device = self?.currentCamera, device.hasTorch else { return }
            try? device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
    }

    // MARK: - Zoom

    func setZoom(_ factor: CGFloat) {
        queue.async { [weak self] in
            guard let device = self?.currentCamera else { return }
            let clamped = max(1, min(factor, device.activeFormat.videoMaxZoomFactor))
            try? device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        }
    }

    // MARK: - Tap to focus / expose

    /// `devicePoint` is in AVFoundation device coordinates: (0,0) top-left, (1,1) bottom-right.
    func focusAndExpose(at devicePoint: CGPoint) {
        queue.async { [weak self] in
            guard let device = self?.currentCamera else { return }
            try? device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        }
    }

    // MARK: - Recording

    func startRecording() throws {
        guard let output = movieOutput, !output.isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture_\(UUID().uuidString).mp4")
        queue.async { output.startRecording(to: url, recordingDelegate: self) }
    }

    func stopRecording() {
        queue.async { [weak self] in self?.movieOutput?.stopRecording() }
    }
}

extension CaptureService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        let result: Result<URL, Error> = error.map { .failure($0) } ?? .success(url)
        let cb = onRecordingFinished
        Task { @MainActor in cb?(result) }
    }
}
