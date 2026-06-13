import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/mixins/game_animations_mixin.dart';

// Minimal widget that uses the mixin for testing.
class _TestWidget extends StatefulWidget {
  final bool useGlow;
  final bool usePulse;
  final bool useSuccess;

  const _TestWidget({
    this.useGlow = true,
    this.usePulse = true,
    this.useSuccess = true,
  });

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget>
    with TickerProviderStateMixin, GameAnimationsMixin<_TestWidget> {
  @override
  void initState() {
    super.initState();
    initGameAnimations(
      useGlow: widget.useGlow,
      usePulse: widget.usePulse,
      useSuccess: widget.useSuccess,
    );
  }

  @override
  void dispose() {
    disposeGameAnimations(
      useGlow: widget.useGlow,
      usePulse: widget.usePulse,
      useSuccess: widget.useSuccess,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

void main() {
  group('GameAnimationsMixin', () {
    testWidgets('creates all three controllers by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: _TestWidget()),
      );

      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));

      // Glow
      expect(state.glowController.duration,
          const Duration(milliseconds: 2000));
      expect(state.glowController.isAnimating, isTrue);
      expect(state.glowAnimation.value, isNotNull);

      // Pulse
      expect(state.pulseController.duration,
          const Duration(milliseconds: 1000));
      expect(state.pulseController.isAnimating, isTrue);
      expect(state.pulseAnimation.value, isNotNull);

      // Success (one-shot — not animating until triggered)
      expect(state.successController.duration,
          const Duration(milliseconds: 600));
      expect(state.successController.isAnimating, isFalse);
      expect(state.successAnimation.value, isNotNull);
    });

    testWidgets('glow animation value stays within expected range',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
            home: _TestWidget(usePulse: false, useSuccess: false)),
      );

      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));

      // Value must always be in the [0.5, 1.0] range defined by the tween.
      final values = <double>[];
      for (int ms = 0; ms < 4000; ms += 100) {
        await tester.pump(const Duration(milliseconds: 100));
        values.add(state.glowAnimation.value);
      }
      expect(values.every((v) => v >= 0.5 && v <= 1.0), isTrue,
          reason: 'glow values out of range: $values');
      // Must oscillate — not stuck at a single value.
      expect(values.toSet().length, greaterThan(1));
    });

    testWidgets('success controller completes after duration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
            home: _TestWidget(useGlow: false, usePulse: false)),
      );

      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));

      expect(state.successController.status, AnimationStatus.dismissed);

      state.successController.forward(from: 0.0);
      // Pump enough frames to complete the 600ms animation.
      await tester.pumpAndSettle();
      expect(state.successController.status, AnimationStatus.completed);
    });

    testWidgets('disposes cleanly without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: _TestWidget()),
      );

      // Removing the widget triggers dispose.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // No exception = success.
    });

    testWidgets('skips controllers when flags are false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _TestWidget(useGlow: false, usePulse: false, useSuccess: false),
        ),
      );

      // Widget should build without errors even with no controllers.
      expect(find.byType(_TestWidget), findsOneWidget);

      // Removing it should also dispose cleanly.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });
}
