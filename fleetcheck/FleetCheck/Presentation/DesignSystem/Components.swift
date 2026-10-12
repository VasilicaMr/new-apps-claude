import SwiftUI

struct KPITile: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = Theme.accent
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
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let footnote {
                Text(footnote).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: .capsule)
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

struct InsightRow: View {
    let insight: Insight
    let money: MoneyFormatter

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.category.symbol)
                .font(.title3)
                .foregroundStyle(Theme.color(for: insight.severity))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(insight.title).font(.subheadline.weight(.semibold))
                    Spacer(minLength: 4)
                    if let impact = insight.monthlyImpact, impact > 0 {
                        Text("\(money.string(impact))/mo").font(.caption.weight(.semibold)).foregroundStyle(Theme.negative)
                    }
                }
                Text(insight.detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DueItemRow: View {
    let item: DueItem
    let plate: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.symbol)
                .foregroundStyle(Theme.color(for: item.severity))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(plate.map { "\($0) · \(item.kind.title)" } ?? item.kind.title).font(.subheadline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if item.severity >= .warning {
                Image(systemName: Theme.symbol(for: item.severity)).foregroundStyle(Theme.color(for: item.severity))
            }
        }
    }

    private var detail: String {
        let date = item.dueDate.formatted(date: .abbreviated, time: .omitted)
        if let km = item.kmRemaining {
            return km <= 0 ? "Overdue by \(abs(km).kilometers)" : "In \(km.kilometers) · around \(date)"
        }
        return item.dueDate < .now ? "Expired \(date)" : "Due \(date) (\(item.dueDate.formatted(.relative(presentation: .named))))"
    }
}

struct PeriodPicker: View {
    @Binding var period: AnalysisPeriod

    var body: some View {
        Picker("Period", selection: $period) {
            ForEach(AnalysisPeriod.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}

struct LoadingStateView<Content: View>: View {
    let state: FleetStore.State
    let retry: () async -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView("Loading fleet data…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load the fleet", systemImage: "exclamationmark.icloud")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await retry() } }.buttonStyle(.borderedProminent)
            }
        case .loaded:
            content()
        }
    }
}
