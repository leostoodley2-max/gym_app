#!/bin/bash
# Captures App Store-style screenshots and a screen recording of LiftBros using demo mode.
# Requires macOS with Xcode 16+. Output goes to docs/screenshots/.
set -euo pipefail

OUT="${1:-docs/screenshots}"
DEVICE_NAME="${DEVICE_NAME:-iPhone 16 Pro}"
BUNDLE_ID="com.liftbros.app"
mkdir -p "$OUT"

echo "▶ Creating simulator ($DEVICE_NAME)"
UDID=$(xcrun simctl create "LiftBros Shots" "$DEVICE_NAME")
trap 'xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true; xcrun simctl delete "$UDID" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b

echo "▶ Building"
xcodebuild build \
  -project LiftBros.xcodeproj -scheme LiftBros -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build/screens \
  CODE_SIGNING_ALLOWED=NO -quiet
xcrun simctl install "$UDID" build/screens/Build/Products/Debug-iphonesimulator/LiftBros.app

xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

launch() { xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" -LBDemo "$@" >/dev/null; }

# First launch is slow (dyld cache, Charts); warm up so screenshots are consistent.
launch -LBScreen train
sleep 10

echo "▶ Screenshots"
i=1
for screen in onboarding train workout logSet setDetail rankingsGym rankingsUK rankingsP4P lifter progress profile; do
  launch -LBScreen "$screen"
  sleep 6
  file=$(printf "%s/%02d-%s.png" "$OUT" "$i" "$screen")
  xcrun simctl io "$UDID" screenshot --type=png "$file" >/dev/null
  sips --resampleHeightWidthMax 1400 "$file" >/dev/null
  echo "  $file"
  i=$((i + 1))
done

echo "▶ Recording tour"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
sleep 1
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/liftbros-tour.mp4" &
REC_PID=$!
sleep 2
launch -LBTour
sleep 36
kill -INT "$REC_PID"
wait "$REC_PID" || true
ls -lh "$OUT"
