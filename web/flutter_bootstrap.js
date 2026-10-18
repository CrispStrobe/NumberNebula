{{flutter_js}}
{{flutter_build_config}}

// The pinned engine predates Flutter's shared glyph-cache race repair:
// https://github.com/flutter/flutter/issues/190039
// Keep Skwasm on one thread until an SDK upgrade passes the mixed-game stress
// checks. The explicit opt-in retains the original path for controlled A/B runs.
const useMultipleSkwasmThreads =
  new URLSearchParams(window.location.search).get('skwasmThreads') === 'multi';

_flutter.loader.load({
  config: {
    forceSingleThreadedSkwasm: !useMultipleSkwasmThreads,
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
