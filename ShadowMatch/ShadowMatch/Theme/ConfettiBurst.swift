//
//  ConfettiBurst.swift
//  ShadowMatch (from scrambledUI/Kid/KidMainScreenView.swift)
//

import SwiftUI

struct ConfettiBurst: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let color: Color
        let dx: CGFloat
        let dy: CGFloat
        let rotation: Double
        let size: CGFloat
    }

    @State private var fired = false
    @State private var pieces: [Piece] = (0..<36).map { _ in
        let angle = Double.random(in: 0..<(2 * .pi))
        let dist = CGFloat.random(in: 120...320)
        return Piece(
            color: NubeePalette.accents.randomElement() ?? NubeePalette.sun,
            dx: cos(angle) * dist,
            dy: sin(angle) * dist - 60,
            rotation: Double.random(in: -360...360),
            size: CGFloat.random(in: 8...14)
        )
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                RoundedRectangle(cornerRadius: 3)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 0.6)
                    .rotationEffect(.degrees(fired ? p.rotation : 0))
                    .offset(x: fired ? p.dx : 0, y: fired ? p.dy + 80 : 0)
                    .opacity(fired ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4)) { fired = true }
        }
    }
}
