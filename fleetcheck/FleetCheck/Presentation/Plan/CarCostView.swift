import SwiftData
import SwiftUI

/// The true cost of the car per km: fuel from the receipts plus leasing, fixed costs, losing value,
/// tyres and service spread over the km. The result is the minimum fare per km worth accepting.
struct CarCostView: View {
    let plan: MoneyPlan
    @Environment(\.modelContext) private var context

    var body: some View {
        CarCostForm(plan: plan, car: context.car())
    }
}

private struct CarCostForm: View {
    let plan: MoneyPlan
    @Bindable var car: Car
    @Environment(\.money) private var money

    private var cost: CarCostBreakdown { plan.carCost }
    private var currency: String { money.currencyCode }

    var body: some View {
        Form {
            Section {
                resultCard
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            Section {
                ForEach(cost.lines.filter { $0.perKm > 0 }) { line in
                    HStack(spacing: 12) {
                        IconBadge(symbol: line.kind.symbol, tint: PlanColors.car, size: 32)
                        Text(line.kind.title).font(.body.weight(.semibold))
                        Spacer()
                        Text(verbatim: "\(line.perKm.decimal(2)) \(currency)")
                            .font(.system(.body, design: .rounded, weight: .heavy))
                            .monospacedDigit()
                    }
                }
                if cost.costPerKm == 0 {
                    Text("Fill in the costs below and the breakdown shows here.").foregroundStyle(Theme.inkSecondary)
                }
            } header: {
                Text("Where each km goes")
            } footer: {
                if cost.weeklyKm <= 0 {
                    Text("Add your kilometers per week below so fixed costs can be spread over them.")
                } else if cost.kmFromTrips {
                    Text("Fixed costs are spread over \(cost.weeklyKm.kilometers) a week (from your trips). That's \(money.string(cost.weeklyCost)) a week for the car.")
                } else {
                    Text("Fixed costs are spread over \(cost.weeklyKm.kilometers) a week (your estimate). That's \(money.string(cost.weeklyCost)) a week for the car.")
                }
            }

            Section {
                AmountField(title: "Amount", value: $car.rentAmount)
                Picker("Paid", selection: $car.rentPerMonth) {
                    Text("Per week").tag(false)
                    Text("Per month").tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Leasing or rent")
            } footer: {
                Text("Your leasing rate, or the weekly rent you pay a fleet for the car. Leave 0 if the car is yours.")
            }

            Section {
                AmountField(title: "Per month", value: $car.otherMonthlyCosts)
            } header: {
                Text("Insurance, phone, fees")
            } footer: {
                Text("Costs you pay whether you drive or not: CASCO, phone plan, fleet or licence fees.")
            }

            Section {
                AmountField(title: "Car is worth now", value: $car.carValue)
                AmountField(title: "Worth when you sell", value: $car.resaleValue)
                AmountField(title: "Km until you sell", value: $car.kmUntilSale)
            } header: {
                Text("Car losing value")
            } footer: {
                Text("Every km makes the car worth a little less. A rough guess is fine, e.g. worth 60,000 now, 30,000 after another 150,000 km.")
            }

            Section {
                AmountField(title: "Set of tyres", value: $car.tyreSetCost)
                AmountField(title: "They last (km)", value: $car.tyreLifeKm)
            } header: {
                Text("Tyres")
            }

            Section {
                AmountField(title: "Each service", value: $car.serviceCost)
                AmountField(title: "Every (km)", value: $car.serviceIntervalKm)
            } header: {
                Text("Service")
            } footer: {
                Text("Oil, filters, brake pads: what a normal service costs on average.")
            }

            Section {
                if cost.fuelFromReceipts {
                    LabeledContent("From your receipts", value: "\(cost.perKm(.fuel).decimal(2)) \(currency) / km")
                } else {
                    AmountField(title: "Liters per 100 km", value: $car.litersPer100Km)
                    AmountField(title: "Price per liter", value: $car.fuelPrice)
                }
            } header: {
                Text("Fuel")
            } footer: {
                Text(cost.fuelFromReceipts
                     ? "Worked out from the fuel and charging receipts and the km of the last 4 weeks."
                     : "Used until you add fuel receipts; then the real figure takes over.")
            }

            Section {
                if cost.kmFromTrips {
                    LabeledContent("Per week, from your trips", value: cost.weeklyKm.kilometers)
                } else {
                    AmountField(title: "Km per week", value: $car.expectedWeeklyKm)
                }
            } header: {
                Text("Kilometers")
            }
        }
        .fleetBackground()
        .navigationTitle("Car cost")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Minimum fare")
                .font(.subheadline.weight(.bold))
                .opacity(0.9)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(cost.costPerKm.decimal(2))
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("\(currency) per km").font(.headline.weight(.bold))
            }
            Text(cost.isSetUp
                 ? "Below \(cost.costPerKm.decimal(2)) \(currency) per km you lose money."
                 : "Only fuel so far. Fill in the costs below to see what the car really costs.")
                .font(.body.weight(.semibold))
            if let earned = cost.earningsPerKm, let profit = cost.profitPerKm, cost.isSetUp {
                Divider().overlay(.white.opacity(0.4))
                Text(profit >= 0
                     ? "You make \(earned.decimal(2)) \(currency) per km, so \(profit.decimal(2)) \(currency) of each km is real profit."
                     : "You make \(earned.decimal(2)) \(currency) per km, \(abs(profit).decimal(2)) \(currency) less than the car costs.")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gradientCard((cost.profitPerKm ?? 0) < 0 && cost.isSetUp ? Theme.lossGradient : Theme.carGradient, cornerRadius: 26)
    }
}
