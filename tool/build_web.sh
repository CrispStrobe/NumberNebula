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
# A pristine SDK may print bootstrap progress before its machine JSON.
# Parse one complete JSON object; malformed or trailing output still fails.
actual_version=$("$flutter_bin" --version --machine | python3 -c '
import json, sys
raw = sys.stdin.read()
start = raw.find("{")
if start < 0:
    raise SystemExit("Flutter did not report machine JSON")
metadata = json.loads(raw[start:])
version = metadata.get("frameworkVersion") if isinstance(metadata, dict) else None
if not isinstance(version, str) or not version:
    raise SystemExit("Flutter did not report frameworkVersion")
print(version)
')
if [[ "$actual_version" != "$version" ]]; then
  echo "Flutter $version required by .flutter-version; found $actual_version at $flutter_bin" >&2
  exit 1
fi
# Archived validation runners must supply the exact source commit explicitly.
# Resolve separately so a failed Git lookup cannot become an empty build hash.
if [[ ${SOURCE_COMMIT+x} ]]; then
  source_commit="$SOURCE_COMMIT"
else
  git_root=$(git rev-parse --show-toplevel)
  if [[ "$(cd "$git_root" && pwd -P)" != "$(pwd -P)" ]]; then
    echo "Build root is not the Git repository root; set SOURCE_COMMIT for an archived source tree." >&2
    exit 1
  fi
  source_commit=$(git rev-parse --verify HEAD)
fi
if [[ ! "$source_commit" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Expected a full lowercase hexadecimal source commit; set SOURCE_COMMIT for an archived source tree." >&2
  exit 1
fi
"$flutter_bin" pub get
"$flutter_bin" build web --wasm --release --dart-define="GIT_HASH=${source_commit:0:7}" "$@"
