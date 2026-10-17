// lib/core/utils/app_logger.dart
//
// Central debug logger. No output in release builds (kDebugMode = false).
// Keeps diagnostic chatter out of store builds while preserving it for
// local runs and CI. Verbose callers (generators, combat sims) must pass
// their own `enabled` flag in addition to the debug gate.

import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  /// Always emitted in debug, silent in release/profile.
  static void debug(String message, {String tag = 'App'}) {
    if (kDebugMode) debugPrint('[$tag] $message');
  }

  /// Gated by both kDebugMode and a runtime verbose flag.
  static void verbose(String message,
      {required bool enabled, String tag = 'App'}) {
    if (kDebugMode && enabled) debugPrint('[$tag] $message');
  }
}
