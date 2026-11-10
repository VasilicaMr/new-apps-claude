//
//  JourneyView.swift
//  LittlePhysicsTrail
//
//  Home: one stop per big physics idea along a winding trail (JourneyMapView).
//  Tapping an open stop starts LessonFlowView full screen; a locked one opens the
//  Full Journey unlock page, and the gear the grown-ups hub — both behind the parental gate.
//

import SwiftUI
import TrailDomain

struct JourneyView: View {
    @Environment(\.container) private var container
    @State private var viewModel: JourneyViewModel
    @State private var showGrownUps = false

    init(viewModel: JourneyViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .top) {
            NubeeBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, NubeeMetrics.gutter)
                    .padding(.bottom, 6)
                trail
            }

            if let toast = viewModel.toast {
                Label(toast, systemImage: "map.fill")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                    .background(NubeePalette.purple, in: Capsule())
                    .shadow(color: NubeePalette.purple.opacity(0.35), radius: 12, y: 6)
                    .padding(.top, 80)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
                    .accessibilityIdentifier("journey.toast")
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.toast)
        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: viewModel.markerStopID)
        .onAppear { viewModel.onAppear() }
        .fullScreenCover(item: $viewModel.lesson, onDismiss: viewModel.lessonClosed) { route in
            LessonFlowView(viewModel: container.makeLessonViewModel(stop: route.stop, showIntro: route.showIntro))
        }
        .onChange(of: viewModel.ownsFullJourney) { _, _ in viewModel.entitlementsChanged() }
        .sheet(item: $viewModel.unlockRequest, onDismiss: viewModel.unlockClosed) { stop in
            NubeeParentalGate {
                UnlockJourneyView(viewModel: container.makeUnlockViewModel()) { viewModel.explore(stop) }
            }
        }
        .sheet(isPresented: $showGrownUps, onDismiss: viewModel.grownUpsClosed) {
            NubeeParentalGate {
                GrownUpsView(viewModel: container.makeGrownUpsViewModel())
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Little Physics Trail")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(viewModel.journey.completedCount) of \(viewModel.journey.stops.count) big ideas discovered")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(NubeePalette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            NubeeStatPill(symbol: "star.fill", value: "\(viewModel.journey.totalStars)", tint: NubeePalette.orange, accessibilityLabel: "Stars")
            NubeeIconButton(symbol: "gearshape.fill", color: NubeePalette.slate, accessibilityLabel: "Grown-ups") {
                showGrownUps = true
            }
            .accessibilityIdentifier("journey.grownups")
        }
        .padding(.top, 8)
        .frame(maxWidth: 1000)
    }

    private var trail: some View {
        ScrollViewReader { proxy in
            ScrollView {
                JourneyMapView(
                    stops: viewModel.journey.stops,
                    markerStopID: viewModel.markerStopID,
                    onTap: viewModel.open
                )
                .padding(.horizontal, NubeeMetrics.gutter)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.markerStopID, initial: true) { _, id in
                guard let id else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(.easeInOut(duration: 0.9)) { proxy.scrollTo(JourneyMapView.scrollID(id), anchor: .center) }
                }
            }
        }
    }
}
