//
//  GrownUpsView.swift
//  LittlePhysicsTrail
//
//  Behind the parental gate: Full Journey purchase status, read-aloud setting, what each
//  stop teaches (with the child's stars and the try-at-home activity), and reset progress.
//

import SwiftUI
import TrailDomain

struct GrownUpsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.container) private var container
    @State private var viewModel: GrownUpsViewModel
    @State private var confirmReset = false
    @State private var showUnlock = false

    init(viewModel: GrownUpsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            NubeeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Grown-ups")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(NubeePalette.ink)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(NubeePalette.inkSoft)
                                .frame(width: 40, height: 40)
                                .background(NubeePalette.surface, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }

                    journeyCard

                    Toggle(isOn: $viewModel.readAloud) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Read aloud")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                            Text("Questions, big ideas and facts are spoken for pre-readers.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(NubeePalette.inkSoft)
                        }
                    }
                    .tint(NubeePalette.mint)
                    .foregroundStyle(NubeePalette.ink)
                    .nubeeSurface(radius: 22, padding: 16)
                    .accessibilityIdentifier("grownups.readAloud")

                    sectionTitle("What your child is learning")
                    ForEach(viewModel.journey.stops) { entry in
                        stopCard(entry)
                    }

                    sectionTitle("Privacy")
                    Text("No ads, no accounts, no tracking. Progress stays on this device.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(NubeePalette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .nubeeSurface(radius: 22, padding: 16)

                    NubeePillButton(title: "Reset progress", symbol: "arrow.counterclockwise", color: NubeePalette.wrong, fullWidth: true) {
                        confirmReset = true
                    }
                    .accessibilityIdentifier("grownups.reset")
                    .padding(.top, 6)
                }
                .padding(NubeeMetrics.gutter)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: viewModel.ownsFullJourney) { _, _ in viewModel.refresh() }
        .sheet(isPresented: $showUnlock) {
            UnlockJourneyView(viewModel: container.makeUnlockViewModel())
        }
        .confirmationDialog("Reset all stars?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset progress", role: .destructive, action: viewModel.reset)
        } message: {
            Text("Stars and seen big ideas are cleared. Settings are kept.")
        }
    }

    private var journeyCard: some View {
        HStack(spacing: 12) {
            Text("🗺️").font(.system(size: 32))
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.ownsFullJourney ? "Full journey unlocked" : "First 3 stops are free")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(NubeePalette.ink)
                Text(viewModel.ownsFullJourney
                     ? "All \(viewModel.journey.stops.count) stops are open. Thank you!"
                     : "Unlock all \(viewModel.journey.stops.count) stops with one purchase\(viewModel.price.map { " (\($0))" } ?? "").")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(NubeePalette.inkSoft)
            }
            Spacer(minLength: 8)
            if !viewModel.ownsFullJourney {
                Button { showUnlock = true } label: {
                    Text("See more")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                }
                .buttonStyle(NubeeChunkyButtonStyle(color: NubeePalette.purple, radius: 16, depth: 3))
                .accessibilityIdentifier("grownups.unlock")
            }
        }
        .nubeeSurface(radius: 22, padding: 16)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .foregroundStyle(NubeePalette.ink)
            .padding(.top, 6)
    }

    private func stopCard(_ entry: StopProgress) -> some View {
        let stop = entry.stop
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(stop.emoji).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text(stop.title)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(stop.color)
                    Text(stop.bigIdea.headline)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(NubeePalette.ink)
                }
                Spacer(minLength: 8)
                if entry.isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(NubeePalette.inkSoft)
                        .accessibilityLabel("Locked")
                } else {
                    StarsRow(earned: entry.bestStars, size: 13)
                }
            }
            Text("Try at home: \(stop.bigIdea.tryAtHome)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(NubeePalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nubeeSurface(radius: 22, padding: 16)
    }
}
