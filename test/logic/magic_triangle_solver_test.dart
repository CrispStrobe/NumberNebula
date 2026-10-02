import 'dart:math';
import 'package:space_math_academy/features/games/services/magic_triangle_puzzle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/magic_triangle_solver.dart';

List<int> sideTotals(List<int> a, int n) => [
      a.take(n).reduce((a, b) => a + b),
      a.skip(n - 1).take(n).reduce((a, b) => a + b),
      a.skip(2 * n - 2).fold<int>(a.first, (a, b) => a + b),
    ];

void main() {
  test('higher-level generation keeps its size and a playable equal-sum board',
      () {
    for (final grade in [1, 3, 6]) {
      for (int sample = 0; sample < 5; sample++) {
        final puzzle =
            MagicTrianglePuzzle.generate({'grade': grade, 'level': 10});
        final solution =
            solveMagicTriangle(puzzle.circlesPerSide, puzzle.allNumbers)!;
        final indices = puzzle.hiddenIndices.toList()..sort();
        expect(
            puzzle
                .checkSolution(indices.map((i) => solution[i]).toList())
                .isPerfect,
            isTrue);
        if (grade == 6) {
          expect(puzzle.circlesPerSide, 7);
          expect(puzzle.warpFrequency, greaterThan(300));
        }
        final hidden = indices.map((i) => solution[i]).toSet();
        expect(puzzle.numberPool.toSet().containsAll(hidden), isTrue);
        expect(puzzle.numberPool.every((v) => v > 0), isTrue);
      }
    }
  });
  test(
      'exact solver keeps every value and equal sides through maximum board size',
      () {
    final random = Random(6301);
    for (int n = 3; n <= 7; n++) {
      for (int sample = 0; sample < 10; sample++) {
        final numbers = List.generate(3 * n - 3, (i) => 1000 + 17 * i)
          ..shuffle(random);
        final input = List<int>.of(numbers);
        final solution = solveMagicTriangle(n, numbers);
        expect(solution, isNotNull, reason: 'size $n, sample $sample');
        expect(solution!.toSet(), numbers.toSet());
        expect(sideTotals(solution, n).toSet(), hasLength(1));
        expect(sideTotals(solution, n).first, greaterThan(300));
        expect(numbers, input, reason: 'solving must not shuffle caller data');
      }
    }
  });
  test('small-board feasibility matches exhaustive permutations', () {
    final random = Random(921);
    bool brute(List<int> numbers, List<int> prefix) {
      if (numbers.isEmpty) return sideTotals(prefix, 3).toSet().length == 1;
      for (int i = 0; i < numbers.length; i++) {
        final rest = List<int>.of(numbers)..removeAt(i);
        if (brute(rest, [...prefix, numbers[i]])) return true;
      }
      return false;
    }

    for (int sample = 0; sample < 30; sample++) {
      final pool = List.generate(20, (i) => i + 1)..shuffle(random);
      final numbers = pool.take(6).toList();
      expect(solveMagicTriangle(3, numbers) != null, brute(numbers, []));
    }
    expect(solveMagicTriangle(3, [1, 2, 3, 4, 5, 1000]), isNull);
  });
  test('invalid shapes and duplicate values are rejected', () {
    expect(solveMagicTriangle(2, [1, 2, 3]), isNull);
    expect(solveMagicTriangle(3, [1, 2, 3]), isNull);
    expect(solveMagicTriangle(3, [1, 2, 3, 4, 5, 5]), isNull);
  });
}
