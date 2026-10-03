# macOS App Store Connect assets

## Screenshots (3, 1280×800)

**Not generated yet** — this dev environment can launch the app (its menu
bar takes over, the process runs fine) but no app window ever actually
renders on screen, even for a from-scratch minimal SwiftUI app. See the
`macos-app-windows-dont-render` memory note. This blocks capturing a real
screenshot here; it isn't a bug in Realto.

Everything needed to produce the 3 screenshots is built and ready to run
**on a Mac where app windows actually render** (e.g. your own machine):

```
Scripts/generate-appstore-screenshots-macos.sh
```

This runs `ListingReelMacOSUITests` (drives Home → Preview → Export-done
with seeded local clips, no Photos library needed), extracts its 3
`.keepAlways` screenshot attachments from the `.xcresult`, and composites
each onto a branded 1280×800 canvas (`Scripts/compose-appstore-screenshot.py`
— centers the actual window on Theme's dark background with a soft shadow,
since the app's window is sized for a portrait wizard, not a landscape
screenshot). Output lands in `AppStoreAssets/Screenshots-macOS/`:

- `01_Home.png` — the zero-friction empty state
- `02_Preview.png` — the real composition (branding + property card + clips)
- `03_ExportDone.png` — proof the render finishes successfully

The compositor itself is verified working (tested against an arbitrary
screenshot) — only the actual app capture is blocked here.

## Promotional text (≤170 characters)

See `macOS-promotional-text.txt` — 148 characters, ready to paste into App
Store Connect as-is.

## Description (≤4000 characters)

See `macOS-description.txt` — 2,182 characters. Written from
`ListingReel-Spec.md`; deliberately does not mention Mac Inbox, since that
flag is currently DEBUG-only (hidden from this Release build's Settings —
see conversation history / `ListingReelApp.swift`'s `#if DEBUG` around the
`Settings` scene). Update the description if that changes before submission.
