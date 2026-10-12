import SwiftUI

/// First-launch walkthrough. Can be replayed from Settings.
struct TutorialView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [TutorialPage] = [
        TutorialPage(symbol: "steeringwheel", color: .blue, title: "Your driving, your numbers",
                     body: "FleetCheck is a logbook for ride-sharing drivers: kilometers, hours, earnings and costs, so you know what you really make per hour."),
        TutorialPage(symbol: "play.circle.fill", color: .green, title: "Start a shift",
                     body: "Tap Start shift when you go online. GPS counts your kilometers and driving time, even with the phone locked. Allow location \"While Using the App\"."),
        TutorialPage(symbol: "banknote.fill", color: .orange, title: "Add what you earned",
                     body: "When you end the shift, copy your earnings from Uber, Bolt or any other app. Log fuel, washes and repairs as they happen; add a photo of the receipt."),
        TutorialPage(symbol: "chart.bar.fill", color: .indigo, title: "See your real profit",
                     body: "Stats show net per hour and per kilometer for any day, week, month or year, which app pays best and where your money goes."),
        TutorialPage(symbol: "bell.badge.fill", color: .red, title: "Never miss a deadline",
                     body: "Add your ITP, RCA, vignette and oil change. FleetCheck reminds you 30, 7 and 1 days before."),
        TutorialPage(symbol: "lock.shield.fill", color: .teal, title: "Your data stays yours",
                     body: "Everything is stored only on this iPhone. No account, no company sees it. Export it to a spreadsheet whenever you want."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish).foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index]).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom)
            .accessibilityIdentifier("tutorial.next")
        }
        .padding(.top)
    }

    private func pageView(_ page: TutorialPage) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: page.symbol)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 150, height: 150)
                .background(page.color.gradient, in: .rect(cornerRadius: 36))
                .shadow(color: page.color.opacity(0.4), radius: 16, y: 8)
            Text(page.title).font(.title.bold()).multilineTextAlignment(.center)
            Text(page.body).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 28)
            Spacer()
            Spacer()
        }
    }
}

private struct TutorialPage {
    let symbol: String
    let color: Color
    let title: String
    let body: String
}
