//
//  StarsRow.swift
//  LittlePhysicsTrail
//

import SwiftUI
import TrailDomain

/// 3 stars, filled up to `earned`.
struct StarsRow: View {
    let earned: Int
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: size * 0.15) {
            ForEach(0..<StarRating.maximum, id: \.self) { i in
                Image(systemName: i < earned ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < earned ? NubeePalette.orange : NubeePalette.inkSoft.opacity(0.4))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(earned) of \(StarRating.maximum) stars")
    }
}
