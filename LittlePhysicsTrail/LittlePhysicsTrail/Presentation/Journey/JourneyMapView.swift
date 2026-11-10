//
//  JourneyMapView.swift
//  LittlePhysicsTrail
//
//  The trail: a winding road with one stop per physics idea, in order. Ported from
//  ShadowMatch/Views/JourneyMapView.swift — same road, regions, pulsing "next" ring and
//  greyed-out locked stops; art is emoji instead of pictures.
//

import SwiftUI
import TrailDomain

struct JourneyMapView: View {
    let stops: [StopProgress]
    /// Stop the owl stands next to (suggested next stop), if any.
    let markerStopID: String?
    let onTap: (JourneyStop) -> Void

    /// ScrollViewReader target for a stop.
    static func scrollID(_ stopID: String) -> String { "stop.\(stopID)" }

    private let spacing: CGFloat = 250
    private let startY: CGFloat = 56
    private let firstStopY: CGFloat = 200
    private let maxWidth: CGFloat = 640

    private func stopY(_ i: Int) -> CGFloat { firstStopY + CGFloat(i) * spacing }
    private func xFraction(_ i: Int) -> CGFloat { i.isMultiple(of: 2) ? 0.28 : 0.72 }
    private var endY: CGFloat { stopY(max(stops.count - 1, 0)) + 210 }
    private var height: CGFloat { endY + 90 }

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width, maxWidth)
            let points = stops.indices.map { CGPoint(x: w * xFraction($0), y: stopY($0)) }
            let start = CGPoint(x: w * 0.5, y: startY)
            let end = CGPoint(x: w * 0.5, y: endY)

            ZStack(alignment: .topLeading) {
                // Scroll targets: `.position`ed views report the whole map as their frame,
                // so each stop gets a 1pt anchor placed with padding instead.
                ForEach(Array(stops.enumerated()), id: \.element.id) { i, entry in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .id(Self.scrollID(entry.id))
                        .padding(.top, stopY(i))
                        .padding(.leading, points[i].x)
                        .accessibilityHidden(true)
                }

                regions(fullWidth: geo.size.width, journeyWidth: w)
                road(through: [start] + points + [end])

                startFlag.position(start)

                ForEach(Array(stops.enumerated()), id: \.element.id) { i, entry in
                    decorations(for: entry, index: i, width: w)
                }

                ForEach(Array(stops.enumerated()), id: \.element.id) { i, entry in
                    Button { onTap(entry.stop) } label: {
                        JourneyStopView(entry: entry, number: i + 1, isNext: markerStopID == entry.id)
                    }
                    .buttonStyle(JourneyStopButtonStyle())
                    .accessibilityIdentifier("journey.stop.\(entry.id)")
                    .position(points[i])
                }

                endFlag.position(end)

                if let id = markerStopID, let i = stops.firstIndex(where: { $0.id == id }) {
                    let side: CGFloat = xFraction(i) < 0.5 ? 1 : -1
                    OwlMarker()
                        .position(x: points[i].x + side * 122, y: points[i].y - 54)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: w, height: height)
            .frame(maxWidth: .infinity)
        }
        .frame(height: height)
    }

    // MARK: Scenery

    /// Soft color band behind each stop so the journey feels like moving through places.
    private func regions(fullWidth: CGFloat, journeyWidth: CGFloat) -> some View {
        ForEach(Array(stops.enumerated()), id: \.element.id) { i, entry in
            LinearGradient(
                colors: [entry.stop.color.opacity(0), entry.stop.color.opacity(0.16), entry.stop.color.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: fullWidth, height: spacing * 1.3)
            .position(x: journeyWidth / 2, y: stopY(i))
            .allowsHitTesting(false)
        }
    }

    private func road(through points: [CGPoint]) -> some View {
        let path = Path { p in
            guard let first = points.first else { return }
            p.move(to: first)
            for (prev, next) in zip(points, points.dropFirst()) {
                let dy = next.y - prev.y
                p.addCurve(to: next,
                           control1: CGPoint(x: prev.x, y: prev.y + dy * 0.55),
                           control2: CGPoint(x: next.x, y: next.y - dy * 0.55))
            }
        }
        return ZStack {
            path.stroke(NubeePalette.surface, style: StrokeStyle(lineWidth: 30, lineCap: .round))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            path.stroke(NubeePalette.inkSoft.opacity(0.28), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 16]))
        }
        .allowsHitTesting(false)
    }

    /// Two of the stop's items floating on the other side of the road.
    private func decorations(for entry: StopProgress, index i: Int, width: CGFloat) -> some View {
        let x = width * (1 - xFraction(i))
        let picks = Array(entry.stop.items.dropFirst(1).prefix(2))
        return ForEach(Array(picks.enumerated()), id: \.element.id) { j, item in
            Text(item.emoji)
                .font(.system(size: 48))
                .grayscale(entry.isLocked ? 1 : 0)
                .opacity(entry.isLocked ? 0.3 : 0.75)
                .rotationEffect(.degrees(j == 0 ? -10 : 8))
                .phaseAnimator([0.0, -7.0]) { content, y in content.offset(y: y) }
                    animation: { _ in .easeInOut(duration: 1.6 + Double(j) * 0.4) }
                // upper one sits above the owl's spot
                .position(x: x + (j == 0 ? 30 : 40), y: stopY(i) + (j == 0 ? -118 : 62))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var startFlag: some View {
        Label("Start", systemImage: "flag.fill")
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(NubeePalette.purple, in: Capsule())
            .accessibilityHidden(true)
    }

    private var endFlag: some View {
        VStack(spacing: 6) {
            Text("🔭")
                .font(.system(size: 28))
            Text("More discoveries coming soon!")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(NubeePalette.inkSoft)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .nubeeSurface(radius: 20, padding: 0)
    }
}

// ======================================================
// MARK: - Stop
// ======================================================

private struct JourneyStopView: View {
    let entry: StopProgress
    let number: Int
    let isNext: Bool

    private let size: CGFloat = 132
    private var stop: JourneyStop { entry.stop }
    private var tint: Color { entry.isLocked ? NubeePalette.slate : stop.color }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if isNext {
                    Circle()
                        .stroke(stop.color, lineWidth: 6)
                        .frame(width: size, height: size)
                        .phaseAnimator([false, true]) { content, on in
                            content.scaleEffect(on ? 1.3 : 1).opacity(on ? 0 : 0.7)
                        } animation: { on in on ? .easeOut(duration: 1.5) : nil }
                }

                Circle()
                    .fill(NubeePalette.surface)
                    .shadow(color: tint.opacity(0.35), radius: 12, y: 6)
                Circle()
                    .strokeBorder(entry.isLocked ? tint.opacity(0.4) : tint, lineWidth: 8)

                Text(stop.emoji)
                    .font(.system(size: size * 0.42))
                    .grayscale(entry.isLocked ? 1 : 0)
                    .opacity(entry.isLocked ? 0.35 : 1)
            }
            .frame(width: size, height: size)
            .overlay(alignment: .topLeading) {
                Text("\(number)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(tint, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
            }
            .overlay(alignment: .topTrailing) {
                if entry.isLocked {
                    badge(symbol: "lock.fill", color: NubeePalette.purple)
                } else if entry.isCompleted {
                    badge(symbol: "checkmark", color: NubeePalette.mint)
                }
            }

            Text(stop.title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(tint, in: Capsule())

            Group {
                if entry.isLocked {
                    Label("Locked", systemImage: "lock.fill")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(NubeePalette.inkSoft)
                } else if entry.isCompleted {
                    StarsRow(earned: entry.bestStars)
                } else {
                    Text("New idea!")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(NubeePalette.inkSoft)
                }
            }
            .frame(height: 20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private func badge(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(color, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))
    }

    private var accessibilityText: String {
        if entry.isLocked { return "Stop \(number), \(stop.title), locked" }
        if entry.isCompleted { return "Stop \(number), \(stop.title), \(entry.bestStars) stars" }
        return "Stop \(number), \(stop.title), play"
    }
}

private struct JourneyStopButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// ======================================================
// MARK: - Owl marker ("you are here")
// ======================================================

private struct OwlMarker: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("Let's explore!")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(NubeePalette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(NubeePalette.surface, in: Capsule())
                .overlay(Capsule().stroke(NubeePalette.stroke))
            Text("🦉")
                .font(.system(size: 56))
        }
        .phaseAnimator([0.0, -8.0]) { content, y in content.offset(y: y) }
            animation: { _ in .easeInOut(duration: 0.7) }
        .accessibilityHidden(true)
    }
}
