//
//  JourneyMapView.swift
//  ShadowMatch
//
//  The home "journey": a winding road with one stop per picture pack, in order.
//  Nothing is gated by order — every unlocked stop can be played any time. The fox
//  marker + pulsing ring just suggest where to go next.
//

import SwiftUI

struct JourneyMapView: View {
    let packs: [ShadowPack]
    /// Stop the fox stands next to (suggested next pack), if any.
    let markerPackID: String?
    let isUnlocked: (ShadowPack) -> Bool
    let price: (ShadowPack) -> String?
    let best: (ShadowPack) -> Int
    let onTap: (ShadowPack) -> Void

    /// ScrollViewReader target for a stop.
    static func scrollID(_ pack: ShadowPack) -> String { "stop.\(pack.id)" }

    private let spacing: CGFloat = 250
    private let startY: CGFloat = 56
    private let firstStopY: CGFloat = 200
    private let maxWidth: CGFloat = 640

    private func stopY(_ i: Int) -> CGFloat { firstStopY + CGFloat(i) * spacing }
    private func xFraction(_ i: Int) -> CGFloat { i.isMultiple(of: 2) ? 0.28 : 0.72 }
    private var endY: CGFloat { stopY(packs.count - 1) + 210 }
    private var height: CGFloat { endY + 90 }

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width, maxWidth)
            let stops = packs.indices.map { CGPoint(x: w * xFraction($0), y: stopY($0)) }
            let start = CGPoint(x: w * 0.5, y: startY)
            let end = CGPoint(x: w * 0.5, y: endY)

            ZStack(alignment: .topLeading) {
                // Scroll targets: `.position`ed views report the whole map as their frame,
                // so each stop gets a 1pt anchor placed with padding instead.
                ForEach(Array(packs.enumerated()), id: \.offset) { i, pack in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .id(Self.scrollID(pack))
                        .padding(.top, stopY(i))
                        .padding(.leading, stops[i].x)
                        .accessibilityHidden(true)
                }

                regions(fullWidth: geo.size.width, journeyWidth: w)
                road(through: [start] + stops + [end])

                startFlag.position(start)

                ForEach(Array(packs.enumerated()), id: \.offset) { i, pack in
                    decorations(for: pack, index: i, width: w)
                }

                ForEach(Array(packs.enumerated()), id: \.offset) { i, pack in
                    Button { onTap(pack) } label: {
                        JourneyStopView(
                            pack: pack,
                            number: i + 1,
                            unlocked: isUnlocked(pack),
                            price: price(pack),
                            best: best(pack),
                            isNext: markerPackID == pack.id
                        )
                    }
                    .buttonStyle(JourneyStopButtonStyle())
                    .accessibilityIdentifier("pack.\(pack.id)")
                    .position(stops[i])
                }

                endFlag.position(end)

                if let id = markerPackID, let i = packs.firstIndex(where: { $0.id == id }) {
                    let side: CGFloat = xFraction(i) < 0.5 ? 1 : -1
                    FoxMarker()
                        .position(x: stops[i].x + side * 122, y: stops[i].y - 54)
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
        ForEach(Array(packs.enumerated()), id: \.offset) { i, pack in
            LinearGradient(
                colors: [pack.color.opacity(0), pack.color.opacity(0.16), pack.color.opacity(0)],
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

    /// A couple of the pack's pictures floating on the other side of the road.
    private func decorations(for pack: ShadowPack, index i: Int, width: CGFloat) -> some View {
        let unlocked = isUnlocked(pack)
        let x = width * (1 - xFraction(i))
        let picks = [pack.items[3], pack.items[5]]
        return ForEach(Array(picks.enumerated()), id: \.element.id) { j, item in
            Group {
                if unlocked {
                    Image(item.id).resizable().scaledToFit().opacity(0.6)
                } else {
                    Image(item.id).resizable().renderingMode(.template).scaledToFit()
                        .foregroundStyle(NubeePalette.ink.opacity(0.14))
                }
            }
            .frame(width: 66, height: 66)
            .rotationEffect(.degrees(j == 0 ? -10 : 8))
            .phaseAnimator([0.0, -7.0]) { content, y in content.offset(y: y) }
                animation: { _ in .easeInOut(duration: 1.6 + Double(j) * 0.4) }
            // upper one sits above the fox marker's spot
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
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(NubeePalette.orange)
            Text("More adventures coming soon!")
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
    let pack: ShadowPack
    let number: Int
    let unlocked: Bool
    let price: String?
    let best: Int
    let isNext: Bool

    private let size: CGFloat = 132

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if isNext {
                    Circle()
                        .stroke(pack.color, lineWidth: 6)
                        .frame(width: size, height: size)
                        .phaseAnimator([false, true]) { content, on in
                            content.scaleEffect(on ? 1.3 : 1).opacity(on ? 0 : 0.7)
                        } animation: { on in on ? .easeOut(duration: 1.5) : nil }
                }

                Circle()
                    .fill(NubeePalette.surface)
                    .shadow(color: pack.color.opacity(0.35), radius: 12, y: 6)
                Circle()
                    .strokeBorder(unlocked ? pack.color : NubeePalette.slate.opacity(0.4), lineWidth: 8)

                art
                    .frame(width: size * 0.66, height: size * 0.66)
            }
            .frame(width: size, height: size)
            .overlay(alignment: .topLeading) {
                Text("\(number)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(unlocked ? pack.color : NubeePalette.slate, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
            }
            .overlay(alignment: .topTrailing) { cornerBadge }

            Text(pack.title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(unlocked ? pack.color : NubeePalette.slate, in: Capsule())

            status
                .frame(height: 20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var art: some View {
        let item = pack.items[0]
        if unlocked {
            Image(item.id).resizable().scaledToFit()
        } else {
            Image(item.id).resizable().renderingMode(.template).scaledToFit()
                .foregroundStyle(NubeePalette.ink.opacity(0.25))
        }
    }

    @ViewBuilder
    private var cornerBadge: some View {
        if !unlocked {
            badge(symbol: "lock.fill", color: NubeePalette.purple)
        } else if best > 0 {
            badge(symbol: "checkmark", color: NubeePalette.mint)
        }
    }

    private func badge(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(color, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))
    }

    @ViewBuilder
    private var status: some View {
        if !unlocked {
            Label(price ?? "Locked", systemImage: "lock.fill")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(NubeePalette.inkSoft)
        } else if best > 0 {
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < best ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(i < best ? NubeePalette.orange : NubeePalette.inkSoft.opacity(0.4))
                }
            }
        } else {
            Text("\(pack.items.count) pictures")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(NubeePalette.inkSoft)
        }
    }

    private var accessibilityText: String {
        if !unlocked { return "Stop \(number), \(pack.title), locked" }
        if best > 0 { return "Stop \(number), \(pack.title), \(best) stars" }
        return "Stop \(number), \(pack.title), play"
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
// MARK: - Fox marker ("you are here")
// ======================================================

private struct FoxMarker: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("Let's go!")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(NubeePalette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(NubeePalette.surface, in: Capsule())
                .overlay(Capsule().stroke(NubeePalette.stroke))
            Image("shadow_fox")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
        }
        .phaseAnimator([0.0, -8.0]) { content, y in content.offset(y: y) }
            animation: { _ in .easeInOut(duration: 0.7) }
        .accessibilityHidden(true)
    }
}
