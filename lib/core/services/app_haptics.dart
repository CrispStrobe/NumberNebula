import 'package:flutter/services.dart';

/// All tactile feedback uses the active player's preference.
class AppHaptics {
  static bool enabled = true;
  static Future<void> lightImpact() =>
      enabled ? HapticFeedback.lightImpact() : Future<void>.value();
  static Future<void> mediumImpact() =>
      enabled ? HapticFeedback.mediumImpact() : Future<void>.value();
  static Future<void> heavyImpact() =>
      enabled ? HapticFeedback.heavyImpact() : Future<void>.value();
  static Future<void> selectionClick() =>
      enabled ? HapticFeedback.selectionClick() : Future<void>.value();
  static Future<void> vibrate() =>
      enabled ? HapticFeedback.vibrate() : Future<void>.value();
}
