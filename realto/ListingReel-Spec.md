# ListingReel — iOS App Specification

**A fast, offline, no-login video tool that turns a realtor's raw phone footage into a branded, platform-ready listing video in under 5 minutes.**

Version 0.1 · Specification document for development. This file is the single source of truth for scope, architecture, and build order. Update it as decisions change.

---

## 1. Product Summary

### 1.1 The one-sentence pitch
A realtor films a walkthrough on their iPhone, drops it into ListingReel, picks a template, and exports a branded video sized for Instagram, feed, and YouTube — all on-device, no account required, no internet needed.

### 1.2 Who it's for
Individual real estate agents (primary) and small brokerages/real estate photographers (secondary) in the US and Western Europe. These users treat software as a business expense, are not technical, and value speed and reliability over creative depth. A single closed listing is worth thousands, so a $10–20/month tool that saves hours is trivially justified.

### 1.3 The core job-to-be-done
"I have raw clips (or photos) of a property. Make them look professional, put my branding on them, add the property details, and give me files I can post everywhere — right now, from my phone, even if I'm standing in a house with no signal."

### 1.4 Positioning wedge (differentiators)
These are deliberate reactions to real weaknesses in existing apps (Momenzo, REVA Pro, AutoReel):

1. **No account, no login, no phone number.** Open → create → export. Nothing gates the first success.
2. **100% on-device processing.** Works offline. Nothing uploads. Privacy and reliability are the pitch.
3. **App Store billing only.** No web-dashboard subscriptions; cancellation is handled by Apple. Eliminates billing-complaint churn.
4. **Bulletproof local rendering.** Export must never silently fail. Rendering is the #1 trust-killer in this category.
5. **Fresh templates monthly.** Templates are data, not code — cheap to ship, and they justify renewal.
6. **Simultaneous multi-format export:** 9:16, 1:1, 16:9 in one tap.

