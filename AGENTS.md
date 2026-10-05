# Repository agent instructions

Read [HANDOVER.md](HANDOVER.md), then [REMAINING_WORK.md](REMAINING_WORK.md).
The registered game inventory lives in `lib/features/games/game_registry.dart`;
this is a Flutter app with shared pure Dart generators for 48 registered games.

## Working constraints

- Inspect the working tree and remote head before editing; preserve unrelated work.
- Check average load, available memory and disk space before substantial local jobs.
  Keep local work to inspection, edits and small checks. Run large calibration,
  full suites, WASM builds and browser validation on GitHub Actions or a configured
  remote runner. Do not overlap heavy local jobs or disturb other users' processes.
- Preserve working algorithms, selectable A/B paths and fallbacks.
- Test actual input, restored rounds, outcomes and initial/mid-animation reduced
  motion. Keep session persistence and learning records correct after mistakes.
- Shipping-code changes require a version/build increase; docs-only changes do not.
- Verify checks on the exact pushed head and again on merged main, including
  deployment. Record public run links rather than assuming a configured job passed.
- Keep local paths, host/account details, credentials and private operational notes
  outside repo-public Markdown. Use public URLs and repository-relative paths.
- Use the existing deployment-compatible Git identity configured for the task.

Remote runner commands, with the pinned SDK on PATH:

```sh
flutter pub get
flutter analyze --fatal-infos
flutter test --concurrency=2 --reporter expanded
bash tool/build_web.sh
```

For pure Dart commands and bounded larger samples, read
[docs/pure-dart-calibration.md](docs/pure-dart-calibration.md).
