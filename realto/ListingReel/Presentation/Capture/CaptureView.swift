import SwiftUI
import AVFoundation

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Root view
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen AVFoundation camera (spec §F2).
/// All interactive controls are fully custom — no system buttons.
struct CaptureView: View {
    let onFinish: ([MediaClip]) -> Void
    let onCancel: () -> Void

    @State private var viewModel = CaptureViewModel()
    @State private var pinchBaseZoom: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black

            // ── Camera preview (extends behind safe areas) ──────────────────
            cameraPreviewLayer
                .ignoresSafeArea()

            // ── Gesture capture (below UI, above preview) ──────────────────
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { point in
                        let dev = CGPoint(x: point.x / geo.size.width,
                                         y: point.y / geo.size.height)
                        viewModel.focus(devicePoint: dev, previewPoint: point)
                    }
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                viewModel.onPinch(scale: scale, baseZoom: pinchBaseZoom)
                            }
                            .onEnded { _ in pinchBaseZoom = viewModel.zoomFactor }
                    )
            }
            .ignoresSafeArea()

            // ── Gradient scrims ────────────────────────────────────────────
            VStack {
                LinearGradient(colors: [.black.opacity(0.65), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 220)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.82)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 340)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // ── Focus brackets ────────────────────────────────────────────
            if let pt = viewModel.focusIndicatorPoint {
                FocusBrackets()
                    .position(x: pt.x, y: pt.y)
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(.easeOut(duration: 0.4)))
            }

            // ── UI stack (respects safe area) ─────────────────────────────
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                shotLabel
                    .padding(.top, 10)

                Spacer()

                bottomDock
            }
        }
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .alert("Camera Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) { onCancel() }
        } message: {
            Text(viewModel.setupError ?? "")
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75),
                   value: viewModel.recordedURLs.count)
    }

    // MARK: Camera layer

    @ViewBuilder
    private var cameraPreviewLayer: some View {
        #if targetEnvironment(simulator)
        ZStack {
            Color(white: 0.07)
            VStack(spacing: 14) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.18))
                Text("Simulator Preview")
                    .font(.caption2.weight(.medium))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        #else
        CameraPreviewView(session: viewModel.service.session)
        #endif
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 0) {
            // Close — rounded-square button (like Apple Camera)
            CloseButton(action: onCancel)

            Spacer()

            // Shot progress dots
            ShotProgressDots(
                total: viewModel.shotList.count,
                currentIndex: viewModel.currentShotIndex
            )

            Spacer()

            // Torch (idle) → REC timer (recording)
            if viewModel.isRecording {
                RecordingTimerBadge(elapsed: viewModel.elapsedSeconds)
            } else {
                TorchButton(
                    isOn: viewModel.isTorchOn,
                    isAvailable: viewModel.isTorchAvailable,
                    action: viewModel.toggleTorch
                )
            }
        }
    }

    // MARK: Shot label

    private var shotLabel: some View {
        VStack(spacing: 4) {
            if viewModel.allShotsComplete {
                allShotsDoneLabel
            } else {
                currentShotLabel
            }
            if let next = viewModel.nextShotTitle, !viewModel.isRecording {
                Text("Next: \(next)")
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var currentShotLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "scope")
                .font(.caption.weight(.semibold))
            Text(viewModel.currentShotTitle)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .environment(\.colorScheme, .dark)
    }

    private var allShotsDoneLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
            Text("All shots covered")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Theme.Palette.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.black.opacity(0.45), in: Capsule())
    }

    // MARK: Bottom dock (frosted glass panel)

    private var bottomDock: some View {
        VStack(spacing: 18) {
            // Zoom selector
            ZoomSelectorBar(zoomFactor: viewModel.zoomFactor) { level in
                viewModel.setZoomLevel(level)
                pinchBaseZoom = level
            }

            // Clip thumbnail strip
            if !viewModel.recordedURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 6) {
                        ForEach(viewModel.recordedURLs, id: \.absoluteString) { url in
                            RecordedClipThumb(url: url)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 56)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Main controls row: skip | record | flip
            HStack(spacing: 0) {
                // Skip
                SkipShotButton(
                    visible: !viewModel.allShotsComplete && !viewModel.isRecording,
                    action: viewModel.skipShot
                )
                .frame(width: 80)

                Spacer()

                // Record
                CustomRecordButton(isRecording: viewModel.isRecording) {
                    viewModel.toggleRecording()
                }

                Spacer()

                // Flip camera
                FlipCameraButton(isFrontCamera: viewModel.isFrontCamera) {
                    Task { await viewModel.flipCamera() }
                }
                .frame(width: 80)
            }
            .padding(.horizontal, 24)

            // Done button
            if !viewModel.recordedURLs.isEmpty && !viewModel.isRecording {
                DoneButton(count: viewModel.recordedURLs.count) {
                    onFinish(viewModel.finishedClips(startingOrder: 0))
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 16)
        .padding(.bottom, 36)
        .background(dockBackground)
        .environment(\.colorScheme, .dark)
    }

    private var dockBackground: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 32, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 32,
            style: .continuous
        )
        .fill(.ultraThinMaterial)
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 32, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 32,
                style: .continuous
            )
            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Close button
