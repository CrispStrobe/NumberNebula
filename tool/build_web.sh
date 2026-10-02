#!/usr/bin/env bash
set -euo pipefail
# Use the same pinned SDK for local, CI and Vercel builds.
version=$(tr -d '[:space:]' < .flutter-version)
if [[ -n "${FLUTTER_BIN:-}" ]]; then
  flutter_bin="$FLUTTER_BIN"
else
  if [[ ! -x flutter/bin/flutter ]]; then
    git clone --depth 1 --branch "$version" https://github.com/flutter/flutter.git flutter
  fi
  flutter_bin=./flutter/bin/flutter
fi
actual_version=$("$flutter_bin" --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')
if [[ "$actual_version" != "$version" ]]; then
  echo "Flutter $version required by .flutter-version; found $actual_version at $flutter_bin" >&2
  exit 1
fi
"$flutter_bin" pub get
"$flutter_bin" build web --wasm --release --dart-define="GIT_HASH=$(git rev-parse --short HEAD)" "$@"
