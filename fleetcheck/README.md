# DriveCap — driver logbook (project: FleetCheck)

A personal app for ride-sharing drivers (Uber, Bolt, FREENOW…): time your shifts, read earnings, kilometers and destinations from Uber/Bolt screenshots, log
and expenses, see your real net per hour and per km, and get reminders for ITP, RCA, vignette and oil changes.
All data stays on the iPhone (SwiftData), with no account and no backend.

## Run it

```bash
xcodegen generate            # project.yml → FleetCheck.xcodeproj
open FleetCheck.xcodeproj    # run the FleetCheck scheme (iOS 26+); ⌘U runs the tests
```

Debug launch arguments:
- `-hasSeenTutorial YES` skips onboarding
- `-initialTab home|stats|diary|car|ask`
- `-forcePro YES|NO` shows the Pro or free version; `-hasSeenTutorial NO -tutorialPage 6` opens the tutorial on its paywall page
- `-seedSampleData` replaces the local database with 6 weeks of sample data (Bucharest)
- `-startShift` starts a shift at launch.
- `-debugSettings YES` opens Settings at launch
- `-debugScanImage /path/to/screenshot.png` opens the earnings form and scans that image (no photo picker needed)
- `-askQuestion "how much did I make this week?"` opens Ask and sends the question
- `-debugPlanTool carCost|goal|bestTimes` opens an Earn smarter screen; `-weeklyGoal 2500` sets a goal
- `-inboxImages "/a.png,/b.png"` puts images in the Home inbox as if found in Photos (the simulator can't grant Photos access from the command line)

## The main flow (AI-first)

Tabs: **Home · Stats · Diary · Car · Ask** (Ask is the sparkles button). Settings is the gear on Home.

**Home** puts everything in one place:
- An **Ask or add anything** bar
- The **shift** card: start, or the live map and timers
- **Needs you:** earnings screenshots found in Photos (one-tap **Add** or **Review**), shifts without earnings, papers that are due, and the Photos permission prompt
- **Your brief:** facts from `InsightComposer`, written up by Apple Intelligence
- **Quick actions:** scan earnings, scan receipt, say it, my week
- Today's numbers and recent shifts

**Earn smarter** (Home, below *This week*): three columns side by side, each with one big number and a plain sentence;
tap one for the full screen (`Presentation/Plan`, math in `Domain/Services/MoneyPlanner.swift`, fed by `Data/MoneyPlan.swift`):
- **Minimum fare** (`CarCostView`): fuel from the receipts of the last 4 weeks, plus leasing/rent, insurance and fees,
  the car losing value, tyres and service, all spread per km → "Below 0,75 RON per km you lose money", and the real profit per km.
- **Weekly goal** (`GoalView`): what you want to keep after costs; shows what's left and the hours it takes at the best
  weekday still to come ("About 11 h more at your Saturday rate"), plus the week day by day.
- **Best time** (`BestTimesView`): earnings per hour for each weekday × morning/afternoon/evening/night over 8 weeks
  (night belongs to the evening it starts), top 3 and slowest times, and Uber vs Bolt per hour and per km.
  Slots need 3 h of driving before they're ranked; an app is named best only when it pays at least 5% more.

**Ask** (`Assistant`, `AssistantView`):
- Free text goes to Apple Intelligence with tools over the driver's data, streamed as it's written:
  `getStats`, `getInsights`, `getReminders`, `getRecentEntries`, `addExpense`, `addEarnings`.
  The model never invents numbers; `DriverData` computes them.
- Things added from chat show as cards with **Undo**.
- Chips ("This week vs last week", "What's due?"…) answer instantly from the data, with no model call.
- Without Apple Intelligence, `AssistantCommandParser` and `QuickEntryParser` understand the common questions
  and shorthand ("fuel 250 lei 34 L", "uber 420 tips 30") in English and Romanian.
- "What can I ask?" lists examples. Siri: "Ask DriveCap" (`AskFleetCheckIntent`).

**Automatic:**
- Ending a shift opens the screenshot picker directly.
- `ScreenshotInbox` reads up to 8 screenshots from the last 3 days when the app opens.
  It keeps only earnings screens and links each one to its shift (`ShiftMatcher`).
- Receipts: photograph one and `ReceiptScanner` fills category, total, liters, station and date
  (Apple Intelligence, falling back to `ReceiptTextParser`).

**Tutorial** (6 pages) explains the flow and switches on screenshots and notifications as it goes. Replay it from Settings.

## DriveCap Pro (StoreKit 2)

`Core/Store/ProStore.swift` holds the products and entitlements; `Presentation/Paywall/PaywallView.swift` is the paywall,
shown as a sheet from locked features and as the last tutorial page (buy there or "Continue with the free version").

| Product ID | Type | Test price |
|---|---|---|
| `com.adaptiveservices.drivecap.pro.yearly` | auto-renewing, 1 year, 7-day free trial | 149,99 lei |
| `com.adaptiveservices.drivecap.pro.monthly` | auto-renewing, 1 month, 7-day free trial | 24,99 lei |
| `com.adaptiveservices.drivecap.pro.lifetime` | non-consumable | 399,99 lei |

- **Free:** shifts, manual entries, stats, reminders, receipts, the assistant, 10 screenshot reads a month (`ScreenshotAllowance`).
- **Pro:** unlimited screenshot reading, the automatic screenshot inbox, Earn smarter (minimum fare, weekly goal, best times), CSV export.

`FleetCheck.storekit` (Romanian storefront) is used when running from Xcode and by `ProStoreTests`.
The real products and prices are created in App Store Connect with the same IDs, in one subscription group "DriveCap Pro".

## Phase 1 features

| Feature | Where |
|---|---|
| Start/End shift (a clock, no GPS) | `ShiftCard`, `ShiftStore` |
| Earnings per app (fares, tips, bonus, trips, km, destination), read from screenshots | `EarningForm`, `EarningsScreenshotScanner` (opens automatically when a shift ends) |
| Expense diary with receipt photo, liters, odometer | `ExpenseForm`, `DiaryView` |
| Stats by day/week/month/year: net, net/h, net/km, cost/km, by app, by category | `StatsView`, `StatsCalculator` |
| Reminders by date and/or km, with notifications 30/7/1 days before | `CarView`, `ReminderPlanner`, `ReminderNotifier` |
| CSV export (shifts, earnings, expenses) | `ExportView`, `CSVExporter` |
| Siri: "Start my shift / End my shift / How much did I make today in DriveCap" | `Intents/ShiftIntents.swift` |
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
  Core/           Screenshot/receipt reading (Vision + Foundation Models), ReminderNotifier, Formatters
  Domain/         Framework-free, unit-tested: EarningsTextParser, StatsCalculator,
                  ReminderPlanner, CSVExporter, categories
  Data/           SwiftData models (Shift, Earning, Expense, Reminder, Car), SampleData (DEBUG)
  Intents/        Siri / Shortcuts
  Presentation/   SwiftUI: Shift, Stats, Diary, Car, Settings, Tutorial
Shared/           Live Activity attributes + EndShiftIntent (app + widget)
FleetCheckWidgets/  Live Activity UI
```

## How the numbers work

- **Kilometers come from screenshots, not GPS** (GPS drained the battery). Each trip or earnings screenshot's
  distance ("Distance 9.4 km", "Distanță 12,6 km") is added to its shift and to the car's odometer;
  editing or deleting the entry adjusts both. Trip screens also give the drop-off address.
  A screenshot taken during a running shift belongs to that shift.
- **Shift time** is just Start → End. If iOS kills the app mid-shift, the shift resumes on the next launch.
- **A shift belongs to the day it started.** A Friday-night shift that ends at 3 AM counts as Friday.
- **Costs that cover several months** (insurance, vignette) are spread evenly per day,
  and stats stop at today so future days aren't charged.
- **Net** = earnings (fares + tips + bonus, after the platform's commission) − expenses.

## Not verifiable in the simulator

- **Apple Intelligence:** the build Mac has no Apple Intelligence, so every AI path ran its fallback in testing.
- **Finding screenshots in Photos:** reading and filing them is unit-tested (`ScreenshotInbox.ingest`); the Photos query itself needs a device.
- **Camera receipts, Siri, Live Activity:** these need a device too.

## Next

Share-sheet extension (send a screenshot straight from Photos), Uber data-export import, fleet payout check, tax set-aside,
Pro subscription, driving score, weather and traffic per shift, best areas map, weekly AI coach.
