#!/bin/bash
# Captures the raw App Store screenshots on the iPhone and iPad simulators, in every store language,
# with sample data and Pro on. Frame them afterwards with Scripts/make_store_screenshots.swift.
#
#   Scripts/capture_store_screenshots.sh   → AppStoreAssets/Source/screens/<iphone|ipad>/<lang>/<nn>_<screen>.png
#
# English uses a U.S. region (dollars), Romanian lei and French euros.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
BID=com.adaptiveservices.drivo
IPHONE=${IPHONE:-"iPhone 17 Pro Max"}
IPAD=${IPAD:-"iPad Pro 13-inch M4 (Screenshots)"}
DERIVED=${DERIVED:-build/StoreScreenshots}

python3 Scripts/generate_store_scan_images.py

udid() { xcrun simctl list devices available | grep -F "$1 (" | head -1 | grep -oE '[0-9A-F-]{36}'; }

shoot() { # device-udid out-file wait-seconds args...
    local sim=$1 out=$2 wait=$3; shift 3
    xcrun simctl terminate "$sim" $BID 2>/dev/null || true
    xcrun simctl launch "$sim" $BID -hasSeenTutorial YES -forcePro YES -seedSampleData "$@" >/dev/null
    sleep "$wait"
    xcrun simctl io "$sim" screenshot "$out" >/dev/null 2>&1
    echo "  $out"
}

for device in iphone ipad; do
    name=$([ $device = iphone ] && echo "$IPHONE" || echo "$IPAD")
    sim=$(udid "$name")
    [ -n "$sim" ] || { echo "No simulator named \"$name\""; exit 1; }
    xcrun simctl boot "$sim" 2>/dev/null || true
    xcrun simctl bootstatus "$sim" >/dev/null
    xcrun simctl ui "$sim" appearance light
    xcrun simctl status_bar "$sim" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

    xcodebuild -scheme FleetCheck -destination "id=$sim" -derivedDataPath "$DERIVED" build -quiet
    xcrun simctl install "$sim" "$DERIVED/Build/Products/Debug-iphonesimulator/FleetCheck.app"
    # One launch first: the first start after install is slow.
    shoot "$sim" /dev/null 12 -initialTab home 2>/dev/null || true

    for lang in en ro fr; do
        case $lang in
            en) locale=en_US; currency=USD; question="How much did I make this week?" ;;
            ro) locale=ro_RO; currency=RON; question="Cât am câștigat săptămâna asta?" ;;
            fr) locale=fr_FR; currency=EUR; question="Combien j’ai gagné cette semaine ?" ;;
        esac
        out=AppStoreAssets/Source/screens/$device/$lang
        mkdir -p "$out"
        echo "$device · $lang"
        common=(-AppleLanguages "($lang)" -AppleLocale $locale -currencyCode $currency)
        shoot "$sim" "$out/1_home.png" 9 "${common[@]}" -initialTab home
        shoot "$sim" "$out/2_scan.png" 10 "${common[@]}" -initialTab home -debugScanImage "$ROOT/AppStoreAssets/Source/scan_$lang.png"
        shoot "$sim" "$out/3_stats.png" 9 "${common[@]}" -initialTab stats
        shoot "$sim" "$out/4_min_fare.png" 9 "${common[@]}" -initialTab home -debugPlanTool carCost
        shoot "$sim" "$out/5_best_times.png" 9 "${common[@]}" -initialTab home -debugPlanTool bestTimes
        shoot "$sim" "$out/6_ask.png" 18 "${common[@]}" -askQuestion "$question"
        shoot "$sim" "$out/7_car.png" 9 "${common[@]}" -initialTab car
    done
    xcrun simctl terminate "$sim" $BID 2>/dev/null || true
done

# The search results artwork uses the iPhone Home screen.
for lang in en ro fr; do cp "AppStoreAssets/Source/screens/iphone/$lang/1_home.png" "AppStoreAssets/Source/home_$lang.png"; done
