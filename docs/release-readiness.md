# Store release readiness

Prepared 2026-10-16. Documentation only — no version bump, no upload, no submission.

This is the lane R readiness artifact for the current codebase at **1.5.22+38** (`8eaf252bc86dfc7e44bb219613e60f2bd3450e7c`, see [HANDOVER.md](../HANDOVER.md)). It records what the release automation *does*, how `pubspec.yaml` version/build maps to Apple builds, what notes would ship with this code, and what must be rechecked in the authorized App Store Connect account before any action. It explicitly does **not** claim the historical **1.4.10** “Waiting for Review” (iOS) / “Pending Developer Release” (macOS) labels are current. Web deployment is already green at the baseline (see HANDOVER.md).

No account identifiers, API keys, certificates, or machine-local instructions are included. Verify the live store state in the authorized App Store Connect portal before deciding what can be released.

## 1. Version and build mapping (single source of truth)

`pubspec.yaml:4`:

```yaml
version: 1.5.22+38
#        ^^^^^^^ ^^^
#        |       └─ build number → CFBundleVersion (BUILD_NUMBER)
#        └────────── marketing version → CFBundleShortVersionString (APP_VERSION)
```

Flutter propagates these to both native projects:

* **iOS** `ios/Runner/Info.plist` and **macOS** `macos/Runner/Info.plist` both declare `CFBundleShortVersionString = $(FLUTTER_BUILD_NAME)` and `CFBundleVersion = $(FLUTTER_BUILD_NUMBER)`. Xcode project sets `CURRENT_PROJECT_VERSION = $(FLUTTER_BUILD_NUMBER)`.
* `.flutter-version` pins the SDK (currently `3.44.1`); `release.yml` reads it at runtime (`Read Flutter SDK pin`).
* `dart_csp` is pinned to tag `v2.2.0` in both `pubspec.yaml` and `tool/pure_dart/pubspec.yaml` — a tag, not a dangling SHA (see [HISTORY.md](../HISTORY.md) Vercel fix).

**Build-number rule:** Apple rejects a duplicate `CFBundleVersion` for a given `APP_VERSION`. Before tagging a release, the build number in `pubspec.yaml` must be bumped (e.g., `tool/bump_version.dart build` or `tool/bump_version.dart --set 1.5.23+39`). CI does not auto-bump; a PR touching `lib/`, `assets/`, or `pubspec.yaml` without a version change fails the `version-bump` job.

## 2. What the workflows do

| Workflow | File | Trigger | What it does | What it does NOT do |
| --- | --- | --- | --- | --- |
| **Release** | `.github/workflows/release.yml` | `push` tag `v*` → build + upload; `workflow_dispatch` with `dry_run: true` (default) → build + sign only | Two independent jobs: `build-upload` (iOS IPA via manual-signing `xcodebuild archive` + `exportArchive` with `ExportOptions.plist`) and `build-upload-macos` (Mac `.pkg` via `xcodebuild archive` with `CODE_SIGN_STYLE=Manual` + `exportArchive` with `ExportOptionsMac.plist`). Both read `version:` from `pubspec.yaml` for `bundle-version` / `bundle-short-version-string` and upload with `xcrun altool` using the App Store Connect API key from repo secrets. On a tag, hands off to `submit.yml` with `lane: testflight`. | Does not submit for App Store review. Does not create the App Store version record. Tag ⇒ TestFlight only. |
| **Submit** | `.github/workflows/submit.yml` | `workflow_call` from `release.yml`, or manual `workflow_dispatch` with `platforms` in `[ios, osx]` and `lane` in `testflight` / `status` / `appstore_submit` | `fastlane/Fastfile` lanes: `testflight` waits for processing, submits for Beta App Review, and distributes to every external TestFlight group; `status` is read-only; `appstore_submit` attaches the build to the App Store version and submits for review. Reads `APP_VERSION`/`BUILD_NUMBER` from `pubspec.yaml` unless overridden. Two platforms are serialized (`max-parallel: 1`) to avoid App Store version-record races. | A tagged release never calls `appstore_submit`. Review submission is a deliberate manual run: `gh workflow run submit.yml -f lane=appstore_submit -f platforms='["ios"]'` (or `osx` / both). |

