#!/usr/bin/env bash
# Summarise a Flutter web build's download sizes.
#
# Usage: tool/web_size_report.sh [build/web] [out.json]
#
# Prints a Markdown table (raw and gzip sizes of the compiled app, every
# deferred part, CanvasKit and assets) and writes the same numbers as JSON so
# two builds can be compared. "Initial" is what a first visit downloads before
# the menu appears: bootstrap, the main app module and the fonts/manifests;
# deferred parts are only fetched when a game is opened.
set -euo pipefail

dir="${1:-build/web}"
out="${2:-}"

gz() { gzip -9 -c "$1" | wc -c; }
kb() { awk -v b="$1" 'BEGIN { printf "%.1f", b / 1024 }'; }

rows=()
json_rows=()
add() { # label path
  local label="$1" path="$2"
  [ -f "$path" ] || return 0
  local raw zipped
  raw=$(wc -c < "$path")
  zipped=$(gz "$path")
  rows+=("| $label | ${path#"$dir"/} | $(kb "$raw") | $(kb "$zipped") |")
  json_rows+=("{\"label\":\"$label\",\"path\":\"${path#"$dir"/}\",\"bytes\":$raw,\"gzip\":$zipped}")
}

add "main (wasm)" "$dir/main.dart.wasm"
add "main (js)" "$dir/main.dart.js"
add "bootstrap" "$dir/flutter_bootstrap.js"
add "index" "$dir/index.html"

# Deferred parts: dart2js writes main.dart.js_N.part.js, dart2wasm writes
# extra .wasm modules next to main.dart.wasm.
deferred_js=0 deferred_wasm=0
while IFS= read -r f; do
  add "deferred (js)" "$f"
  deferred_js=$((deferred_js + 1))
done < <(find "$dir" -maxdepth 1 -name 'main.dart.js_*.part.js' | sort -V)
while IFS= read -r f; do
  add "deferred (wasm)" "$f"
  deferred_wasm=$((deferred_wasm + 1))
done < <(find "$dir" -maxdepth 1 -name '*.wasm' ! -name 'main.dart.wasm' | sort -V)

assets_bytes=$(du -sb "$dir/assets" | cut -f1)
canvaskit_bytes=$(du -sb "$dir/canvaskit" 2>/dev/null | cut -f1 || echo 0)
total_bytes=$(du -sb "$dir" | cut -f1)

{
  echo "| Kind | File | KiB | gzip KiB |"
  echo "|---|---|---:|---:|"
  printf '%s\n' "${rows[@]}"
  echo
  echo "Deferred parts: ${deferred_js} js, ${deferred_wasm} wasm."
  echo "assets/: $(kb "$assets_bytes") KiB · canvaskit/: $(kb "$canvaskit_bytes") KiB · whole build: $(kb "$total_bytes") KiB"
}

if [ -n "$out" ]; then
  {
    echo "{"
    echo "  \"files\": [$(IFS=,; echo "${json_rows[*]}")],"
    echo "  \"deferredJs\": $deferred_js, \"deferredWasm\": $deferred_wasm,"
    echo "  \"assetsBytes\": $assets_bytes, \"canvaskitBytes\": $canvaskit_bytes, \"totalBytes\": $total_bytes"
    echo "}"
  } > "$out"
fi
