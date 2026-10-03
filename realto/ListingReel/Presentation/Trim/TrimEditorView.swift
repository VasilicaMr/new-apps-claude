import SwiftUI
import AVFoundation

/// Professional per-clip trim editor. Shows a video filmstrip with two
/// draggable handles (green = start, blue = end). Time readouts update live.
/// Called from MediaStepView; applies changes via the `onApply` closure.
struct TrimEditorView: View {
    let clip: MediaClip
    let resolver: AVAssetResolver
    let onApply: (MediaClip) -> Void
    let onCancel: () -> Void

    @State private var viewModel: TrimEditorViewModel

    init(clip: MediaClip, resolver: AVAssetResolver,
         onApply: @escaping (MediaClip) -> Void, onCancel: @escaping () -> Void) {
        self.clip = clip
        self.resolver = resolver
        self.onApply = onApply
        self.onCancel = onCancel
        _viewModel = State(initialValue: TrimEditorViewModel(clip: clip, resolver: resolver))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading clip…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .padding()
                } else if let asset = viewModel.asset {
                    trimContent(asset: asset)
                }
            }
            .screenBackground()
            .navigationTitle("Trim Clip")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        var updated = clip
                        viewModel.apply(to: &updated)
                        onApply(updated)
                    }
                    .bold()
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Trim UI

    private func trimContent(asset: AVAsset) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()

            // Time readout row
            HStack {
                timeLabel(viewModel.trimStart, color: Theme.Palette.accent, label: "Start")
                Spacer()
                VStack(spacing: 2) {
                    Text("Duration")
                        .font(.caption2).foregroundStyle(Theme.Palette.textSecondary)
                    Text(TrimEditorViewModel.formatTime(viewModel.trimmedDuration))
                        .font(.body.monospacedDigit().bold())
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                Spacer()
                timeLabel(viewModel.trimEnd, color: Theme.Palette.accentAlt, label: "End")
            }
            .padding(.horizontal, Theme.Spacing.l)

            // Filmstrip + handles
            GeometryReader { geo in
                let w = geo.size.width
                let startX = w * viewModel.startFraction
                let endX   = w * viewModel.endFraction
                let handleW: CGFloat = 22

                ZStack(alignment: .leading) {
                    // Thumbnail filmstrip
                    VideoThumbnailStrip(asset: asset, duration: viewModel.duration)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Darkened regions outside trim
                    scrim(width: startX)
                    scrim(width: w - endX).offset(x: endX)

                    // Trim region border
                    Rectangle()
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
                        .frame(width: max(endX - startX, handleW), height: 80)
                        .offset(x: startX)
                        .allowsHitTesting(false)

                    // Start handle (green)
                    handle(color: Theme.Palette.accent, x: startX - handleW / 2)
                        .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .local)
                            .onChanged { v in
                                viewModel.updateStart(fraction: v.location.x / w)
                            })

                    // End handle (blue)
                    handle(color: Theme.Palette.accentAlt, x: endX - handleW / 2)
                        .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .local)
                            .onChanged { v in
                                viewModel.updateEnd(fraction: v.location.x / w)
                            })
                }
                .frame(width: w, height: 80)
            }
            .frame(height: 80)
            .padding(.horizontal, Theme.Spacing.l)

            // Hint
            Text("Drag the handles to set start and end points.")
                .font(.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()
        }
    }

    // MARK: - Sub-views

    private func timeLabel(_ t: TimeInterval, color: Color, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(Theme.Palette.textSecondary)
            Text(TrimEditorViewModel.formatTime(t))
                .font(.body.monospacedDigit().bold())
                .foregroundStyle(color)
        }
    }

    private func scrim(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.55))
            .frame(width: max(width, 0), height: 80)
            .allowsHitTesting(false)
    }

    private func handle(color: Color, x: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: 22, height: 80)
            .overlay(alignment: .center) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 3, height: 28)
            }
            .offset(x: x)
    }
}
