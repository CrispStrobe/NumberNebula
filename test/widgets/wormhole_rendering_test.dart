import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/magic_triangles_game.dart';
import 'package:space_math_academy/features/games/widgets/magic_triangle_painters.dart';
import 'package:space_math_academy/generated/l10n.dart';

Future<Uint8List> _raster(
    WidgetTester tester, CustomPainter painter, Size size, double dpr) async {
  final result = await tester.runAsync(() async {
    // Preserve effects outside the nominal painter bounds: the disk slightly
    // overhangs a square, and energy/warp strokes have blurred edges.
    const padding = 48.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(dpr)
      ..translate(padding, padding);
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
          ((size.width + padding * 2) * dpr).ceil(),
          ((size.height + padding * 2) * dpr).ceil());
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return Uint8List.fromList(
            data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  });
  return result!;
}

Future<Uint8List> _widgetPixels(WidgetTester tester, Key key) async {
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

void _expectPixels(Uint8List legacy, Uint8List candidate, String label,
    {int tolerance = 2}) {
  expect(candidate.length, legacy.length, reason: label);
  var maximumDelta = 0;
  var changedChannels = 0;
  for (var index = 0; index < legacy.length; index++) {
    final delta = (legacy[index] - candidate[index]).abs();
    if (delta > maximumDelta) maximumDelta = delta;
    if (delta != 0) changedChannels++;
  }
  expect(maximumDelta, lessThanOrEqualTo(tolerance),
      reason: '$label: $changedChannels/${legacy.length} RGBA channels differ; '
          'rotational gradient rounding is limited to $tolerance/255');
}

class _AnimatedHarness extends StatefulWidget {
  const _AnimatedHarness({super.key});

  @override
  State<_AnimatedHarness> createState() => _AnimatedHarnessState();
}

class _AnimatedHarnessState extends State<_AnimatedHarness>
    with TickerProviderStateMixin {
  final cache = WormholeRenderCache();
  late final AnimationController glow;
  late final AnimationController time;
  late final AnimationController warp;
  late final AnimatedWormholePainter painter;
  int builds = 0;
  int taps = 0;

  @override
  void initState() {
    super.initState();
    glow = AnimationController(vsync: this, value: 0.5);
    time =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    warp = AnimationController(vsync: this);
    painter = AnimatedWormholePainter(
        glowIntensity: glow,
        time: time,
        warpActivation: warp,
        renderCache: cache);
  }

  @override
  void dispose() {
    glow.dispose();
    time.dispose();
    warp.dispose();
    cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    builds++;
    return CustomPaint(
      painter: painter,
      child: Semantics(
        label: 'Puzzle controls',
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
      'wormhole cache preserves every draw layer across phase, size and DPR',
      (tester) async {
    final cache = WormholeRenderCache();
    addTearDown(cache.dispose);
    // Revisit the original size with the same cache to catch stale geometry.
    for (final size in [
      const Size(160, 160),
      const Size(240, 180),
      const Size(160, 160)
    ]) {
      for (final dpr in [1.0, 2.0]) {
        for (final time in [0.0, 0.25, 0.5, 0.9]) {
          for (final state in [
            (glow: 0.5, warp: 0.0),
            (glow: 0.75, warp: 0.25),
            (glow: 1.0, warp: 0.75),
            (glow: 0.5, warp: 1.0),
          ]) {
            final legacy = WormholePainter(
                glowIntensity: state.glow,
                time: time,
                warpActivation: state.warp);
            final candidate = WormholePainter(
                glowIntensity: state.glow,
                time: time,
                warpActivation: state.warp,
                renderCache: cache);
            _expectPixels(
                await _raster(tester, legacy, size, dpr),
                await _raster(tester, candidate, size, dpr),
                '$size DPR$dpr time$time glow${state.glow} warp${state.warp}');
          }
        }
      }
    }
  });

  testWidgets(
      'wormhole cache survives repeated painting, disposal and recreation',
      (tester) async {
    final cache = WormholeRenderCache();
    addTearDown(cache.dispose);
    WormholePainter painter({WormholeRenderCache? resources}) =>
        WormholePainter(
            glowIntensity: 0.8,
            time: 0.65,
            warpActivation: 0.6,
            renderCache: resources);
    const size = Size(190, 220);
    final first = await _raster(tester, painter(resources: cache), size, 2);
    final second = await _raster(tester, painter(resources: cache), size, 2);
    _expectPixels(first, second, 'Repeated cache use', tolerance: 0);
    cache.dispose();
    cache.dispose();
    final recreated = await _raster(tester, painter(resources: cache), size, 2);
    _expectPixels(first, recreated, 'Recreated resources', tolerance: 0);
    _expectPixels(await _raster(tester, painter(), size, 2), recreated,
        'Legacy after cache recreation');
  });

  testWidgets(
      'animated wormhole repaints all inputs without rebuilding controls',
      (tester) async {
    const boundaryKey = ValueKey('animated-wormhole');
    final key = GlobalKey<_AnimatedHarnessState>();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
          child: SizedBox(
        width: 220,
        height: 180,
        child: RepaintBoundary(
            key: boundaryKey, child: _AnimatedHarness(key: key)),
      )),
    ));
    final state = key.currentState!;
    final paintFinder = find.byType(CustomPaint);
    final originalPaint = tester.widget<CustomPaint>(paintFinder);
    final controls = find.byWidgetPredicate((widget) =>
        widget is Semantics && widget.properties.label == 'Puzzle controls');
    final originalControls = tester.widget(controls);
    var previous = await _widgetPixels(tester, boundaryKey);
    for (final update in [
      () => state.time.value = 0.25,
      () => state.glow.value = 1.0,
      () => state.warp.value = 0.7,
    ]) {
      update();
      await tester.pump(const Duration(milliseconds: 16));
      final current = await _widgetPixels(tester, boundaryKey);
      expect(_samePixels(previous, current), isFalse,
          reason:
              'Each animated input must independently update rendered pixels');
      expect(tester.widget<CustomPaint>(paintFinder), same(originalPaint));
      expect(tester.widget(controls), same(originalControls));
      expect(state.builds, 1);
      previous = current;
    }
    state.time.repeat();
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget<CustomPaint>(paintFinder), same(originalPaint));
      expect(state.builds, 1);
    }
    expect(_samePixels(previous, await _widgetPixels(tester, boundaryKey)),
        isFalse);
    await tester.tap(controls);
    expect(state.taps, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Magic Triangles default selector retains frame and puzzle behavior',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'onboarding_seen_magic_triangles': true});
    ProfilePreferences.activeId = 'default';
    PuzzleSessionStore.resetForTesting();
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sri = SriService();
    final cognitive = CognitiveProfileService();
    final gp = GameProvider(
        progressService: ProgressService(),
        sriService: sri,
        cognitiveProfileService: cognitive);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: gp),
        ChangeNotifierProvider.value(value: sri),
        ChangeNotifierProvider.value(value: cognitive),
      ],
      child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: const MagicTrianglesGame(grade: 1, level: 1)),
    ));
    dynamic session = tester.state(find.byType(MagicTrianglesGame));
    for (var attempt = 0; attempt < 150; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      if (session.capturePuzzleSession() != null) break;
    }
    expect(session.capturePuzzleSession(), isNotNull);
    await tester.pump();
    final before = session.capturePuzzleSession();
    final paint = find.byWidgetPredicate((widget) =>
        widget is CustomPaint &&
        (widget.painter is WormholePainter ||
            widget.painter is AnimatedWormholePainter));
    expect(paint, findsOneWidget);
    final originalPaint = tester.widget<CustomPaint>(paint);
    final node = find
        .byWidgetPredicate((widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Empty triangle node, drop a number here')
        .first;
    final originalNode = tester.widget(node);
    const selector =
        String.fromEnvironment('WORMHOLE_RENDER_PATH', defaultValue: 'cached');
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(tester.widget<CustomPaint>(paint), originalPaint),
          selector == 'cached');
      expect(tester.widget(node), same(originalNode));
    }
    expect(session.capturePuzzleSession(), before,
        reason: 'Rendering ticks must not mutate the puzzle or consume moves');
    expect(gp.outcomeCount, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
