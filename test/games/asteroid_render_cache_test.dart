import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';
import 'package:space_math_academy/features/games/screens/asteroid_math_game.dart';

Asteroid _asteroid(AsteroidType type, MathProblem problem) => Asteroid(
      id: 1,
      problem: problem,
      position: const Offset(128, 128),
      velocity: const Offset(2, -3),
      size: 48,
      rotationSpeed: 0.2,
      rotation: 0,
      type: type,
      hue: 120,
    );

Future<Uint8List> _pixels(
  Asteroid asteroid, {
  AsteroidRenderCache? cache,
  String divisionSymbol = '÷',
  String multiplicationSymbol = '×',
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  asteroid.draw(
    canvas,
    isHintActive: false,
    divisionSymbol: divisionSymbol,
    multiplicationSymbol: multiplicationSymbol,
    renderCache: cache,
  );
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(256, 256);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(bytes, isNotNull);
      return Uint8List.fromList(bytes!.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      ));
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

Future<void> _expectSamePixels(
  Asteroid asteroid,
  AsteroidRenderCache cache, {
  String divisionSymbol = '÷',
  String multiplicationSymbol = '×',
}) async {
  final legacy = await _pixels(
    asteroid,
    divisionSymbol: divisionSymbol,
    multiplicationSymbol: multiplicationSymbol,
  );
  final candidate = await _pixels(
    asteroid,
    cache: cache,
    divisionSymbol: divisionSymbol,
    multiplicationSymbol: multiplicationSymbol,
  );
  expect(legacy.any((byte) => byte != 0), isTrue);
  expect(
    listEquals(legacy, candidate),
    isTrue,
    reason: '${asteroid.type.name}, size ${asteroid.size}, '
        'rotation ${asteroid.rotation}, position ${asteroid.position}, '
        'symbols $divisionSymbol / $multiplicationSymbol',
  );
}

void main() {
  testWidgets('font changes invalidate labels after round cache resets',
      (tester) async {
    final cache = AsteroidRenderCache();
    final asteroid = _asteroid(AsteroidType.rocky, MathProblem.addition(3, 4));
    try {
      for (var round = 0; round < 2; round++) {
        final previous = cache.label(asteroid, asteroid.mathProblem)!;
        await tester.binding.handleSystemMessage({'type': 'fontsChange'});
        final current = cache.label(asteroid, asteroid.mathProblem)!;
        expect(current, isNot(same(previous)),
            reason: 'A font change must remeasure previously cached text');
        await tester.runAsync(() => _expectSamePixels(asteroid, cache));
        cache.clear();
      }
    } finally {
      cache.dispose();
    }
    // Closing a screen must remove its font listener as well as paragraphs.
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
  });

  for (final type in AsteroidType.values) {
    testWidgets('cached ${type.name} matches legacy across moving frames',
        (tester) async {
      await tester.runAsync(() async {
        final cache = AsteroidRenderCache();
        final asteroid = _asteroid(type, MathProblem.addition(3, 4));
        try {
          await _expectSamePixels(asteroid, cache);
          asteroid.position = const Offset(111, 137);
          asteroid.rotation = 0.6;
          await _expectSamePixels(asteroid, cache);
          asteroid.size = 88;
          await _expectSamePixels(asteroid, cache);
          asteroid.position = const Offset(139, 111);
          asteroid.rotation = 1.8;
          asteroid.size = 140;
          await _expectSamePixels(asteroid, cache);
        } finally {
          cache.dispose();
        }
      });
    });
  }

  testWidgets('cached labels follow division and multiplication preferences',
      (tester) async {
    await tester.runAsync(() async {
      final cache = AsteroidRenderCache();
      final division = _asteroid(
        AsteroidType.crystalline,
        MathProblem.division(24, 6),
      );
      final multiplication = _asteroid(
        AsteroidType.rocky,
        MathProblem.multiplication(6, 7),
      );
      try {
        for (final asteroid in [division, multiplication]) {
          await _expectSamePixels(asteroid, cache);
          await _expectSamePixels(
            asteroid,
            cache,
            divisionSymbol: ':',
            multiplicationSymbol: '·',
          );
          await _expectSamePixels(asteroid, cache);
        }
      } finally {
        cache.dispose();
      }
    });
  });

  testWidgets('retaining live asteroids preserves pixels after removal',
      (tester) async {
    await tester.runAsync(() async {
      final cache = AsteroidRenderCache();
      final removed = _asteroid(
        AsteroidType.crystalline,
        MathProblem.addition(3, 4),
      );
      final retained = _asteroid(
        AsteroidType.volcanic,
        MathProblem.subtraction(10, 4),
      );
      try {
        await _expectSamePixels(removed, cache);
        await _expectSamePixels(retained, cache);
        cache.retain([retained]);
        retained.position = const Offset(117, 131);
        retained.rotation = 0.9;
        await _expectSamePixels(retained, cache);
        cache.retain(const <Asteroid>[]);
        await _expectSamePixels(removed, cache);
      } finally {
        cache.dispose();
      }
    });
  });
}
