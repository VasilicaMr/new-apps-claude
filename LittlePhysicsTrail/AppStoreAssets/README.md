# App Store Connect assets

## Header and Search Results (iOS 27)

Upload these on the app version page under **Header and Search Results**, or in the **Asset Library**.

| File | Placement | Size | Notes |
|---|---|---|---|
| `header.png` | Product page header | 3840 × 1646 (21:9) | Illustrated trail with no text, so one image works for every language |
| `search_results.png` | Search results | 3840 × 2560 (3:2) | Headline plus the real game screen ("state the obvious") |

Both are opaque PNGs (`sips -g hasAlpha` → `no`), as App Store Connect requires.

### Design notes

- **Header:** one idea, a winding trail of discoveries. The seven stop icons match the app's
  journey map. The highlighted 💡 stop and the owl guide sit inside the template's safe area
  (about x 1097–2743, y 493–1154), so narrower crops keep them. Stops near the edges may be cropped,
  which is fine. The top edge is kept quiet because the App Store's back and share buttons sit there.
- **Search results:** the headline "Sort it. Learn why." and subline sit on the left inside the safe area
  (about x 836–3004, y 765–1795). The phone shows the real Sink or Float screen with the "Big ship ·
  Floats!" fact card, the app's teaching moment. It runs off the right and bottom edges so
  the screen stays large at search size (about 365 pt wide). Checked at a 384 px wide copy:
  the headline and fact card are still readable.
- **App Store rules followed:** no price or "free" claims, no URLs, logos, awards or other platforms,
  and content suitable for 4+. The generic phone frame is drawn, not an Apple device image.

### Regenerate

```bash
# 1. Optional: a fresh game screenshot (iPhone 17 Pro Max, 1320×2868, status bar 9:41)
#    → AppStoreAssets/Source/game_sink_or_float.png
# 2. Render both assets
swift tools/make_store_assets.swift AppStoreAssets/Source/game_sink_or_float.png AppStoreAssets
```

Edit the headline, colors and layout in `tools/make_store_assets.swift`. It uses the same palette as
the app's `NubeeTheme`.

### Localizing

Only `search_results.png` has text. For each language, translate the two `Text(...)` strings in
`SearchResults`, use a screenshot taken in that language, and render again.

### Before uploading

Check both images with the preview tool in App Store Connect. Apple's templates
(Figma, Sketch, Photoshop, Pixelmator) show the exact safe areas per device.

## Store text

`metadata/en-US/promotional_text.txt` (limit 170 characters) and `metadata/en-US/description.txt` (limit 4000) are ready to paste into App Store Connect. They use fastlane's `deliver` folder layout, so you can upload them with `fastlane deliver` later. If the content changes (stops, items, privacy, pricing model), update these files too.
