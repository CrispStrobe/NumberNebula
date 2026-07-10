#!/usr/bin/env bash
#
# Capture App Store screenshots with no physical device and no manual tapping.
#
# Drives the real app via the integration_test harness
# (integration_test/screenshots_test.dart), which navigates home -> menu -> a
# game and HOLDS each screen while printing `SHOT_MARKER <name>`. This script
# watches for those markers and grabs native-resolution pixels with
# `xcrun simctl io screenshot`, then rotates them to landscape (the app is
# landscape-locked on iPhone, so simctl captures a portrait buffer).
#
# Usage:
#   xcrun simctl boot <sim-udid>          # e.g. an iPhone 17 Pro Max
#   tool/capture_screenshots.sh <sim-udid> [locale]
#
# Notes:
#  * `env -u GEM_HOME -u GEM_PATH -u RUBYOPT` works around a CocoaPods/Ruby
#    version mismatch on this machine (flutter's pod install otherwise fails).
#  * `/usr/bin` is prepended to PATH so Xcode uses the system rsync (a
#    Homebrew rsync without xattr support breaks the packaging step).
set -uo pipefail

DEVICE="${1:?usage: capture_screenshots.sh <sim-udid> [locale]}"
LOCALE="${2:-en-US}"
DIR="fastlane/screenshots/$LOCALE"
mkdir -p "$DIR"

LOG="$(mktemp -t sma_shots)"
PATH="/usr/bin:$PATH" env -u GEM_HOME -u GEM_PATH -u RUBYOPT \
  flutter test integration_test/screenshots_test.dart -d "$DEVICE" >"$LOG" 2>&1 &
TEST_PID=$!

tail -f "$LOG" 2>/dev/null | while IFS= read -r line; do
  case "$line" in
    *SHOT_MARKER*)
      name=$(printf '%s' "$line" | sed -n 's/.*SHOT_MARKER \([a-z0-9]*\).*/\1/p')
      [ -z "$name" ] && continue
      xcrun simctl io "$DEVICE" screenshot "$DIR/iphone-$name.png" >/dev/null 2>&1 \
        && echo "captured $name"
      ;;
    *"All tests passed"*|*"Some tests failed"*|*"Unable to start"*)
      echo "$line"; break ;;
  esac
done

wait "$TEST_PID" 2>/dev/null || true

# Rotate any portrait-buffer captures to upright landscape.
for f in "$DIR"/iphone-*.png; do
  [ -e "$f" ] || continue
  w=$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/{print $2}')
  if [ -n "$w" ] && [ -n "$h" ] && [ "$h" -gt "$w" ]; then
    sips -r 270 "$f" >/dev/null 2>&1
  fi
done

echo "Screenshots written to $DIR"
