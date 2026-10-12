# FleetCheck — driver logbook

A personal app for ride-sharing drivers (Uber, Bolt, FREENOW…): track shifts with GPS, log earnings
and expenses, see your real net per hour and per km, and get reminders for ITP, RCA, vignette and oil changes.
All data stays on the iPhone (SwiftData), with no account and no backend.

## Run it

```bash
xcodegen generate            # project.yml → FleetCheck.xcodeproj
open FleetCheck.xcodeproj    # run the FleetCheck scheme (iOS 26+); ⌘U runs the tests
```

Debug launch arguments:
- `-hasSeenTutorial YES` skips onboarding
- `-initialTab shift|stats|diary|car|settings`
- `-seedSampleData` replaces the local database with 6 weeks of sample data (Bucharest)
- `-startShift` starts a shift at launch. Combine it with `xcrun simctl location <device> start …` to simulate driving.
- `-debugScanImage /path/to/screenshot.png` opens the earnings form and scans that image (no photo picker needed)

## Phase 1 features

| Feature | Where |
|---|---|
| Start/End shift, GPS km, driving vs waiting time, route map | `ShiftView`, `ShiftStore`, `ShiftLocationTracker`, `DistanceAccumulator` |
| Earnings per app after each shift (fares, tips, bonus, trips) | `EarningForm` (opens automatically when a shift ends) |
| Expense diary with receipt photo, liters, odometer | `ExpenseForm`, `DiaryView` |
| Stats by day/week/month/year: net, net/h, net/km, cost/km, by app, by category | `StatsView`, `StatsCalculator` |
| Reminders by date and/or km, with notifications 30/7/1 days before | `CarView`, `ReminderPlanner`, `ReminderNotifier` |
| CSV export (shifts, earnings, expenses) | `ExportView`, `CSVExporter` |
| Siri: "Start my shift / End my shift / How much did I make today in FleetCheck" | `Intents/ShiftIntents.swift` |
| Live Activity (Lock Screen + Dynamic Island) with an End button | `FleetCheckWidgets`, `Shared/ShiftActivity.swift` |

## Phase 2: earnings from screenshots (Apple Intelligence)

In the earnings form, tap **Read from screenshot** (or use Diary → + → *Earnings from screenshot*) and pick a
screenshot of the Uber/Bolt/FREENOW earnings screen. Everything runs on the iPhone:

1. **Vision** (`ScreenshotTextReader`) reads the text with its position. Romanian and English are supported.
2. `EarningsTextParser.lines` joins each label with the amount on the same row ("Tips … 25,50 lei").
3. **Foundation Models** (`AppleIntelligenceEarningsExtractor`) fills a `@Generable` struct:
   app, scope (trip/day/week), date, total, fares, tips, bonus, trips. Greedy sampling makes the output repeatable.
4. **Fallback:** if Apple Intelligence isn't available (iPhone 15 Pro or newer required, must be turned on, model must be downloaded)
   or fails, keyword matching (`EarningsTextParser.parse`) reads the same fields.
   It handles English/Romanian labels, "1.234,56 lei" vs "RON 1,234.56", and ș/ş/s.
5. `ScreenshotEarnings.normalized()` makes fares + tips + bonus add up to the headline total.

The keyword fallback skips amounts that aren't the driver's (customer price, gross, commission, service fee, cash collected,
balance, points, distance, online time) and prefers "net"/"your earnings". It recognises single-trip screens and date-range
weekly summaries.

**Misread reports:** "Numbers wrong? Save a report" in the form stores the recognised text (never the image), what was
detected and, after Save, what the driver corrected. Settings → Apple Intelligence → Misread reports shows and shares them.
This is how real Uber/Bolt layouts get collected to tune the parser.

The form shows which method was used, warns when the screenshot is a weekly summary, and always asks the driver to check
the numbers before saving. Settings → Apple Intelligence shows the status and can switch it off.
Test fixtures (lookalike screens, not real Uber/Bolt screenshots) come from `python3 Scripts/generate_test_screenshots.py`:
Uber day (EN, dark), Uber trip details (EN), Uber week (RO, dark), Bolt week (RO), Bolt gross/net day (EN).

## Architecture

```
FleetCheck/
  App/            FleetCheckApp (ModelContainer, ShiftStore, App Intents wiring)
  Core/           ShiftLocationTracker (CLLocationUpdate + CLBackgroundActivitySession),
                  ReminderNotifier, Formatters
  Domain/         Framework-free, unit-tested: DistanceAccumulator, StatsCalculator,
                  ReminderPlanner, CSVExporter, categories
  Data/           SwiftData models (Shift, Earning, Expense, Reminder, Car), SampleData (DEBUG)
  Intents/        Siri / Shortcuts
  Presentation/   SwiftUI: Shift, Stats, Diary, Car, Settings, Tutorial
Shared/           Live Activity attributes + EndShiftIntent (app + widget)
FleetCheckWidgets/  Live Activity UI
```

## How the numbers work

- **Kilometers.** A GPS fix counts only if it's accurate to 50 m or better and at least 25 m from the last *stored* point.
  Jumps faster than 200 km/h are dropped, so jitter while parked adds 0 km.
  Segments slower than 5 km/h count as *waiting* time.
- **Background tracking** needs only "While Using" permission, thanks to `CLBackgroundActivitySession`
  (the blue location pill shows while tracking). The route is saved every 10 points.
  If iOS kills the app mid-shift, the shift resumes on the next launch.
- **A shift belongs to the day it started.** A Friday-night shift that ends at 3 AM counts as Friday.
- **Costs that cover several months** (insurance, vignette) are spread evenly per day,
  and stats stop at today so future days aren't charged.
- **Net** = earnings (fares + tips + bonus, after the platform's commission) − expenses.

## Next (Phase 2+)

Share-sheet extension (send a screenshot straight from Photos), Uber data-export import, car wear and depreciation per km,
driving score, weather and traffic per shift, best hours/areas heatmap, weekly AI coach.
