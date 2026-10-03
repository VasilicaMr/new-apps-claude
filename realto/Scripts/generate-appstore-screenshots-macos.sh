#!/usr/bin/env bash
# Runs ListingReelMacOSUITests/AppStoreScreenshotMacUITests, extracts its
# .keepAlways screenshot attachments, and composites each onto a 1280x800
# App Store Connect canvas via compose-appstore-screenshot.py.
#
# Needs a Mac session that can actually render app windows — see the
# "macos-app-windows-dont-render" note if this produces blank/missing
# screenshots (menu bar comes up but no window appears in the capture).
#
# Usage: Scripts/generate-appstore-screenshots-macos.sh
set -euo pipefail
cd "$(dirname "$0")/.."

RESULT_BUNDLE=/tmp/realto_appstore_screenshots.xcresult
EXPORT_DIR=/tmp/realto_appstore_screenshots_export
OUT_DIR=AppStoreAssets/Screenshots-macOS

rm -rf "$RESULT_BUNDLE" "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR" "$OUT_DIR"

echo "==> Running AppStoreScreenshotMacUITests..."
xcodebuild -project ListingReel.xcodeproj -scheme ListingReel-macOS -configuration Debug \
    -destination 'platform=macOS' \
    -only-testing:ListingReelMacOSUITests \
    -resultBundlePath "$RESULT_BUNDLE" \
    test

echo "==> Exporting attachments..."
xcrun xcresulttool export attachments \
    --path "$RESULT_BUNDLE" \
    --test-id "AppStoreScreenshotMacUITests/testCaptureMacScreenshots()" \
    --output-path "$EXPORT_DIR"

MANIFEST="$EXPORT_DIR/manifest.json"

compose_one() {
    local label="$1" out_name="$2"
    local exported
    # manifest.json is a list of test entries, each with its own "attachments"
    # list — flatten and match by our XCTAttachment `.name` (e.g. "01_Home"),
    # which xcresulttool surfaces as `suggestedHumanReadableName`.
    exported=$(python3 -c "
import json
manifest = json.load(open('$MANIFEST'))
for test_entry in manifest:
    for att in test_entry.get('attachments', []):
        if att['suggestedHumanReadableName'].startswith('$label'):
            print(att['exportedFileName'])
            raise SystemExit
")
    if [ -z "$exported" ]; then
        echo "warning: no attachment found for $label — skipping" >&2
        return
    fi
    python3 Scripts/compose-appstore-screenshot.py "$EXPORT_DIR/$exported" "$OUT_DIR/$out_name"
}

compose_one "01_Home" "01_Home.png"
compose_one "02_Preview" "02_Preview.png"
compose_one "03_ExportDone" "03_ExportDone.png"

echo "==> Done. Screenshots in $OUT_DIR/"