// ─────────────────────────────────────────────────────────────────────────────

private struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.black.opacity(0.42))
                    .frame(width: 38, height: 38)
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                    }
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Torch button
// ─────────────────────────────────────────────────────────────────────────────

private struct TorchButton: View {
    let isOn: Bool
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Glow halo when active
                if isOn {
                    Circle()
                        .fill(Theme.Palette.accent.opacity(0.35))
                        .frame(width: 56, height: 56)
                        .blur(radius: 10)
                }
                Circle()
                    .fill(isOn ? Theme.Palette.accent : Color.black.opacity(0.42))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                isOn ? Color.clear : Color.white.opacity(0.15),
                                lineWidth: 0.5
                            )
                    }
                Image(systemName: isOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isOn ? .black : .white)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.25)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isOn)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shot progress dots
// ─────────────────────────────────────────────────────────────────────────────

private struct ShotProgressDots: View {
    let total: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                let completed = i < currentIndex
                let active    = i == currentIndex
                Capsule()
                    .fill(completed ? Theme.Palette.accent
                          : active  ? Color.white
                          : Color.white.opacity(0.28))
                    .frame(width: active ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: currentIndex)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Recording timer badge
// ─────────────────────────────────────────────────────────────────────────────

private struct RecordingTimerBadge: View {
    let elapsed: Double
    @State private var bright = true

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 7, height: 7)
                .opacity(bright ? 1 : 0.2)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.55).repeatForever()) {
                        bright = false
                    }
                }
            let s = Int(elapsed)
            Text(String(format: "%d:%02d", s / 60, s % 60))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.52), in: Capsule())
        .overlay {
            Capsule().strokeBorder(.red.opacity(0.45), lineWidth: 1)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Zoom selector bar
// ─────────────────────────────────────────────────────────────────────────────

private struct ZoomSelectorBar: View {
    let zoomFactor: CGFloat
    let onSelect: (CGFloat) -> Void

    private let levels: [(String, CGFloat)] = [("1×", 1), ("2×", 2), ("3×", 3)]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(levels, id: \.1) { label, value in
                let active = abs(zoomFactor - value) < 0.35
                Button { onSelect(value) } label: {
                    Text(label)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(active ? Color.black : Color.white)
                        .frame(width: 46, height: 30)
                        .background {
                            Capsule()
                                .fill(active ? Theme.Palette.accent : Color.white.opacity(0.1))
                        }
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: zoomFactor)
            }
        }
        .padding(4)
        .background(.black.opacity(0.28), in: Capsule())
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Custom record button
// ─────────────────────────────────────────────────────────────────────────────

private struct CustomRecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulsing outer halo — recording only
                if isRecording {
                    Circle()
                        .fill(.red.opacity(0.22))
                        .frame(width: 110, height: 110)
                        .scaleEffect(pulseScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                                pulseScale = 1.4
                            }
                        }
                        .onDisappear { pulseScale = 1.0 }
                }

                // Spinning arc ring (recording) / static ring (idle)
                if isRecording {
                    TimelineView(.animation) { tl in
                        let angle = (tl.date.timeIntervalSinceReferenceDate * 90)
                            .truncatingRemainder(dividingBy: 360)
                        Circle()
                            .trim(from: 0.08, to: 0.88)
                            .stroke(
                                AngularGradient(
                                    colors: [.red, .red.opacity(0.15)],
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(320)
                                ),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .frame(width: 92, height: 92)
                            .rotationEffect(.degrees(angle))
                    }
                } else {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3.5
                        )
                        .frame(width: 92, height: 92)
                }

                // Inner glass fill
                Circle()
                    .fill(.white.opacity(0.07))
                    .frame(width: 78, height: 78)

                // Core: filled circle → stop square
                if isRecording {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.red)
                        .frame(width: 33, height: 33)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 63, height: 63)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isRecording)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Flip camera button
