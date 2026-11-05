#!/usr/bin/env bash
# Compare final original-API contracts with the unchanged pre-repair screen.
set -euo pipefail
screen=lib/features/games/screens/space_station_gridlock_game.dart
report=build/gridlock-audit
mkdir -p "$report"
fixed=$(mktemp)
cp "$screen" "$fixed"
trap 'cp "$fixed" "$screen"; rm -f "$fixed"' EXIT
baseline=32383b40e93f9e84dd7f8a69dc59dcb68f8c6203
git fetch --no-tags --depth=1 origin "$baseline"
git show "$baseline:$screen" > "$report/baseline-screen.dart"
cp "$report/baseline-screen.dart" "$screen"
set +e
flutter test test/widgets/space_station_gridlock_round_test.dart --concurrency=1 --reporter expanded --file-reporter "json:$report/baseline.json" > "$report/baseline.log" 2>&1
status=$?
set -e
cp "$fixed" "$screen"
python3 tool/verify_gridlock_baseline.py "$status"