### 1.5 Explicit non-goals (v1)
- No cloud storage, no user accounts, no server backend.
- No MLS integration (a future consideration, not v1).
- No timeline/multi-track manual editor — this is a template tool, not iMovie.
- No collaboration/team features.
- No Android (iOS first; architecture should not actively block a later port but we don't build for it).

---

## 2. Feature Scope

### 2.1 MVP (v1.0) — the minimum that delivers the core job

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| F1 | Media import | Import multiple video clips and/or photos from Photos library. | Must |
| F2 | In-app capture | Record clips directly, with a guided shot list (optional overlay prompts: "living room", "kitchen", "exterior"). | Should |
| F3 | Template selection | Pick from a set of listing templates (intro card → clips → outro). | Must |
| F4 | Property info card | Enter address, price, beds/baths, sqft; rendered into intro/outro cards. | Must |
| F5 | Branding | Add agent logo, name, phone, brokerage; persisted as a reusable profile. | Must |
| F6 | Music | Pick from a bundled licensed music library; auto-fit to video length. | Must |
| F7 | Multi-format export | Export 9:16, 1:1, 16:9 (user chooses one or more) at up to 4K. | Must |
| F8 | Save/share | Save to Photos and share via the system share sheet. | Must |
| F9 | Reliable render pipeline | Progress UI, cancellable, never fails silently, works offline. | Must |

### 2.2 v1.x (fast follow)
- Auto-captions via on-device Speech framework (talking-head market updates).
- Bluetooth/gimbal shutter button support during capture.
- Speed ramp / hyperlapse per clip.
- Simple per-clip trim.
- Watermark toggle (free tier shows watermark, paid removes it).

### 2.4 macOS-only (v1.x, feature-flagged)
**Mac Inbox** — a watched Finder folder + background batch export queue.
Deliberately macOS-only (not a future iOS commitment) and shipped behind a
Settings toggle ("Inbox (Beta)", off by default — spec §3.7). Ships in
Release builds (gated `#if os(macOS)`, not DEBUG-only — the toggle itself is
the gate) and is introduced to the user in onboarding's macOS-only fourth
page (§6.1), since a feature nobody knows exists behind a Settings toggle
they'd never find isn't really shipped.
- Point the app at a folder once; new footage dropped into it (AirDrop, a
  card reader, a photographer's export) auto-creates a draft `Project`, no
  manual "New Video" click needed.
- "Export All Drafts" / "Export Selected" renders several draft projects
  unattended, sequentially, with a single macOS notification summarizing the
  batch when it finishes. One project failing never aborts the rest.

Positioned as the desktop-native answer to Finder drag-and-drop import
(already shipped in the wizard's "Add Media" step, §3.6) — Mac Inbox is about
*not having to open the app at all* to start a project.

### 2.5 v2+ (future)
- Auto scene-to-beat music syncing.
- Photos-to-video slideshow mode (compete with AutoReel/Real Estate Vids).
- Additional niches on the same engine (contractor before/after, etc.).
- Optional MLS listing lookup.

---

## 3. Architecture — Clean Architecture for iOS

### 3.1 Guiding principles
- **Dependency rule:** source-code dependencies point *inward only*. Domain knows nothing about UI, AVFoundation, or the file system.
- **Testable core:** business rules (template assembly, export config) are pure Swift, unit-testable without a device.
- **AVFoundation is a detail:** it lives behind a protocol in the outermost layer, so the rest of the app doesn't care that video is powered by AVFoundation.
- **SwiftUI for views, but views are dumb:** all logic lives in ViewModels/UseCases.

### 3.2 Layers

```
┌─────────────────────────────────────────────────────────┐
│  Presentation (SwiftUI Views + ViewModels)              │
│  - Views: dumb, declarative, bind to ViewModel state    │
│  - ViewModels: @Observable, call UseCases, expose state │
└───────────────────────────┬─────────────────────────────┘
                            │ depends on
┌───────────────────────────▼─────────────────────────────┐
│  Domain (pure Swift, no framework imports)              │
│  - Entities: Project, Template, BrandProfile, MediaClip │
│  - UseCases: AssembleVideoUseCase, ExportVideoUseCase…  │
│  - Repository protocols (interfaces only)               │
└───────────────────────────┬─────────────────────────────┘
                            │ implemented by
┌───────────────────────────▼─────────────────────────────┐
│  Data / Infrastructure                                  │
│  - Repositories (concrete)                              │
│  - VideoCompositionService (AVFoundation)               │
│  - MediaLibraryService (PhotoKit)                       │
│  - PersistenceService (SwiftData/Core Data)             │
│  - AssetCatalog (templates, music - bundled)            │
└─────────────────────────────────────────────────────────┘
```

### 3.3 Suggested module / folder structure

```
ListingReel/
├── App/
│   ├── ListingReelApp.swift            // @main, composition root
│   └── DIContainer.swift               // dependency injection wiring
├── Presentation/
│   ├── Home/
│   ├── Editor/
│   │   ├── EditorView.swift
│   │   └── EditorViewModel.swift
│   ├── Capture/
│   ├── Branding/
│   ├── Export/
│   └── Components/                     // shared SwiftUI views
├── Domain/
│   ├── Entities/
│   │   ├── Project.swift
│   │   ├── Template.swift
│   │   ├── MediaClip.swift
│   │   ├── BrandProfile.swift
│   │   └── ExportSettings.swift
│   ├── UseCases/
│   │   ├── AssembleCompositionUseCase.swift
│   │   ├── ExportVideoUseCase.swift
│   │   ├── SaveProjectUseCase.swift
│   │   └── ManageBrandProfileUseCase.swift
│   └── Repositories/                   // protocols only
│       ├── ProjectRepository.swift
│       ├── MediaRepository.swift
│       ├── TemplateRepository.swift
│       └── VideoRenderer.swift
├── Data/
│   ├── Repositories/                   // concrete implementations
│   ├── Services/
│   │   ├── AVVideoCompositionService.swift
│   │   ├── PhotoKitMediaService.swift
│   │   └── SwiftDataPersistenceService.swift
│   └── Catalog/
│       ├── Templates/                  // JSON template definitions
│       └── Music/                      // bundled licensed audio
├── Resources/
│   ├── Assets.xcassets
│   └── Fonts/
└── Tests/
    ├── DomainTests/                    // pure, fast, no device
    └── DataTests/
```

### 3.4 Key domain entities (shape, not final code)

```swift
// Pure Swift. No AVFoundation, no SwiftUI.

struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var propertyInfo: PropertyInfo
    var clips: [MediaClip]           // ordered
    var templateID: Template.ID
    var musicTrackID: MusicTrack.ID?
    var brandProfileID: BrandProfile.ID
    var createdAt: Date
    var updatedAt: Date
}

struct PropertyInfo: Codable {
    var address: String
    var price: String?
    var beds: Int?
    var baths: Double?
    var squareFeet: Int?
    var headline: String?            // "Just Listed", "Open House Sat 2–4"
}

struct MediaClip: Identifiable, Codable {
    let id: UUID
    var sourceIdentifier: String     // PHAsset localIdentifier or file URL bookmark
    var kind: MediaKind              // .video / .photo
    var trimStart: TimeInterval?
    var trimEnd: TimeInterval?
    var order: Int
}

struct Template: Identifiable, Codable {
    let id: String
    var displayName: String
    var intro: TemplateSegment       // title card layout, duration, animation
    var body: BodyStyle              // transitions, clip pacing, overlays
    var outro: TemplateSegment       // contact card layout
    var defaultAspectRatios: [AspectRatio]
    var fontTokens: FontTokens
    var colorTokens: ColorTokens
}

struct BrandProfile: Identifiable, Codable {
    let id: UUID
    var agentName: String
    var phone: String?
    var brokerage: String?
    var logoAssetID: String?         // reference to stored image
    var primaryColorHex: String
    var accentColorHex: String
}

struct ExportSettings {
    var aspectRatios: Set<AspectRatio>   // 9:16, 1:1, 16:9
    var resolution: Resolution           // .hd1080, .uhd4K
    var codec: VideoCodec                // .hevc preferred, .h264 fallback
    var includeWatermark: Bool           // tier-dependent
}
```

### 3.5 Repository protocols (Domain owns the interface)

```swift
protocol VideoRenderer {
    /// Builds a composition and exports it. Emits progress. Throws on failure.
    func export(
        project: Project,
        template: Template,
        brand: BrandProfile,
        settings: ExportSettings,
        progress: @escaping (Double) -> Void
    ) async throws -> [ExportedFile]     // one per requested aspect ratio
}

protocol ProjectRepository {
    func save(_ project: Project) async throws
    func fetchAll() async throws -> [Project]
    func delete(_ id: Project.ID) async throws
}

protocol TemplateRepository {
    func allTemplates() -> [Template]
    func template(id: Template.ID) -> Template?
}

protocol MediaRepository {
    func importFromLibrary() async throws -> [MediaClip]
    func loadAVAsset(for clip: MediaClip) async throws -> AVAsset  // Data layer only
}
```

The `VideoRenderer` protocol is the seam. The Domain's `ExportVideoUseCase` depends on `VideoRenderer`, never on AVFoundation. The concrete `AVVideoCompositionService` in the Data layer is the *only* file that imports AVFoundation for rendering.

### 3.6 macOS target

A second, native macOS target (`ListingReel-macOS`, not Mac Catalyst) shares the entire Domain and Data layer with iOS — the Clean Architecture split above is exactly what makes this cheap. Notes:

- **Same bundle ID** (`com.adaptiveservices.realto`) as iOS, required for StoreKit "Universal Purchase" — the one-time "Unlock Full Version" purchase (§7) restores on both platforms under the same Apple ID.
- **In-app capture (F2) is iOS-only in v1.** Mac users import existing footage rather than film with a laptop camera; the `Presentation/Capture` folder and `CaptureService.swift` are excluded from the macOS target's sources. "Add Media" on Mac browses/drags in files directly from Finder (`MediaStepView`'s `NSOpenPanel` + `.dropDestination`) rather than using `PhotosPicker`.
- **Firebase isn't linked on macOS.** FirebaseAnalytics doesn't support the platform at all, and Crashlytics wasn't judged essential to feature parity for this pass — `AppDelegate.swift`/`GoogleService-Info.plist` are excluded from the macOS target.
- The handful of UIKit-specific call sites (`UIColor`, `UIImage`, the old `PHPickerViewController`/`UIActivityViewController` wrappers) sit behind a `PlatformColor`/`PlatformImage` typealias shim (`Data/Services/ColorHex.swift`) and SwiftUI-native replacements (`PhotosPicker`/`.photosPicker`, `ShareLink`) — one implementation compiles on both platforms rather than forking files.
- **Mac Inbox** (§2.4) goes the other way — a `MacInbox` grouping under each of `Domain/`, `Data/`, `Presentation/` that's excluded from the *iOS* target's sources instead (`project.yml`), so it doesn't compile into the iPhone app at all. `ListingReelApp.swift` adds a `Settings { }` scene (the flag toggle + folder picker) and a `Window(id: "mac-inbox")` scene for the batch-management surface — both intentionally outside `AppRoute`/`AppCoordinator`, since neither is part of a wizard editing session. See §3.7.

### 3.7 Feature flags

Mac Inbox (§2.4) is the first feature flag in the app — there was no prior
mechanism. Its shape sets the pattern for any future one:

- **Storage**: a small dedicated store (`MacInboxSettingsStore`, an `actor`)
  persisting a JSON file under Application Support, styled exactly like
  `FileBrandProfileRepository` — not `UserDefaults` (keeping a flagged
  feature's state in its own folder keeps it trivially removable if the
  feature is ever pulled). This is specific to Mac Inbox being an
  internal-only feature; `@AppStorage`/`UserDefaults` is still the right,
  standard tool for a permanent, ship-to-everyone flag like onboarding's
  `hasCompletedOnboarding` (§6.1) — don't over-apply this bullet.
- **Visibility**: a real, user-facing Settings toggle (⌘,), off by default,
  gated only `#if os(macOS)` (`DIContainer`, `ListingReelApp`, `RootView`,
  `HomeView`) — ships in Release. Introduced in onboarding's macOS-only
  fourth page (§6.1) rather than left for someone to stumble onto in
  Settings. A future flag that genuinely needs to stay internal-only before
  its first exposure to real users should gate the same touch points with
  `#if os(macOS) && DEBUG` instead — that was this flag's state briefly,
  before onboarding gave it a real introduction.
- **Isolation**: a flagged feature's files live under one `<Layer>/<FeatureName>/`
  grouping per layer and are excluded from the *other* target in
  `project.yml`, mirroring how `Presentation/Capture` is already excluded
  from the macOS target. Touch points in shared files (DI wiring, one toolbar
  button, one `Scene`) stay as small and additive as possible — never a
  scattered `#if FEATURE_X` through existing wizard/render-pipeline code.

---

## 4. The Video Pipeline (AVFoundation — the technical heart)

This is where the app lives or dies. Reliability here is the entire competitive wedge.

### 4.1 Composition assembly
- Use `AVMutableComposition` to lay clips end-to-end on a single (or A/B) video track and an audio track.
- Insert each clip's time range via `insertTimeRange(_:of:at:)`. Respect per-clip trim.
- Normalize orientation: read each source track's `preferredTransform`; portrait phone video needs correct transforms or output rotates. **This is the single most common bug — test portrait, landscape, and mixed-orientation projects explicitly.**

### 4.2 Overlays (title cards, lower-thirds, branding, captions)
- Build overlays as Core Animation layers.
- Composite them onto video using `AVVideoCompositionCoreAnimationTool` (parent layer + video layer + overlay layer).
- Property info card, animated logo, contact outro, and captions are all CALayers.
- **Gotcha:** the animation `beginTime` of 0 must be converted to `AVCoreAnimationBeginTimeAtZero` or animations won't render in the export.
- **Gotcha:** Core Animation timing during export ignores wall-clock; drive everything off the composition timeline.

### 4.3 Multi-aspect-ratio rendering
- Each aspect ratio = a separate `AVMutableVideoComposition` with its own `renderSize` and a layer-instruction transform that scales/repositions the source (fill vs. fit; realtors want fill for interiors).
- Run exports sequentially (not all at once) to control memory; a 4K export is heavy. Show per-format progress.

### 4.4 Export
- `AVAssetExportSession` with a preset; prefer HEVC (`AVAssetExportPresetHEVCHighestQuality`) with H.264 fallback for older devices / compatibility.
- Write to a temp URL in the app's caches, then hand to the share sheet / Photos save.
- **Never fail silently.** Check `exportSession.status`; on `.failed`, surface `exportSession.error` to the user with a retry. Log the failure. This directly addresses the REVA Pro "would not render" reviews that destroyed their trust.
- Make export cancellable (`exportSession.cancelExport()`), and clean up temp files on cancel/failure.

### 4.5 Reliability checklist (make these tests real)
- [ ] Portrait-only project exports upright in all three aspect ratios.
- [ ] Landscape-only project exports correctly.
- [ ] Mixed portrait + landscape clips in one project.
- [ ] Photos-only project (Ken Burns pan/zoom) renders.
- [ ] 4K source on a mid-range device doesn't crash (memory).
- [ ] Airplane mode: full create → export → save works with zero connectivity.
- [ ] Export cancelled mid-way leaves no orphan temp files and no corrupt Photos entry.
- [ ] Very long (10 min) source clip trimmed to 60s exports quickly.
- [ ] App backgrounded mid-export resumes or fails gracefully with a clear message.

---

## 5. Data & Persistence

- **Projects, brand profiles:** SwiftData (iOS 17+) or Core Data. Local only.
- **Media references:** store PHAsset `localIdentifier` or security-scoped bookmarks — **do not** copy raw video into app storage (wastes gigabytes). Resolve to `AVAsset` at render time.
- **Templates:** bundled JSON in the app + a mechanism to add more via app updates (v1) or a lightweight remote config later (v2). No backend required for v1.
- **Music:** bundled audio files with clearly documented licenses (see §8).
- **Logo/brand images:** stored in app support directory, referenced by ID.

---

## 6. UX Flow (happy path)

```
Launch
  └─ [first install only] Onboarding (3 skippable pages, no sign-up, no
       permission prompts) → Home
  └─ Home (list of past projects + big "New Video" button)
       └─ New Video
            ├─ 1. Add media  (import from Photos OR record in-app)
            ├─ 2. Pick template
            ├─ 3. Enter property info  (address, price, beds/baths, sqft)
            ├─ 4. Confirm branding  (pulled from saved profile; editable)
            ├─ 5. Pick music
            ├─ 6. Preview  (scrubbable, real composition)
            └─ 7. Export  → choose aspect ratios → render (progress) → Save/Share
```

Design rules:
- First run: let them reach a finished export with **zero** account friction. The empty-state should invite "New Video," not "Sign up."
- Branding is entered once and reused. Second video should take under 2 minutes.
- Preview must reflect the real render (use the same composition), so there are no surprises after export.

### 6.1 Onboarding (first install only)

`OnboardingView` (`Presentation/Onboarding/`, shared — not platform-excluded)
gates `RootView` behind an `@AppStorage("hasCompletedOnboarding")` flag, once
per install per platform. It exists purely to set expectations before Home
appears — it must never become a second "account friction" wall (§6 design
rules), so it asks for nothing: no sign-up, no permission prompts (Photos/
camera/mic stay requested lazily at the point of use, same as today), no
required fields. "Skip" is always one tap away except on the final page.

Pages, each mapping to a step of this document — `Page` is a `CaseIterable`
enum with the third case declared `#if os(macOS)`, so iOS gets 3 pages and
macOS gets 4 without separate page-count bookkeeping:
1. **Welcome** — restates the one-sentence pitch (§1.1) and the no-account/
   on-device promise.
2. **How it works** — three rows condensing the 7-step wizard into what
   actually matters to a first-time user: add footage (platform-aware copy —
   Photos/record on iOS, Finder drag-and-drop on macOS, matching `MediaStepView`),
   pick a style + branding (persisted, §6 "second video under 2 minutes"),
   export in every format (§1.4.6).
3. **Mac Inbox** (macOS only) — introduces the watched-folder flag (§2.4):
   turn it on in Settings, point it at a folder, drafts appear automatically,
   batch-export unattended. Explicitly notes it's off by default. This is the
   feature's only introduction to a real user — there's no other in-app
   affordance pointing at the Settings toggle.
4. **Ready** — an honest note about the free-tier watermark and the one-time
   unlock (§7), then "Get Started."

UI tests launch straight into the wizard and can't rely on a fresh
`UserDefaults` default — `-UITestSkipOnboarding` (DEBUG-only, alongside the
existing `-UITestSeedClips` seam in `AppCoordinator`) bypasses the gate.

---

## 7. Monetization

- **Model:** Free tier (all templates, all music, all aspect ratios, exports up to 1080p) with a small watermark on exports. A single non-consumable **one-time purchase** ("Unlock Full Version," product ID `com.listingreel.app.unlock`) removes the watermark and unlocks 4K Ultra HD. No subscriptions, no recurring billing — deliberately simpler than the typical photo/video-app subscription paywall: pay once, own it forever, restorable via "Restore Purchases" on any device on the same Apple ID.
- **Paywall:** shown post-preview / pre-export when a free user tries to remove the watermark or export at 4K (`PaywallView`, triggered from `ExportStepView`).
- **Price anchor:** ~$19.99 one-time. Do **not** underprice to $2.99 — the audience judges cheap tools as unprofessional and it caps revenue.
- **Billing:** StoreKit 2 / App Store only (`SubscriptionManager`, `ListingReel.storekit`). Because there's no auto-renewal, the App Review subscription-disclosure requirements (Guideline 3.1.2) don't apply — but a working Privacy Policy and Terms of Use link are still required near the purchase button.

---

## 8. Legal & Compliance (do not skip)

- **Music licensing:** every bundled track needs a license permitting redistribution inside an app and use in users' commercial videos. Use a royalty-free library with an app-distribution license, or commission original tracks. Keep a license record per track. This is a real legal exposure — get it right.
- **MLS compliance:** many MLS boards have rules about branding on listing content. Market templates as "MLS-friendly" only if they genuinely support unbranded variants. Don't over-claim.
- **Privacy:** because everything is on-device, the privacy story is strong. Still need an App Privacy nutrition label; if you add no analytics, you can honestly say "no data collected," which is a marketing asset.
- **Permissions:** camera, microphone, photo library — with clear `Info.plist` usage strings explaining *why* (agents are wary of permission grabs; one Momenzo reviewer bounced over a phone-number request).
- **Fair Housing:** if you ship script/caption templates, avoid any language that could imply discriminatory preference. Keep copy neutral.

---

## 9. Build Order (recommended sequencing)

**Phase 0 — De-risk the hard part first.**
Build a throwaway spike: import one clip → apply one hardcoded title-card overlay → export 9:16. Prove the AVFoundation pipeline (transforms, Core Animation overlay, export success) before building any UI. If this is solid, the rest is straightforward app plumbing.

**Phase 1 — Core vertical slice.**
Domain entities + `VideoRenderer` protocol + one real template + minimal SwiftUI flow (import → template → property info → export). One aspect ratio. No branding, no music yet. Goal: a full end-to-end export.

**Phase 2 — Make it useful.**
Brand profiles, music library, multi-format export, preview screen, project save/load.

**Phase 3 — Make it sell.**
3–5 polished templates, paywall + StoreKit, App Store listing (ASO for "listing video", "real estate video maker"), onboarding.

**Phase 4 — Validate with real users.**
Put Phase 1–2 in front of 5–10 actual agents (local realtor Facebook groups). Their reaction to ONE template beats any spec. Iterate templates based on what they actually post.

**Phase 5 — Fast follow.**
Auto-captions, gimbal support, per-clip trim, speed ramps.

---

## 10. Technical Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Min iOS version | iOS 17+ | SwiftData, modern SwiftUI, `@Observable`. Revisit if it excludes too many agents' devices. |
| UI framework | SwiftUI | Faster solo-dev iteration; drop to UIKit only where needed (custom camera). |
| Video framework | AVFoundation | Native, on-device, no cost, full control. The whole premise. |
| Persistence | SwiftData | Local-only, low ceremony. Core Data if SwiftData proves limiting. |
| Architecture | Clean Architecture (3 layers) | Keeps AVFoundation swappable and domain testable. |
| Subscriptions | StoreKit 2 (+ optional RevenueCat) | App Store billing is a deliberate differentiator. |
| Backend | None (v1) | On-device is the wedge; no server cost, works offline. |
| macOS support | Native SwiftUI target, not Mac Catalyst (§3.6) | Reuses the Clean Architecture Domain/Data layers; feels like a real Mac app rather than an iPad app running on the Mac. Capture (F2) deferred on Mac in v1. |

---

## 11. Open Questions (resolve before/along the way)

- Exact min iOS version — check the device distribution of your target agents.
- Music: license a library vs. commission originals? (Budget vs. control.)
- Free-tier watermark: how prominent? Enough to motivate upgrade, not so much it kills shares.
- Template authoring: hardcoded Swift vs. JSON-driven? (JSON strongly recommended so non-engineers can add templates and you can ship them without app updates later.)
- Photos-slideshow mode in v1 or v2? (AutoReel/Real Estate Vids compete here; may be worth pulling forward.)

---

## 12. Definition of Done for v1.0

- A realtor, on first launch with no account, can import clips, pick a template, enter property details, add their logo, pick music, preview, and export a branded 9:16 + 1:1 + 16:9 video, save it to Photos, and share it — entirely offline — in under 5 minutes, with zero render failures across the §4.5 reliability checklist.
