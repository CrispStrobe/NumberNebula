import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/widgets/space_background.dart';

Future<Uint8List> _pixels(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final result = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(
          data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } finally {
      image.dispose();
    }
  });
  return result!;
}

bool _samePixels(Uint8List first, Uint8List second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

void _expectEquivalentPixels(Uint8List legacy, Uint8List cached, String label) {
  expect(cached.length, legacy.length, reason: label);
  var maximumDelta = 0;
  var changedChannels = 0;
  for (var index = 0; index < legacy.length; index++) {
    final delta = (legacy[index] - cached[index]).abs();
    if (delta > maximumDelta) maximumDelta = delta;
    if (delta != 0) changedChannels++;
  }
  expect(maximumDelta, lessThanOrEqualTo(2),
      reason: '$label: $changedChannels/${legacy.length} channels differ; '
          'local-origin shader translation may round by at most 2/255');
}

Widget _host(Widget child, {bool reducedMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

void main() {
  testWidgets('background default obeys the compile-time rendering selector',
      (tester) async {
    const boundaryKey = ValueKey('default-background');
    await tester.pumpWidget(_host(const Center(
      child: SizedBox(
        width: 240,
        height: 160,
        child: RepaintBoundary(
          key: boundaryKey,
          child: SpaceBackground(child: SizedBox.expand()),
        ),
      ),
    )));
    await tester.pump();
    final paint = find.descendant(
        of: find.byType(SpaceBackground), matching: find.byType(CustomPaint));
    expect(paint, findsOneWidget);
    final originalPaint = tester.widget<CustomPaint>(paint);
    final before = await _pixels(tester, boundaryKey);
    const selector = String.fromEnvironment('SPACE_BACKGROUND_RENDER_PATH',
        defaultValue: 'cached');
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
      expect(identical(tester.widget<CustomPaint>(paint), originalPaint),
          selector == 'cached',
          reason:
              'The actual default path must follow the compile-time selector');
    }
    expect(_samePixels(await _pixels(tester, boundaryKey), before), isFalse,
        reason: 'Both default paths must preserve animated decoration');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'cached background preserves legacy pixels across themes and resize',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const legacyKey = ValueKey('legacy-background-pixels');
    const cachedKey = ValueKey('cached-background-pixels');
    const sizes = [Size(150, 210), Size(270, 150)];

    for (final theme in [null, 'solarpanel', 'comm_relay']) {
      for (final size in sizes) {
        await tester.pumpWidget(_host(Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final path in SpaceBackgroundRenderPath.values)
              SizedBox(
                width: size.width,
                height: size.height,
                child: RepaintBoundary(
                  key: path == SpaceBackgroundRenderPath.legacy
                      ? legacyKey
                      : cachedKey,
                  child: SpaceBackground(
                    gameKey: theme,
                    renderingPath: path,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
          ]),
        )));
        // Both sibling controllers share the same clock, including after
        // changing palette and constraints on their existing states.
        for (final elapsed in [
          Duration.zero,
          const Duration(milliseconds: 700)
        ]) {
          await tester.pump(elapsed);
          _expectEquivalentPixels(await _pixels(tester, legacyKey),
              await _pixels(tester, cachedKey), '$theme $size $elapsed');
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cached background repaints without rebuilding or blocking play',
      (tester) async {
    const boundaryKey = ValueKey('cached-background');
    const foregroundKey = ValueKey('background-foreground');
    var taps = 0;
    final foreground = GestureDetector(
      key: foregroundKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => taps++,
      child: const SizedBox.expand(),
    );
    Widget app({bool reduced = false, bool animate = true}) => _host(
          Center(
            child: SizedBox(
              width: 240,
              height: 160,
              child: RepaintBoundary(
                key: boundaryKey,
                child: SpaceBackground(
                  renderingPath: SpaceBackgroundRenderPath.cached,
                  animate: animate,
                  child: foreground,
                ),
              ),
            ),
          ),
          reducedMotion: reduced,
        );

    await tester.pumpWidget(app());
    await tester.pump();
    final paint = find.descendant(
        of: find.byType(SpaceBackground), matching: find.byType(CustomPaint));
    expect(paint, findsOneWidget);
    final originalPaint = tester.widget<CustomPaint>(paint);
    final initialPixels = await _pixels(tester, boundaryKey);
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<CustomPaint>(paint), same(originalPaint),
          reason: 'Decoration ticks must repaint without rebuilding widgets');
      expect(tester.widget(find.byKey(foregroundKey)), same(foreground));
    }
    expect(
        _samePixels(await _pixels(tester, boundaryKey), initialPixels), isFalse,
        reason: 'Removing decoration builds must preserve animated rendering');
    await tester.tap(find.byKey(foregroundKey));
    expect(taps, 1, reason: 'The decoration must not intercept gameplay taps');

    await tester.pumpWidget(app(reduced: true));
    await tester.pump();
    final reducedPixels = await _pixels(tester, boundaryKey);
    expect(tester.binding.transientCallbackCount, 0,
        reason: 'Reduced motion must stop the decorative ticker');
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(milliseconds: 900));
    expect(
        _samePixels(await _pixels(tester, boundaryKey), reducedPixels), isTrue);

    await tester.pumpWidget(app(animate: false));
    await tester.pump();
    expect(
        _samePixels(await _pixels(tester, boundaryKey), reducedPixels), isTrue,
        reason:
            'Reduced motion and animate:false both render static phase zero');
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(milliseconds: 900));
    expect(
        _samePixels(await _pixels(tester, boundaryKey), reducedPixels), isTrue);

    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        _samePixels(await _pixels(tester, boundaryKey), reducedPixels), isFalse,
        reason: 'Re-enabling decoration must resume motion');
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    expect(tester.widget(find.byKey(foregroundKey)), same(foreground));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
