# ListingReel — iOS + macOS App

A native SwiftUI app that turns a realtor's raw phone footage into a branded,
platform-ready listing video — on-device, offline, no login. Built to the
[ListingReel-Spec.md](./ListingReel-Spec.md).

## Status

- ✅ Builds for iOS 17+ (Xcode 26 / iOS Simulator) and macOS 14+ (native target,
  not Mac Catalyst — spec §3.6).
- ✅ Domain unit tests pass (`Executed 7 tests, 0 failures`).
- ✅ Full create → export vertical slice implemented end-to-end on both platforms.

## Run it

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonik0/XcodeGen):

```bash
xcodegen generate
open ListingReel.xcodeproj      # then Run (⌘R) on an iOS 17+ simulator/device,
                                 # or pick the "ListingReel-macOS" scheme for the Mac
# or:
xcodebuild build -project ListingReel.xcodeproj -scheme ListingReel \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test  -project ListingReel.xcodeproj -scheme ListingReel \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# macOS:
xcodebuild build -project ListingReel.xcodeproj -scheme ListingReel-macOS \
  -destination 'platform=macOS'
```

> Media import, capture, and Photos save need a real device or a simulator with
> photos in its library. Music playback needs bundled audio files (see below).
> In-app capture (F2) is iOS-only — the Mac target imports existing footage only.

## Architecture — Clean Architecture + Coordinator

Dependencies point **inward only**. The Domain is pure Swift with no framework
imports; AVFoundation lives behind the `VideoRenderer` protocol in the outermost
layer (spec §3).

```
Presentation (SwiftUI Views + @Observable ViewModels + Coordinator)
        │  depends on
        ▼
Domain (pure Swift: Entities, UseCases, Repository protocols)   ← no UIKit/AVFoundation
        ▲  implemented by
        │
Data / Infrastructure (AVFoundation, PhotoKit, SwiftData, catalogs)
```

- **Domain** (`Domain/`): `Project`, `Template`, `BrandProfile`, `MediaClip`,
  `ExportSettings`, `RenderError`; use cases (`ExportVideoUseCase`, …); and the
  repository protocols the Data layer implements. Fully unit-testable, no device.
- **Data** (`Data/`): the concrete `AVVideoCompositionService` (the only file that
  imports AVFoundation for rendering), `PhotoKitMediaService`, SwiftData and
  file-based persistence, and the bundled template/music catalogs.
- **Presentation** (`Presentation/`): dumb SwiftUI views bound to `@Observable`
  ViewModels. Navigation is centralized in **`AppCoordinator`** — views never push
  each other; they ask the coordinator. `DIContainer` is the composition root.

### Two platforms, one codebase (spec §3.6)

`ListingReel-macOS` is a native SwiftUI target (not Mac Catalyst) sharing the
entire Domain and Data layer with iOS. The narrow platform-specific surface
(`UIColor`/`UIImage`, the Photos picker, the share sheet) sits behind a
`PlatformColor`/`PlatformImage` typealias shim (`Data/Services/ColorHex.swift`)
and SwiftUI-native cross-platform APIs (`PhotosPicker`/`.photosPicker`,
`ShareLink`) rather than forked files. In-app capture (F2) is excluded from the
macOS target's sources — Mac users import existing footage.

### The Coordinator pattern

`AppCoordinator` owns a `NavigationPath` and the lifetime of the current editing
session (`EditorFlowModel`), so all seven wizard steps mutate one working
`Project`. `RootView` is the only place that declares `navigationDestination`s;
`AppRoute` is a value-typed enum that also encodes the wizard order (`.next`).

## Screens

| Step | Screen | What it does |
|------|--------|--------------|
| Home | `HomeView` | Past projects + big "New Video" CTA. Zero-friction empty state. |
| 1 | `MediaStepView` | Import clips/photos from Photos (identifiers only, no byte-copy). Record-with-camera is iOS-only. |
| 2 | `TemplateStepView` | Pick a style (Classic / Bold / Minimal) — data-driven templates. |
| 3 | `PropertyInfoStepView` | Address, price, beds/baths/sqft, headline. |
| 4 | `BrandingStepView` | Agent name, phone, brokerage, logo — saved once, reused. |
| 5 | `MusicStepView` | Pick a bundled licensed track (or keep source audio). |
| 6 | `PreviewStepView` | Plays the **real composition** via `AVPlayer` — no surprises. |
| 7 | `ExportStepView` | Choose 9:16 / 1:1 / 16:9 + resolution → render → save/share. |

## The AVFoundation pipeline (the technical heart — spec §4)

All rendering is behind the `VideoRenderer` protocol. `AVVideoCompositionService`
+ the shared `CompositionAssembler` implement it:

1. **Assembly** — `AVMutableComposition`, clips laid end-to-end on one video track
   via `insertTimeRange(_:of:at:)`, honoring per-clip trim.
2. **Orientation-safe transforms** — each source's `preferredTransform` +
   natural size drives a fill/fit transform, so portrait/landscape/mixed projects
   all export upright (the single most common bug in this category).
3. **Overlays** — title cards, lower-third branding, contact outro, and the
   free-tier watermark are Core Animation layers composited with
   `AVVideoCompositionCoreAnimationTool`. Animations use
   `AVCoreAnimationBeginTimeAtZero` and are driven entirely off the composition
   timeline (both documented gotchas handled in `OverlayLayerFactory`).
4. **Multi-format** — each aspect ratio is its own `AVMutableVideoComposition`
   with its own `renderSize`; formats render **sequentially** to bound memory.
5. **Export** — `AVAssetExportSession`, HEVC preferred with H.264 fallback,
   progress reported, **cancellable**, temp files cleaned up on cancel/failure,
   and every failure surfaced as a user-facing `RenderError` (never silent).
6. **Photos** — turned into short video segments by `StillImageVideoGenerator`
   (`AVAssetWriter`) so they live on the same track as real clips.
7. **Preview parity** — `PreviewComposer` reuses the exact assembly path at a
   small render size, so the preview matches the final export.

## What's stubbed / next

- **Bundled music** (`Resources/Music/*.m4a`) ships three original, in-house
  tracks (no third-party licensing exposure) — a v1 placeholder library rather
  than professionally produced music; consider commissioning real tracks before
  a wide release (spec §8).
- **Monetization** is implemented: free tier (watermarked exports, up to 1080p)
  plus a single StoreKit 2 non-consumable one-time purchase, "Unlock Full
  Version," that removes the watermark and unlocks 4K — no subscriptions
  (`SubscriptionManager`, `PaywallView`, spec §7).
- **In-app capture** (F2), **per-clip trim UI**, and **captions** (v1.x) are
  architected-for but not yet built.

See `ListingReel-Spec.md` §9 for the recommended build order and §4.5 for the
render reliability checklist to turn into device tests.
