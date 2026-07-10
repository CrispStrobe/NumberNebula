@TestOn('browser')
library;

// Real web (dart2js) timing for Rechenquadrat / arithmatic_square generation.
// This is the original "takes too long on the vercel/web build" complaint,
// checked on its actual platform:
//   flutter test test/web/rechenquadrat_web_timing_test.dart --platform chrome

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/arithmatic_square_game.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';

DifficultyConfig _cfg(int g, int l) => DifficultyConfig(
      grade: g,
      level: l,
      difficultyMultiplier: 1,
      numberRange: const {'min': 1, 'max': 20},
      operationTypes: const [MathOperation.addition],
      equationProbability: 1,
      objectCount: 1,
      timeLimit: 0,
      gameSpeed: 1,
      showHints: true,
      animationSpeed: 1,
      visualComplexity: 1,
    );

Future<int> _run(int g, int l) async {
  final sw = Stopwatch()..start();
  await ArithmeticSquarePuzzle.generate({
    'grade': g,
    'level': l,
    'difficulty': _cfg(g, l),
    'useCustomSettings': false,
    'customOps': <String>[],
    'customMin': 1,
    'customMax': 20,
  });
  return sw.elapsedMilliseconds;
}

void main() {
  for (final gl in [
    [1, 1],
    [2, 10],
    [3, 10],
    [4, 20],
  ]) {
    test('web generation grade ${gl[0]} level ${gl[1]} is fast', () async {
      final t = <int>[];
      for (var i = 0; i < 8; i++) {
        t.add(await _run(gl[0], gl[1]));
      }
      t.sort();
      // ignore: avoid_print
      print('>>> WEB g${gl[0]}l${gl[1]} times(ms)=$t  max=${t.last}');
      // Bounded generation must never approach the old multi-second blow-up.
      expect(t.last, lessThan(4000),
          reason: 'web generation should be well under 4s');
    }, timeout: const Timeout(Duration(seconds: 120)));
  }
}
