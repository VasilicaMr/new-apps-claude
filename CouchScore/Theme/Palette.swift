import SwiftUI

enum PlayerPalette {
    static let colors: [Color] = [
        Color(red: 0.93, green: 0.30, blue: 0.33), // red
        Color(red: 0.20, green: 0.55, blue: 0.98), // blue
        Color(red: 0.22, green: 0.78, blue: 0.45), // green
        Color(red: 0.99, green: 0.72, blue: 0.16), // yellow
        Color(red: 0.66, green: 0.38, blue: 0.96), // purple
        Color(red: 1.00, green: 0.52, blue: 0.20), // orange
        Color(red: 0.18, green: 0.80, blue: 0.84), // teal
        Color(red: 0.96, green: 0.40, blue: 0.70), // pink
    ]

    static func color(_ index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}

extension GameDefinition {
    var tint: Color {
        switch category {
        case .card: Color(red: 0.80, green: 0.20, blue: 0.27)
        case .board: Color(red: 0.16, green: 0.42, blue: 0.85)
        case .party: Color(red: 0.55, green: 0.27, blue: 0.85)
        case .tableAndYard: Color(red: 0.13, green: 0.60, blue: 0.38)
        case .video: Color(red: 0.92, green: 0.45, blue: 0.13)
        case nil: Color(red: 0.10, green: 0.58, blue: 0.64)
        }
    }
}

extension ShapeStyle where Self == LinearGradient {
    static var appBackground: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.07, blue: 0.13), Color(red: 0.12, green: 0.08, blue: 0.20)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
