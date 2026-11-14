#!/bin/bash
# Takes the README screenshots on the simulator: real shaders, a 9:41 status
# bar, light and dark. Builds a debug simulator app once, then relaunches it
# into each state through LaunchHooks (lib/config/launch_hooks.dart).
#   tool/shots.sh            all screens into docs/screens/
set -e
cd "$(dirname "$0")/.."
D="${FLOODLIGHT_DEVICE:-44CDDB86-D61F-47C8-8C65-7C87828A38C5}"
ID=com.flutterzip.floodlight
OUT="$PWD/docs/screens"   # absolute: simctl does not resolve relative paths
mkdir -p "$OUT"
flutter build ios --simulator --debug >/dev/null
xcrun simctl install "$D" build/ios/iphonesimulator/Runner.app
xcrun simctl status_bar "$D" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
DOCS="$(xcrun simctl get_app_container "$D" "$ID" data)/Documents"
mkdir -p "$DOCS"
shot() { # name, state, seconds to wait
  xcrun simctl terminate "$D" "$ID" >/dev/null 2>&1 || true
  printf '%s' "$2" > "$DOCS/launch_start.txt"
  xcrun simctl launch "$D" "$ID" >/dev/null
  sleep "${3:-8}"
  xcrun simctl io "$D" screenshot "$OUT/$1.png" >/dev/null 2>&1
  sips -Z 1300 "$OUT/$1.png" >/dev/null
}
shot onboarding      "fresh,light" 9
shot sign-in         "fresh,light,touch=300/400x92" 10
shot scores          "fresh,signedIn,light"
shot football        "fresh,signedIn,light,open=live:football"
shot lineups         "fresh,signedIn,light,open=live:football,touch=1500/268x387" 10
shot basketball      "fresh,signedIn,light,open=live:basketball"
shot box-score       "fresh,signedIn,light,open=live:basketball,touch=1500/268x387" 10
shot cricket         "fresh,signedIn,light,open=live:cricket"
shot scorecard       "fresh,signedIn,light,open=live:cricket,touch=1500/268x387" 10
shot stats           "fresh,signedIn,light,open=live:football,touch=1500/171x387" 10
shot tables          "fresh,signedIn,light,tab=tables"
shot team            "fresh,signedIn,light,open=team:nga"
shot following       "fresh,signedIn,light,tab=following"
shot picks           "fresh,signedIn,light,tab=following,view=picks"
shot profile         "fresh,signedIn,light,tab=profile" 9
shot scores-dark     "fresh,signedIn,dark"
shot cricket-dark    "fresh,signedIn,dark,open=live:cricket"
shot football-dark   "fresh,signedIn,dark,open=live:football"
xcrun simctl terminate "$D" "$ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$D" clear
echo "screens written to $OUT"
