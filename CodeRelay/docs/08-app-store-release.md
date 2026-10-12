# 08 · App Store & release

## iOS app: App Store
**Bundle ID** `com.adaptiveservices.coderelay` · **Category** Developer Tools · **Age rating** 4+

### Review risks and how we handle them
| Guideline | Risk | Our answer |
|---|---|---|
| 2.1 / 4.2 Minimum functionality: reviewer can't set up a Mac | Rejection as "doesn't work" | **Demo Mac** built in (+ → Try the demo, also on the empty state). Say so in Review Notes. |
| 2.5.2 Executing code | Remote shell confusion | Nothing runs on the device. It is a remote client, like SSH apps (Termius, Blink). Say so in Review Notes. |
| 5.2 Intellectual property: "Claude" | Name and trademark | App name *CodeRelay*. The subtitle may say "for Claude Code" only as descriptive use; disclaimer in Settings → About. Avoid Anthropic logos. |
| 5.1.1 Privacy | Data collection | Collects **nothing**. Privacy label: *Data Not Collected*. |
| Local network | Permission denial | Clear `NSLocalNetworkUsageDescription`; manual address as a fallback. |

### Review Notes template
> CodeRelay is a remote client for the Claude Code command-line tool that the user runs on their own Mac via our free companion app "CodeRelay Host" (download: https://coderelay.app). No code is executed on the iOS device. To evaluate without a Mac, tap "+" → "Try the demo" on the first screen; this opens a simulated Mac with a full session, including a permission prompt.

### Store text draft
* **Subtitle:** Remote terminal for Claude Code
* **Promo:** Start, watch and steer Claude Code sessions on your Mac from your iPhone. Approve edits with a tap.
* **Keywords:** terminal,ssh,remote,coding,ai,agent,developer,mac,cli,programming
* **Screenshots:** use the Demo Mac (session with streaming text, permission card, AI follow-ups). Need 6.9" iPhone and 13" iPad.

### Pricing ideas
Free download, with a one-time "Pro" unlock (multiple Macs, AI features, themes) via StoreKit 2. This isn't implemented yet; see roadmap.

### Upload
```bash
xcodebuild -project CodeRelay.xcodeproj -scheme CodeRelay -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/CodeRelay.xcarchive archive
# then Xcode Organizer → Distribute App → App Store Connect
```

## Mac host: Developer ID (outside the Mac App Store)
1. Set `DEVELOPMENT_TEAM`, and in `project.yml` replace `CODE_SIGN_IDENTITY: "-"` with `Developer ID Application`. Hardened Runtime is already on.
2. Archive, export with "Developer ID", then notarize:
   ```bash
   xcrun notarytool submit "CodeRelay Host.zip" --keychain-profile AC_NOTARY --wait
   xcrun stapler staple "CodeRelay Host.app"
   ```
3. Ship a DMG from your website or GitHub Releases. Consider Sparkle for auto-updates.
