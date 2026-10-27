import SwiftUI

// Home is built around one job: getting the driver's earnings in. These are the pieces for it.

/// The big card at the top of Home: upload an Uber/Bolt screenshot.
struct UploadHero: View {
    /// Screenshots already found in Photos and waiting on Home.
    let readyCount: Int
    let upload: () -> Void
    let showGuide: () -> Void
    let addReceipt: () -> Void
    let typeIt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 26, weight: .bold))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.22), in: .rect(cornerRadius: 15, style: .continuous))
                Spacer()
                Button(action: showGuide) {
                    Label("How it works", systemImage: "questionmark.circle.fill")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.22), in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("upload.guide")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Upload your earnings")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                Text("Take a screenshot of a trip, a day or a week in Uber or Bolt. DriveCap reads the money, kilometers and destination for you.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .opacity(0.92)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: upload) {
                Label("Upload screenshot", systemImage: "photo.badge.plus")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color(red: 0.86, green: 0.42, blue: 0.16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white, in: .capsule)
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("upload.screenshot")

            if readyCount > 0 {
                Label("\(readyCount) screenshots already found, ready to add below", systemImage: "sparkles")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
            }

            HStack(spacing: 8) {
                smallAction("Fuel or service receipt", symbol: "doc.text.viewfinder", action: addReceipt)
                smallAction("Type it", symbol: "keyboard", action: typeIt)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gradientCard(Theme.earningsGradient, cornerRadius: 28, shadow: Theme.warning.opacity(0.35))
    }

    private func smallAction(_ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white.opacity(0.22), in: .capsule)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Step by step: where to take the screenshot and what happens next. Opens the first time the driver
/// taps Upload, and any time from "How it works".
struct UploadGuideView: View {
    let onChoose: () -> Void

    @Environment(ScreenshotInbox.self) private var inbox
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var showingPaywall = false

    private let steps: [(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey)] = [
        ("car.side", "Open Uber Driver or Bolt Driver",
         "Go to Earnings for a day or a week, or open a single trip to also get its kilometers and destination."),
        ("camera.viewfinder", "Take a screenshot",
         "Press the side button and volume up together. Take as many as you like."),
        ("photo.badge.plus", "Come back and pick it",
         "Tap Choose screenshot. DriveCap reads fares, tips, bonus, cash, trips, km and destination, on this iPhone."),
        ("checkmark.seal", "Check and save",
         "Fix anything that looks wrong, then Save. Kilometers are added to your shift and your car."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How to upload your earnings")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("It takes about 10 seconds. Nothing is typed and nothing leaves your phone.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.inkSecondary)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(steps.indices, id: \.self) { index in
                            stepRow(number: index + 1, step: steps[index])
                        }
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Screens that work").font(.system(.headline, design: .rounded, weight: .heavy)).foregroundStyle(Theme.ink)
                        HStack(spacing: 8) {
                            Chip(text: "Trip details", tint: Theme.blue)
                            Chip(text: "Today's earnings", tint: Theme.blue)
                            Chip(text: "Weekly summary", tint: Theme.blue)
                        }
                    }

                    autoFindCard
                }
                .padding()
            }
            .fleetBackground()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        dismiss()
                        onChoose()
                    } label: {
                        Label("Choose screenshot", systemImage: "photo.badge.plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CapsuleButtonStyle(tint: Theme.warning))
                    .accessibilityIdentifier("guide.choose")
                    Button("Not now") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private func stepRow(number: Int, step: (symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey)) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(verbatim: "\(number)")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Theme.earningsGradient, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Label(step.title, systemImage: step.symbol)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(step.detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var autoFindCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Even faster: let DriveCap find them", systemImage: "sparkles")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if !pro.isPro { ProBadge() }
            }
            Text("With access to your screenshots, new earnings screenshots show up on Home already read. You just tap Add.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
            if !pro.isPro {
                Button("See DriveCap Pro") { showingPaywall = true }
                    .buttonStyle(CapsuleButtonStyle(tint: Theme.warning, filled: false, compact: true))
            } else if inbox.hasAccess {
                Label("Turned on", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.positive)
            } else {
                Button("Allow access to screenshots") { Task { await inbox.requestAccess() } }
                    .buttonStyle(CapsuleButtonStyle(filled: false, compact: true))
            }
        }
        .card()
        .sheet(isPresented: $showingPaywall) { PaywallSheet() }
    }
}

