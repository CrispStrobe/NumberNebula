#!/usr/bin/env bash
# Wrap a finished Flutter web build as a Vercel Build Output (v3) directory so
# it can be deployed with `vercel deploy --prebuilt`, without Vercel
# downloading Flutter and rebuilding.
#
# Usage: tool/vercel_prebuilt.sh [build/web]
#
# Writes .vercel/output/{config.json,static/}. The routes reproduce
# vercel.json: its headers on every response, files first, then the rewrite
# of everything else to index.html.
set -euo pipefail

web="${1:-build/web}"
out=.vercel/output

rm -rf "$out"
mkdir -p "$out/static"
cp -R "$web"/. "$out/static/"
# Source maps are for CI debugging only.
find "$out/static" -name '*.map' -delete

python3 - "$out/config.json" <<'EOF'
import json, sys

vercel = json.load(open('vercel.json'))
routes = []
for rule in vercel.get('headers', []):
    routes.append({
        'src': rule['source'],
        'headers': {h['key']: h['value'] for h in rule['headers']},
        'continue': True,
    })
routes.append({'handle': 'filesystem'})
for rule in vercel.get('rewrites', []):
    routes.append({'src': rule['source'], 'dest': rule['destination']})

json.dump({'version': 3, 'routes': routes}, open(sys.argv[1], 'w'), indent=2)
EOF

echo "Prebuilt output in $out ($(du -sh "$out/static" | cut -f1))"
