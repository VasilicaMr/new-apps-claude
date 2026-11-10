# App Store Connect assets

For the full publishing checklist (app record, privacy, build upload, review), see
[`AppStoreConnect.md`](AppStoreConnect.md). In-app purchases are in [`InAppPurchases.md`](InAppPurchases.md).

## Header and Search Results (iOS 27)

Upload these on the app version page under **Header and Search Results**, or in the **Asset Library**.

| File | Placement | Size | Notes |
|---|---|---|---|
| `header.png` | Product page header, every language | 3840 × 1646 (21:9) | A road through a driver's day, no text |
| `en-US/search_results.png` | Search results, English (U.S.) | 3840 × 2560 (3:2) | "Know what you really keep." plus the English Home screen |
| `ro/search_results.png` | Search results, Romanian | 3840 × 2560 (3:2) | "Vezi cât îți rămâne de fapt." plus the Romanian Home screen |
| `fr-FR/search_results.png` | Search results, French | 3840 × 2560 (3:2) | "Voyez ce qu’il vous reste vraiment." plus the French Home screen |

All are opaque PNGs (`sips -g hasAlpha` → `no`), as App Store Connect requires.

### Design notes

- **Header:** the app's gradient tiles along a road, in the order of a driver's day: shift timer, screenshot reading,
  fuel receipt, the car (large, highlighted), stats, calendar, assistant. The car sits in the middle of the template's
  safe area (about x 1097–2743, y 493–1154), so narrower crops keep it. Tiles near the edges may be cropped, which is
  fine. The top edge stays quiet because the App Store's back and share buttons sit there.
- **Search results:** headline and subline on the left inside the safe area (about x 836–3004, y 765–1795). The phone
  shows the real Home screen with the "Upload your earnings" card, the app's main idea. It runs off the right and bottom
  edges so the screen stays large at search size.
- **App Store rules followed:** no price or "free" claims, no URLs, awards or other platforms in the artwork. The
  generic phone frame is drawn, not an Apple device image. The Home screen's own text names Uber and Bolt; that is
  the app's real UI, but if review objects, retake the screenshot on a screen that doesn't name them.

### Regenerate

```bash
# 1. Optional: fresh screenshots, including Source/home_<lang>.png (see Screenshots below)
Scripts/capture_store_screenshots.sh

# 2. Render all assets
swift Scripts/make_store_assets.swift AppStoreAssets
```

Edit the headlines, colors and layout in `Scripts/make_store_assets.swift`. It uses the same palette as the app's
`Theme`. To add a language, add a row to `languages` and a `Source/home_<lang>.png` screenshot.

### Before uploading

Check every image with the preview tool in App Store Connect. Apple's templates (Figma, Sketch, Photoshop,
Pixelmator) show the exact safe areas per device.

## Screenshots

Seven framed screenshots per language, for **iPhone 6.9"** (`<locale>/iphone/`, 1320 × 2868) and **iPad 13"**
(`<locale>/ipad/`, 2064 × 2752). App Store Connect scales them down for the smaller devices. Upload them in this order:

| # | Screen | English caption |
|---|---|---|
| 1 | Home | Know what you really keep |
| 2 | Earnings form filled from a screenshot | Earnings read from a screenshot |
| 3 | Stats, this week | Your real pay per hour |
| 4 | Minimum fare (Pro) | Know your minimum fare |
| 5 | Best times (Pro) | Drive when it pays best |
| 6 | Ask: "How much did I make this week?" | Just ask |
| 7 | Car and reminders | Car papers on time |

- English uses a U.S. region, so amounts are in **dollars**; Romanian uses lei and French euros. The sample data
  (`-seedSampleData`) scales its amounts and fuel price to the currency, so the numbers look local.
- The earnings screenshot being read (`Source/scan_<lang>.png`) is drawn by `Scripts/generate_store_scan_images.py`
  with a generic "Earnings" title, not a ride-hailing app's brand.
- Captions live in `captions` in `Scripts/make_store_assets.swift`.

### Regenerate

```bash
Scripts/capture_store_screenshots.sh          # ~10 min: raw screens on both simulators, all languages
swift Scripts/make_store_assets.swift AppStoreAssets   # frames them, plus the header and search results
```

The capture script uses the simulators "iPhone 17 Pro Max" and "iPad Pro 13-inch M4 (Screenshots)"; set `IPHONE` or
`IPAD` to use others. It also refreshes `Source/home_<lang>.png` for the search results artwork.

## Store text

`metadata/<locale>/` holds the name, subtitle, promotional text, keywords and description for English (U.S.),
Romanian and French, ready to paste into App Store Connect. The folders follow fastlane's `deliver` layout, so you can
upload them with `fastlane deliver` later.

| File | Limit | en-US | ro | fr-FR |
|---|---|---|---|---|
| `name.txt` | 30 | 8 | 8 | 8 |
| `subtitle.txt` | 30 | 29 | 29 | 27 |
| `promotional_text.txt` | 170 | 166 | 152 | 156 |
| `keywords.txt` | 100 bytes | 99 | 94 | 90 |
| `description.txt` | 4000 | 2736 | 2848 | 3269 |

- **Keywords** skip words already in the name and subtitle (the App Store indexes those too) and brand names like
  Uber or Bolt, which Apple doesn't allow there. Romanian and French keywords are written without diacritics to save
  bytes; App Store search matches them either way.
- **Description** names Uber and Bolt only in the closing "not affiliated" line. The examples it quotes
  ("fuel $40 38 L", "Cât am câștigat săptămâna asta?"…) are checked by `StoreDescriptionExampleTests`.
- If features, the free allowance or the plans change, update the description too.