**Key design decisions captured in the workflows:**

* iOS archives with `CODE_SIGNING_ALLOWED=NO` then signs at export; macOS signs at archive so the sandbox entitlement is present (otherwise `altool` rejects with “App sandbox not enabled”). No `allowProvisioningUpdates` — the Distribution cert and provisioning profiles are imported from repo secrets into a throwaway keychain.
* macOS validation (`altool --validate-app`) runs before upload to catch missing `LSApplicationCategoryType` or bad entitlements without creating a dud build record.
* Artifact upload (`upload-artifact` for `.ipa`/`.pkg`) is `continue-on-error: true` — a full artifact-storage quota must not kill a good upload.
* IPA/`.pkg` secrets required by `release.yml`: `ASC_API_KEY_P8_BASE64`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_APP_ID`, `ASC_TEAM_ID`, `DIST_CERT_P12_BASE64`, `DIST_CERT_PASSWORD`, `ASC_PROFILE_BASE64`, `MAC_DIST_P12`, `MAC_DIST_P12_PASSWORD`, `MAC_PROFILE_BASE64`. Optional repo variables `BETA_CONTACT_EMAIL` etc. supply Beta App Review contact; if unset the existing app-record contact is reused.
* Any App Store **review** submission that was once automated is now intentionally manual. Both `release.yml:347-355` and `submit.yml:1-12` document the reason:

> The app carries an open **4.3(a) (Design: Spam)** rejection from **2026-09-12** and an **Extended Review** notice warning that repeated submissions risk removal from the Apple Developer Program.

Do not re-enable auto-submit for review as drive-by cleanup. Use the authorized release policy and a manual `appstore_submit` run only.

## 3. Candidate build for distribution

| Fact | Value |
| --- | --- |
| **Commit that would be uploaded** | `8eaf252bc86dfc7e44bb219613e60f2bd3450e7c` on `main` (`origin/main`), version **1.5.22+38** — `1.5.22` marketing, build `38` |
| **Verified state on that commit** | Flutter analyze + 1,471 tests (2 skips) · 60,400 pure Dart boards (0 failures) · WASM/JS build + 864 capture/replay + production deploy — see [HANDOVER.md](../HANDOVER.md) for run links. No new native-device profiling claimed. |
| **What changed since the last tagged store build (1.4.10+14, tag `v1.4.10`)** | Focused round-lifecycle audits for 20 games (PRs [#29](https://github.com/CrispStrobe/NumberNebula/pull/29)–[#46](https://github.com/CrispStrobe/NumberNebula/pull/46)): stale-input/timer/drag/completion guards, recoverable saved-session handling, duplicate-outcome prevention, reduced-motion respect (initial + mid-animation), and EN/DE phone-layout fixes. Candidate solver paths (Square/Crossword/Cargo/Robot/Launch) and every-level calibration (60,400 boards) are included. See [HISTORY.md](../HISTORY.md) 2026-10-05 entry. |
| **Would Apple accept the build number?** | Only if build `38` has not been used for marketing version `1.5.22` on a given platform. Verify in App Store Connect → TestFlight → Builds for iOS and macOS separately before tagging; bump if the pair `(1.5.22, 38)` already exists. |

If a different commit is to be distributed, bump the build number on *that* commit and re-verify green CI at the exact head.

## 4. Platform readiness table

Recheck every row in the **authorized** App Store Connect account before acting. The table lists what is *known from the repository* vs. what requires a live account check. Do not treat the old 1.4.10 labels as evidence of the current store state.

| Platform | Workflow / artifact | Version mapping | Store state — repository view | Store state — requires live check | Release readiness | Next authorized step |
| --- | --- | --- | --- | --- | --- | --- |
| **iOS** (iPhone/iPad) | `release.yml` job `build-upload` → `build/ios/ipa/*.ipa` → `altool --upload-package --type ios` | `1.5.22` → `CFBundleShortVersionString`, `38` → `CFBundleVersion` (via `pubspec.yaml`). `ExportOptions.plist` `manageAppVersionAndBuildNumber: false`. | Historical note only: 1.4.10 was once reported as “Waiting for Review” — **stale, unverified now**. No current state is claimed here. | Re-check in App Store Connect: current TestFlight builds for bundle `com.crispstrobe.numbernebula`, current App Store version and its review state, and whether build `38` is already consumed for `1.5.22`. Use `submit.yml` `lane: status` or the console. | **Code ready, store unknown.** Green CI on the upload candidate; IPA signing is reproducible via `dry_run`. App cannot be released until the live state is confirmed and the 4.3(a)/Extended Review posture is acknowledged. | If cleared: ensure build number is unused, tag `v1.5.22` (or next version) to trigger `release.yml`; then `submit.yml` auto-distributes to external TestFlight. Review submission — if pursued at all — is a separate manual `lane: appstore_submit` decision under the authorized policy. |
| **macOS** (Mac App Store) | `release.yml` job `build-upload-macos` → `build/macos/pkg/*.pkg` → `altool --validate-app` then `--upload-package --type macos` | Same `pubspec.yaml` → `CFBundleShortVersionString`/`CFBundleVersion`. `ExportOptionsMac.plist` includes `installerSigningCertificate: 3rd Party Mac Developer Installer`. | Historical note only: 1.4.10 was once reported as “Pending Developer Release” — **stale, unverified now**. No current state is claimed here. | Same live check as iOS but on the macOS platform record (separate TestFlight builds, separate App Store version). | **Code ready, store unknown.** Same green baseline; `.pkg` validation catches entitlement/category faults before upload. | Same as iOS, independently. iOS and macOS jobs are deliberately independent so a macOS-only failure never blocks iOS (and vice versa). |
| **Web** | Vercel auto-deploy from `main` + `.github/workflows/web-perf.yml` + `vercel.json` build `tool/build_web.sh` | Web does not use `CFBundleVersion`; the deployed commit is the main head. | **Green at baseline** per [HANDOVER.md](../HANDOVER.md): WASM/JS fallback, 864 capture/replay, Chromium/Firefox smoke, production deployment and hosted checks. Canonical URL `numbernebula.vercel.app` (see `README.md`). | Verify the live deployment matches the intended commit (Vercel dashboard / `vercel.json` output `build/web`). | **Ready and deployed.** No App Store action needed. | No action unless web assets or routing change. Preserve the web-perf gate on each PR. |
| **Android** | No store workflow in this repository | `pubspec.yaml` version is not published to a store from CI in this repo | No Android release is claimed. No Play Console state is available here. | If Android distribution is ever pursued, verify Play Console track state separately — not covered by `release.yml`/`submit.yml`. | **Not submitted.** | No operation is authorized by this document. |

**How upload, review, and developer release differ:**

* **Upload** (`release.yml`) = binary appears in App Store Connect → TestFlight internal. No human sees it.
* **TestFlight external** (`submit.yml lane: testflight`) = wait for processing + Beta App Review + external groups. This is what a tag does.
* **App Store review submission** (`submit.yml lane: appstore_submit`) = attach build to the App Store version record and send to App Review. Manual only; gated by the 4.3(a) rejection and Extended Review notice.
* **Developer release** (`AUTOMATIC_RELEASE = false` in `fastlane/Fastfile`) = even after approval, the release goes live only when a human presses the button in App Store Connect.

Never conflate “uploaded” with “approved” or “live”.

## 5. Release notes for the current code (draft, publishable without account exposure)

These notes describe what a tester would see if build `38` were distributed via TestFlight. They are safe to publish: no account IDs, keys, or machine notes. The file that ships to App Store Connect is `fastlane/metadata/en-US/release_notes.txt` — replace its current 1.4-era text with the version below when a distribution is intentionally triggered.

> **NumberNebula 1.5.22 — stability, accessibility, and learning feedback**
>
> * Across all 48 mini-games: puzzles now resume correctly after interruptions — restored boards keep your progress, timers pause during hints and coaching, and a finished board clears its saved snapshot so it does not replay rewards. Reduced-motion and mid-animation settings are respected, and English/German layouts remain reachable on phone screens including 390×500 with large text.
> * Smoother practice flow: sibling profiles keep each learner’s progress, spaced-review and cognitive-profile data, missions, and saved boards separate. The parent dashboard shows weekly progress from comparable completed rounds and offers a practice suggestion — no new data leaves the device.
> * Learning feedback: every completed round now records a measured performance signal and shows a result summary with moves/hints where applicable. Coaching is available from the current board across all 48 games.
> * Under the hood: expanded headless generation checks (60,400 boards across all 48 games, six grades, all 20 levels) and WASM/JS web verification remain green. No new in-app purchase or network collection has been added.
>
> As always: nothing is uploaded, no account is required, and progress stays on-device. If anything feels off, Settings → Diagnostics lets you copy a local log to share voluntarily.

Keep the notes factual and short — App Store Connect truncates long TestFlight changelogs.

## 6. Pre-flight checklist (must be done in the authorized session)

Before tagging or submitting, the authorized operator must re-verify:

- [ ] App Store Connect → **iOS** → TestFlight builds → is there already a build `38` for version `1.5.22`? If yes, bump `pubspec.yaml` build number before tagging.
- [ ] Same for **macOS** → TestFlight builds (separate from iOS — same marketing version, independent build record).
- [ ] App Store version state for iOS and macOS: current review state is **not** 1.4.10 “Waiting for Review” / “Pending Developer Release” — confirm the actual state via `lane: status` or console.
- [ ] Acknowledge the **4.3(a) rejection** (2026-09-12) and **Extended Review** notice: review submission (`appstore_submit`) is a deliberate manual choice, not an automatic tag side-effect.
- [ ] `fastlane/metadata/en-US/release_notes.txt` contains the 1.5.22 notes above (or the final approved wording) before the `submit.yml` TestFlight step reads it.
- [ ] CI is green at the **exact tag head**: `ci.yml` (analyze+tests), `pure-calibration.yml` (fixture replay), `web-perf.yml`/`hosted-performance.yml` (deployed site checks). Do not rely on “workflow exists” — require passing runs at that head.
- [ ] `vercel.json` + `tool/build_web.sh` web deployment still matches `main` (spot-check the live site).

No tag, upload, or review submission is authorized by this document alone.

## 7. References

* Workflows: `.github/workflows/release.yml`, `.github/workflows/submit.yml`, `.github/workflows/ci.yml`, `.github/workflows/pure-calibration.yml`
* Version source: `pubspec.yaml`, `tool/bump_version.dart`, `fastlane/Fastfile` (`AUTOMATIC_RELEASE = false`), `fastlane/metadata/en-US/release_notes.txt`
* Baseline evidence: [HANDOVER.md](../HANDOVER.md) (1.5.22+38, `8eaf252...`), [pure Dart calibration](pure-dart-calibration.md), [optimization validation](optimization-validation.md), [REMAINING_WORK.md](../REMAINING_WORK.md) lanes H and R, [HISTORY.md](../HISTORY.md)
* Live verification points: numbernebula.vercel.app (web), App Store Connect / TestFlight (iOS, macOS — authorized account only)

No synthetic child data, device measurements, or deployment outcomes are claimed. Historical 1.4.10 store labels are not current evidence.
