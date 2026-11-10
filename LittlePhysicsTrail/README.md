# Little Physics Trail 🦉

A journey game for kids aged 4–8 that teaches **eight big physics ideas** by playing with them.
It is built on the same approach as [ShadowMatch](../ShadowMatch): a winding trail of stops,
a "drag it to the right place" game at each stop, stars, and a gentle "next stop" guide.
There are no ads, and everything is read aloud for pre-readers.

**Pricing:** stops 1–3 are free. A single one-time, family-shareable purchase, **Full Journey**
(suggested $3.99), unlocks the other five. There is no subscription and no per-stop purchase.
Buying is only possible from grown-up screens behind the parental gate.

| Trail | Big idea | Play | Learn why |
|---|---|---|---|
| Winding road with 8 stops; the owl suggests the next one | Concept card + "try at home" experiment | Drag each item into the right box | A fact card explains *why*, read aloud |

## The journey

| # | Stop | Big idea | Sort into | Access |
|---|---|---|---|---|
| 1 | 🛁 Sink or Float | Buoyancy: light-for-its-size things float | Floats / Sinks | Free |
| 2 | 🧲 Magnet Magic | Magnetism: magnets pull iron and steel | Sticks / No pull | Free |
| 3 | 💪 Push or Pull | Forces are pushes and pulls | Push / Pull | Free |
| 4 | 💡 Light & Shadow | Light sources vs. things that reflect light | Makes light / No light | Full Journey |
| 5 | 🌡️ Hot & Cold | Heat moves from hot to cold | Hot / Cold | Full Journey |
| 6 | 🔊 Loud & Quiet | Sound is a vibration | Loud / Quiet | Full Journey |
| 7 | 🛝 Down the Ramp | Gravity, rolling and friction | Rolls / Slides | Full Journey |
| 8 | 🧪 Solid, Liquid, Gas | States of matter | Solid / Liquid / Gas | Full Journey |

Learning goals and a parent guide per stop: [docs/CURRICULUM.md](docs/CURRICULUM.md).

## Run it

```bash
cd LittlePhysicsTrail
xcodegen                     # regenerate LittlePhysicsTrail.xcodeproj after adding/removing files
open LittlePhysicsTrail.xcodeproj  # run the "LittlePhysicsTrail" scheme (iOS 17+, iPhone & iPad)
```

The scheme's Run action uses `LittlePhysicsTrail.storekit`, so the Full Journey purchase works locally
without App Store Connect. In DEBUG builds, the `-unlockFullJourney` launch argument opens every stop.

## Test it

```bash
# Domain + Data (fast, no simulator — runs on macOS)
cd Packages/PhysicsTrailCore && swift test

# Everything, including the UI test that plays the whole first stop
xcodebuild -project LittlePhysicsTrail.xcodeproj -scheme LittlePhysicsTrail \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test
```

## Project layout

```
LittlePhysicsTrail/
├── Packages/PhysicsTrailCore/      ← inner rings, pure Swift, no UI
│   ├── Sources/TrailDomain/        entities, game rules, protocols, use cases
│   ├── Sources/TrailData/          content catalog + UserDefaults repositories
│   └── Tests/                      domain rules + content guard-rails
├── LittlePhysicsTrail/                   ← iOS app (outer ring)
│   ├── App/                        @main + AppContainer (composition root)
│   ├── Infrastructure/             SpeechNarrator, StoreKitPurchaseService
│   ├── Presentation/
│   │   ├── DesignSystem/           Nubee theme shared with ShadowMatch
│   │   ├── Journey/                trail screen + view model
│   │   ├── Lesson/                 big idea intro, sorting game, view model
│   │   ├── Unlock/                 Full Journey purchase page (behind parental gate)
│   │   └── GrownUps/               purchase status, settings, curriculum, reset (behind parental gate)
│   └── Resources/                  asset catalog
├── LittlePhysicsTrail.storekit           local StoreKit config (Full Journey, $3.99)
├── LittlePhysicsTrailUITests/
├── AppStoreAssets/                App Store Connect header + search results images
├── tools/                        make_app_icon.py, make_store_assets.swift
└── docs/                           architecture, curriculum, game design, content guide
```

## Docs

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): the clean architecture layers, the dependency rule and data flow
- [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md): what was reused from ShadowMatch, what changed, and monetization
- [docs/CURRICULUM.md](docs/CURRICULUM.md): learning goals, misconceptions handled, and parent prompts
- [docs/ADDING_A_STOP.md](docs/ADDING_A_STOP.md): how to add a new physics idea to the trail
