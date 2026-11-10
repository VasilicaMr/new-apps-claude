//
//  StopTheme+Color.swift
//  LittlePhysicsTrail
//
//  Domain keeps colors semantic; this is the only place they become real colors.
//

import SwiftUI
import TrailDomain

extension StopTheme {
    var color: Color {
        switch self {
        case .sky: NubeePalette.sky
        case .coral: NubeePalette.coral
        case .orange: NubeePalette.orange
        case .sun: Color(red: 0.95, green: 0.68, blue: 0.05) // NubeePalette.sun is too pale behind white text
        case .pink: NubeePalette.pink
        case .teal: NubeePalette.teal
        case .mint: NubeePalette.mint
        case .purple: NubeePalette.purple
        }
    }
}

extension JourneyStop {
    var color: Color { theme.color }
}
