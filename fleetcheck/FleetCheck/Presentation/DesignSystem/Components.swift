import MapKit
import SwiftUI

struct KPITile: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = .primary
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let footnote {
                Text(footnote).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    let status: ReminderStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.kind.symbol)
                .foregroundStyle(status.urgency == .ok ? Theme.accent : Theme.color(for: status.urgency))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title).font(.subheadline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if status.urgency > .ok {
                Label(status.urgency == .overdue ? "Overdue" : "Soon", systemImage: Theme.symbol(for: status.urgency))
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Theme.color(for: status.urgency))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        var parts: [String] = []
        if let date = reminder.dueDate, let days = status.daysLeft {
            let when = date.formatted(date: .abbreviated, time: .omitted)
            let text = switch days {
            case ..<0: "Expired \(when)"
            case 0: "Due today"
            case 1: "Due tomorrow"
            default: "\(when) · in \(days) days"
            }
            parts.append(text)
        }
        if let km = status.kmLeft {
            parts.append(km <= 0 ? "Overdue by \(abs(km).kilometers)" : "In \(km.kilometers)")
        }
        return parts.isEmpty ? "No due date set" : parts.joined(separator: " · ")
    }
}

/// A shift's route drawn on a map.
struct RouteMap: View {
    let route: [RoutePoint]

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.zoom, .pan]) {
            if route.count > 1 {
                MapPolyline(coordinates: route.map(\.clLocation))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            if let first = route.first {
                Marker("Start", systemImage: "play.fill", coordinate: first.clLocation).tint(.green)
            }
            if let last = route.last, route.count > 1 {
                Marker("Now", systemImage: "car.fill", coordinate: last.clLocation).tint(Theme.accent)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }
}

extension RoutePoint {
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

/// A number field that edits an optional or plain Double, with the keyboard suited for money.
struct AmountField: View {
    let title: String
    @Binding var value: Double
    var currencyCode: String?

    var body: some View {
        LabeledContent(title) {
            Group {
                if let currencyCode {
                    TextField(title, value: $value, format: .currency(code: currencyCode))
                } else {
                    TextField(title, value: $value, format: .number)
                }
            }
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
        }
    }
}
