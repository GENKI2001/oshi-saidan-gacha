#!/bin/bash
# Store screenshots from the simulator.
#   tool/screenshots.sh <simulator id> <out dir>
# Runs integration_test/screenshots_test.dart and grabs the screen at every "SHOT <name>".
set -u
sim=$1; out=$2
mkdir -p "$out"
xcrun simctl boot "$sim" 2>/dev/null
# a clean status bar (9:41, full battery and signal)
xcrun simctl status_bar "$sim" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
flutter test integration_test/screenshots_test.dart -d "$sim" --dart-define=RANK_DEMO=true 2>&1 | while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *"SHOT "*)
      name=${line##*SHOT }
      sleep 1.5
      xcrun simctl io "$sim" screenshot "$out/$name.png" >/dev/null 2>&1 && echo "  -> $out/$name.png"
      ;;
  esac
done
xcrun simctl status_bar "$sim" clear
