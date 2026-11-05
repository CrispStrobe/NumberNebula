# GitHub Pages web packaging

The project site is intended for `https://crispstrobe.github.io/NumberNebula/`.
Preparing a package does not enable Pages or deploy it. Publication and browser
results must be recorded against the actual deployed source commit.

Reuse a successful, identified `web-build` artifact from the web validation
workflow. Its compiled JavaScript, WASM, deferred modules, bootstrap, assets,
and `version.json` must remain unchanged. The Pages package changes only the
HTML base URL and adds a `.nojekyll` marker and public provenance metadata.
The original Vercel package keeps its root base URL.

From the repository root, after downloading the validated artifact into
`build/web`, run:

```sh
python3 -m unittest tool.test_prepare_pages -v
python3 tool/prepare_pages.py build/web build/pages --base-href /NumberNebula/
```

`build/pages` must not exist before preparation. The script rejects nested
output directories, symlinks inside the artifact, already-adapted HTML,
multiple or unexpected base elements, external URL values, traversal,
encoded paths, and ambiguous separators. Base paths must start and end with
`/`; case matters. It copies and verifies every original file, preserves
compiled bytes, and writes the complete output directory atomically.
`pages-provenance.json` records the base path, original and adapted HTML hashes,
and SHA-256 hashes for all preserved files. It contains no source directory,
host, account identifier, or credentials. The provenance is evidence of
packaging, not a claim that the deployment or browser tests passed.

The output directory can be supplied to the GitHub Pages artifact upload and
deployment jobs. Publish from the intended validated main commit. Before
publication, exercise the adapted package at `/NumberNebula/` with static
hosting behavior; root-path Vercel browser results alone do not validate the
changed HTML or project path. After publication, verify the actual URL,
version/source identity, cold start, refresh, deferred game loading, and the
changed lessons and hints in Chromium and Firefox. Verify normal JS/WASM MIME
types and that asset requests remain under the project path rather than
falling back to the account root.

## Hosting differences

The app uses relative bootstrap, icon, manifest, and asset URLs.
`manifest.json` starts at `.`. Standard Flutter hash routes work without a
Vercel-style server rewrite; a future switch to path routing would require
separate navigation handling and testing.

Pages does not apply the project's `vercel.json` response-header rules. Do not
claim the Vercel COOP/COEP configuration or cross-origin isolation merely
because the same compiled files were uploaded. The existing strict Vercel
header assertions must stay strict for Vercel; Pages checks must report and
assert their own hosting behavior.

With the pinned Flutter SDK, missing cross-origin isolation does **not** by
itself force JavaScript. Loader selection also considers WasmGC, WebGL, and
browser support. Supported Chromium can use single-thread Skwasm without
isolation; Firefox can use the retained JavaScript/CanvasKit fallback. Record
the actual downloaded main module, renderer, and `crossOriginIsolated` value
for each browser instead of inferring them from a project name or URL.
The app's existing single-thread mitigation and selectable renderer paths
remain intact.

The pinned SDK's generated service worker unregisters itself; this packaging
step preserves that worker. An SDK change that restores asset precaching
requires rechecking whether changing `index.html` also requires updating a
worker manifest. Do not silently reuse this assumption across SDK upgrades.

For a bounded hosted measurement on a configured remote browser runner:

```sh
cd tool/web_live_test
BASE_URL=https://crispstrobe.github.io/NumberNebula/ \
  npx playwright test tests/performance.spec.mjs --retries=0
```

This performance command preserves the project path and records isolation;
it does not replace the game/browser acceptance checks or prove device
performance. No hosting parity, physical-device, or child-playtest claims
follow from packaging or CLI validation.