// ─────────────────────────────────────────────────────────────────────────────

private struct FlipCameraButton: View {
    let isFrontCamera: Bool
    let action: () -> Void

    @State private var flipAngle: Double = 0

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.65)) {
                flipAngle += 180
            }
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.38))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                    }
                Image(systemName: "camera.rotate")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0))
            }
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Skip shot button
// ─────────────────────────────────────────────────────────────────────────────

private struct SkipShotButton: View {
    let visible: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if visible {
                Button(action: action) {
                    VStack(spacing: 3) {
                        Image(systemName: "forward.end")
                            .font(.system(size: 16, weight: .medium))
                        Text("Skip")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.65))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            } else {
                Color.clear
            }
        }
        .animation(.easeInOut(duration: 0.2), value: visible)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Done button
// ─────────────────────────────────────────────────────────────────────────────

private struct DoneButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                Text(count == 1 ? "Use 1 clip" : "Use \(count) clips")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Focus brackets (Canvas-drawn L-shaped corners)
// ─────────────────────────────────────────────────────────────────────────────

private struct FocusBrackets: View {
    @State private var scale: CGFloat = 1.4

    private let sz: CGFloat = 82
    private let arm: CGFloat = 18
    private let lw: CGFloat = 1.8

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height, a = arm

            func draw(_ pts: [(CGFloat, CGFloat)]) {
                var p = Path()
                p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
                pts.dropFirst().forEach { p.addLine(to: CGPoint(x: $0.0, y: $0.1)) }
                ctx.stroke(p, with: .color(.yellow),
                           style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            }

            draw([(a, 0), (0, 0), (0, a)])             // ┌
            draw([(w - a, 0), (w, 0), (w, a)])         // ┐
            draw([(0, h - a), (0, h), (a, h)])         // └
            draw([(w, h - a), (w, h), (w - a, h)])     // ┘
        }
        .frame(width: sz, height: sz)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { scale = 1.0 }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Recorded clip thumbnail
// ─────────────────────────────────────────────────────────────────────────────

private struct RecordedClipThumb: View {
    let url: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))

            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "video.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            }

            // Check badge
            ZStack {
                Circle().fill(.black.opacity(0.5)).frame(width: 16, height: 16)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.Palette.accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(3)
        }
        .frame(width: 52, height: 52)
        .task(id: url.absoluteString) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 104, height: 104)
        if let cg = try? await gen.image(at: .zero).image {
            thumbnail = UIImage(cgImage: cg)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AVFoundation preview layer
// ─────────────────────────────────────────────────────────────────────────────

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView { PreviewUIView(session: session) }
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        init(session: AVCaptureSession) {
            super.init(frame: .zero)
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
        }
        required init?(coder: NSCoder) { fatalError() }
    }
}
