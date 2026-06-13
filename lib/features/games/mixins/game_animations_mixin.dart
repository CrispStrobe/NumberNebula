import 'package:flutter/material.dart';

/// Shared animation controllers and animations used across most game screens.
///
/// Games mix this into their State class (which must use
/// [TickerProviderStateMixin]) and call [initGameAnimations] from `initState`
/// and [disposeGameAnimations] from `dispose`.
///
/// Provides three standard animation sets:
///
/// * **Glow** — a slow 2 s oscillation between 0.5 and 1.0 (ambient shimmer).
/// * **Pulse** — a 1 s oscillation between 0.8 and 1.0 (subtle scale bounce).
/// * **Success** — a one-shot 600 ms elastic-out curve (win / correct flash).
///
/// Games that need different parameters should keep their own controllers
/// instead of using this mixin.
mixin GameAnimationsMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  // ── Glow ───────────────────────────────────────────────────────────────
  late AnimationController glowController;
  late Animation<double> glowAnimation;

  // ── Pulse ──────────────────────────────────────────────────────────────
  late AnimationController pulseController;
  late Animation<double> pulseAnimation;

  // ── Success ────────────────────────────────────────────────────────────
  late AnimationController successController;
  late Animation<double> successAnimation;

  /// Call from [initState]. Creates and starts the three standard controllers.
  ///
  /// Pass `useGlow: false`, `usePulse: false`, or `useSuccess: false` to skip
  /// any controller the game doesn't need.
  void initGameAnimations({
    bool useGlow = true,
    bool usePulse = true,
    bool useSuccess = true,
  }) {
    if (useGlow) {
      glowController = AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this,
      )..repeat(reverse: true);
      glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: glowController, curve: Curves.easeInOut),
      );
    }

    if (usePulse) {
      pulseController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      )..repeat(reverse: true);
      pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
      );
    }

    if (useSuccess) {
      successController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      successAnimation = CurvedAnimation(
        parent: successController,
        curve: Curves.elasticOut,
      );
    }
  }

  /// Call from [dispose] to clean up controllers.
  ///
  /// Only disposes controllers that were actually created (matches the
  /// `useGlow` / `usePulse` / `useSuccess` flags passed to
  /// [initGameAnimations]).
  void disposeGameAnimations({
    bool useGlow = true,
    bool usePulse = true,
    bool useSuccess = true,
  }) {
    if (useGlow) glowController.dispose();
    if (usePulse) pulseController.dispose();
    if (useSuccess) successController.dispose();
  }
}