/// "What do I do first?" for new drivers: three steps that tick themselves off as the data arrives.
struct GettingStartedCard: View {
    let hasEarnings: Bool
    let hasCosts: Bool
    let autoFindOn: Bool
    var autoFindNeedsPro = false
    let upload: () -> Void
    let addCost: () -> Void
    let allowAutoFind: () -> Void
    let hide: () -> Void

    private var doneCount: Int { [hasEarnings, hasCosts, autoFindOn].filter { $0 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Get started", subtitle: "\(doneCount) of 3 done. This is all DriveCap needs.")
                Button("Hide", systemImage: "xmark", action: hide)
                    .labelStyle(.iconOnly)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(width: 28, height: 28)
                    .background(Theme.wash, in: .circle)
                    .buttonStyle(.borderless)
            }
            ProgressView(value: Double(doneCount), total: 3).tint(Theme.positive)

            step(1, "Upload your first earnings", "A screenshot from Uber or Bolt: one trip, a day or a week.",
                 done: hasEarnings, action: "Upload", perform: upload)
            step(2, "Add a cost", "Photograph a fuel receipt, or type “fuel $40”. Costs show your real profit.",
                 done: hasCosts, action: "Add", perform: addCost)
            step(3, "Let DriveCap find screenshots",
                 autoFindNeedsPro ? "New earnings screenshots appear here by themselves. Part of Pro." : "New earnings screenshots appear here by themselves. Optional.",
                 done: autoFindOn, action: autoFindNeedsPro ? "See Pro" : "Allow", perform: allowAutoFind)
        }
        .card()
    }

    private func step(_ number: Int, _ title: LocalizedStringKey, _ detail: LocalizedStringKey, done: Bool, action: LocalizedStringKey,
                      perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(done ? Theme.positive : Theme.wash)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                } else {
                    Text(verbatim: "\(number)").font(.system(.subheadline, design: .rounded, weight: .heavy)).foregroundStyle(Theme.blue)
                }
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .strikethrough(done, color: Theme.inkSecondary)
                Text(detail).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            if !done {
                Button(action, action: perform)
                    .buttonStyle(CapsuleButtonStyle(tint: number == 1 ? Theme.warning : Theme.blue, filled: number == 1, compact: true))
            }
        }
    }
}

/// This week's money in one glance: what's left after costs, and where it came from.
struct WeekMoneyCard: View {
    let stats: PeriodStats
    let openStats: () -> Void
    @Environment(\.money) private var money

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "This week", subtitle: "\(stats.interval.start.formatted(.dateTime.day().month())) – today")
                Button(action: openStats) {
                    HStack(spacing: 4) {
                        Text("Details")
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                }
                .buttonStyle(CapsuleButtonStyle(filled: false, compact: true))
            }
            if stats.earnings == 0 && stats.expenses == 0 {
                Text("Nothing yet. Upload your first earnings screenshot and you'll see what you really make here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("You keep")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSecondary)
                    Text(money.string(stats.net))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.color(forNet: stats.net))
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("\(money.string(stats.earnings)) earned − \(money.string(stats.expenses)) costs")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.inkSecondary)
                    if stats.cash > 0 {
                        Label("\(money.string(stats.cash)) of it in cash · \(money.string(max(0, stats.earnings - stats.cash))) paid by the apps",
                              systemImage: "banknote")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.positive)
                            .padding(.top, 2)
                    }
                }
                HStack(spacing: 0) {
                    figure("Per hour", stats.netPerHour.map { money.string($0) } ?? "—")
                    Divider().frame(height: 32)
                    figure("Per km", stats.netPerKm.map { money.string($0, decimals: true) } ?? "—")
                    Divider().frame(height: 32)
                    figure("Kilometers", stats.km.kilometers)
                }
                .padding(.vertical, 10)
                .background(Theme.wash, in: .rect(cornerRadius: 14, style: .continuous))
            }
        }
        .card()
    }

    private func figure(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
