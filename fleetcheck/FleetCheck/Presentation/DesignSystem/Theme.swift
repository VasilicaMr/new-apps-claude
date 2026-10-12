import SwiftUI

enum Theme {
    static let accent = Color("AccentColor")
    static let positive = Color.green
    static let negative = Color.red
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let cornerRadius: CGFloat = 16

    static func color(for severity: Severity) -> Color {
        switch severity {
        case .info: .blue
        case .warning: .orange
        case .critical: .red
        }
    }

    static func symbol(for severity: Severity) -> String {
        switch severity {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.octagon.fill"
        }
    }
}

/// What a vehicle is doing right now, combining the static status with the live feed.
enum LiveStatus: String {
    case moving = "Moving", stopped = "Stopped", inShop = "In service", offline = "Offline"

    init(vehicle: Vehicle, position: VehiclePosition?) {
        if vehicle.operationalStatus == .inMaintenance {
            self = .inShop
        } else if let position {
            self = position.speedKmh > 3 ? .moving : .stopped
        } else {
            self = .offline
        }
    }

    var color: Color {
        switch self {
        case .moving: .green
        case .stopped: .orange
        case .inShop: .purple
        case .offline: .gray
        }
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: .rect(cornerRadius: Theme.cornerRadius))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}
