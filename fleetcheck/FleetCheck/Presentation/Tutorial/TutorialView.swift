import SwiftUI

/// First-launch walkthrough. Can be replayed from Settings.
struct TutorialView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [TutorialPage] = [
        TutorialPage(symbol: "car.2.fill", color: .blue, title: "Your whole fleet, one screen",
                     body: "FleetCheck brings live location, money, repairs and paperwork for every vehicle into a single app — so you always know which cars earn and which ones cost you."),
        TutorialPage(symbol: "gauge.with.dots.needle.67percent", color: .indigo, title: "Dashboard",
                     body: "Revenue, costs, net profit and fleet value at a glance. Switch between 7, 30, 90 and 180 days. Costs include fuel, repairs, insurance, leasing and the value your cars lose every month."),
        TutorialPage(symbol: "map.fill", color: .green, title: "Live map",
                     body: "See where every vehicle is right now. A point is stored only when a car moves about 50 m — accurate enough to follow a route, light enough to save battery and data. Tap a car to see its trail."),
        TutorialPage(symbol: "eurosign.arrow.trianglehead.counterclockwise.rotate.90", color: .orange, title: "Every vehicle's story",
                     body: "Open a vehicle to see profit per km, its market value by mileage, fuel consumption against the baseline, driving score, full repair history and upcoming services."),
        TutorialPage(symbol: "lightbulb.max.fill", color: .yellow, title: "Insights that save money",
                     body: "FleetCheck flags cars to replace, vehicles that sit idle, suspicious fuel use, risky driving and expiring insurance or inspections — with an estimate of what each issue costs per month."),
        TutorialPage(symbol: "iphone.radiowaves.left.and.right", color: .teal, title: "No tracker? Use a phone",
                     body: "Turn on Driver mode in Settings and a driver's iPhone becomes the tracker. Pick \"Always\" for location so it keeps working in the background."),
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
