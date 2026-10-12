# FleetCheck

Fleet management for small businesses (~10 vehicles): live location, money per vehicle,
repairs, market value by mileage, paperwork deadlines and plain-language recommendations.
Runs entirely on mock data (local JSON) until a real backend is plugged in.

## Run it

```bash
xcodegen generate            # project.yml → FleetCheck.xcodeproj
open FleetCheck.xcodeproj    # run the FleetCheck scheme (iOS 18+); ⌘U runs the tests
```

Regenerate mock data / icon (deterministic, seeded):

```bash
python3 Scripts/generate_mock_data.py --as-of 2026-10-11   # dates are relative to --as-of
python3 Scripts/generate_icon.py
```

Debug launch arguments: `-hasSeenTutorial YES` skips onboarding, `-initialTab live|vehicles|insights|settings`.

## Architecture

```
FleetCheck/
  App/            FleetCheckApp, AppDependencies (composition root: mock vs real)
  Core/
    Networking/   Endpoint (every API call), APIClient, MockAPIClient, URLSessionAPIClient
    Location/     DeviceLocationTracker (battery-friendly CoreLocation wrapper)
  Domain/         Framework-free, unit-tested
    Entities/     Vehicle, Driver, Telemetry, DailyMetric, Trip, Maintenance, Expense, ...
    Repositories/ FleetRepository, LivePositionStreaming (protocols)
    Services/     ValuationCalculator, FinancialAnalyzer, MaintenancePlanner,
                  FleetAnalyzer, InsightsEngine, LocationChangeFilter
  Data/           DefaultFleetRepository, SimulatedPositionStream
  Presentation/   SwiftUI + @Observable stores (Dashboard, Live, Vehicles, Insights, Settings, Tutorial)
  Resources/MockData/   one JSON file per endpoint
```

Views never touch JSON or the network: View → Store → Repository → APIClient.
Going live = change one line in `AppDependencies` (`MockAPIClient()` → `URLSessionAPIClient(baseURL:)`).

## API surface (mock files)

| Endpoint | Mock file | What it feeds |
|---|---|---|
| `GET /v1/company` | `company.json` | currency, depot, tracking policy, `dataAsOf` |
| `GET /v1/vehicles` | `vehicles.json` | 10 vehicles, purchase price, odometer, service interval, document expiries |
| `GET /v1/drivers` | `drivers.json` | drivers, license expiry, assignment |
| `GET /v1/telemetry/latest` | `telemetry_latest.json` | position, speed, fuel %, 12 V battery, engine temp, OBD-II fault codes |
| `GET /v1/metrics/daily?from&to` | `daily_metrics.json` | per vehicle per day: km, revenue, fuel, idle, harsh events (180 days) |
| `GET /v1/trips?from&to` | `trips.json` | last 7 days of trips with revenue |
| `GET /v1/maintenance/records` | `maintenance_records.json` | full service & repair history with costs |
| `GET /v1/expenses?from&to` | `expenses.json` | wages, insurance, road tax, leasing, parking, tolls, fines |
| `GET /v1/valuation/models` | `valuation_models.json` | depreciation parameters per segment |
| `GET /v1/alerts` | `alerts.json` | telematics alerts |
| `GET /v1/geofences` | `geofences.json` | depot, client hubs, restricted zone |
| `GET /v1/simulation/routes` | `live_routes.json` | mock-only: replayed routes for the live map |
| `POST /v1/location-events` | `location_event_ack.json` | batched filtered positions upload |

The mock data has stories built in so the insights have something to find: an old Transit eating
76% of its value in repairs, an underused leased Kangoo, an Octavia burning 22% too much diesel
(fuel theft?), a harsh driver, a Caddy idling a lot, expiring insurance/ITP/license, a car in the shop.

## How the analysis works

- **Profit per vehicle** = revenue − (fuel/energy + repairs + wages + insurance + leasing + fees + **depreciation**).
  Recurring payments are amortized over the days they cover, so a 7-day report isn't distorted by a salary or insurance payment.
- **Market value** = declining-balance by age (segment rates) × mileage factor (±% per 10k km vs. normal), with a residual floor.
  The chart projects value against odometer at the car's current km/year pace — use it to pick the moment to sell.
- **Insights** (`InsightsEngine`, thresholds in one place): replace (repairs > 25% of value/yr), losing money,
  underused (< 55% of days), fuel over baseline (> 12%), harsh driving, idling (> 20%), fault codes, due services/paperwork.
- **50 m tracking** (`LocationChangeFilter`): a point is stored only after ≥ 50 m of movement from the last *stored*
  point, plus a heartbeat every 5 min while parked. On the phone, `DeviceLocationTracker` combines that with
  `distanceFilter = 50`, 100 m accuracy (Wi-Fi/cell instead of constant GPS), auto-pause, and batched uploads.
  "Ultra low power" switches to significant-change monitoring (~500 m).

## Tutorial — using the app

1. **First launch** shows a 6-page walkthrough (replay it from *Settings → Show tutorial again*).
2. **Dashboard** — pick 7D/30D/90D/180D. Revenue, costs, net profit, fleet value, vehicles on the road,
   utilization; revenue-vs-costs per month; the top items needing attention; profit per vehicle; upcoming deadlines.
3. **Live** — every vehicle on the map (green moving, orange stopped, purple in service), geofences as circles.
   The panel shows how many GPS samples arrived vs. how many points were actually stored. Tap a car to see its
   50 m breadcrumb trail; the list icon opens the raw location event log. Pause/resume the feed top-left.
4. **Vehicles** — search by plate/model/driver, sort by profit/value/distance. A vehicle page shows live
   readings and fault codes, recommendations, P&L with cost per km, market value curve, usage & driving score,
   due items and full repair history, recent trips.
5. **Insights** — all recommendations ranked by severity with the money at stake per month, a cost
   breakdown, cost-vs-revenue per km per vehicle, and driver ranking.
6. **Settings** — tracking distance (25–300 m), ultra low power, and **Driver mode**, which turns this iPhone
   into the tracker for a vehicle (allow "Always" location for background tracking).
