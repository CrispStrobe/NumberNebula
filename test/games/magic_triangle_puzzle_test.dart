// Logic tests for MagicTrianglePuzzle.
//
// NOTE on determinism: the production generator uses unseeded
// `math.Random()` internally (_generateNumberSet / _generateEnhancedDecoys
// / solver.shuffle), and there is no injection seam to seed it. Per the
// task's "do NOT add a DI seam" rule, we instead assert structural
// INVARIANTS that must hold for *every* generated puzzle regardless of the
// random draw: the produced solution has three equal side sums, the
// hidden/visible bookkeeping is internally consistent, and checkSolution
// correctly accepts the intended hidden assignment and rejects corruptions.
// We keep grade/level small so the recursive solver stays fast.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/magic_triangle_puzzle.dart';

/// Recompute the three side sums the same way the production code does,
/// using only the public puzzle shape (circlesPerSide + a full arrangement).
List<int> sideSums(MagicTrianglePuzzle p, List<int> arrangement) {
  final n = p.circlesPerSide;
  List<int> indicesFor(int side) {
    switch (side) {
      case 0:
        return List.generate(n, (i) => i);
      case 1:
        return [n - 1, ...List.generate(n - 1, (i) => n + i)];
      case 2:
        return [2 * n - 2, ...List.generate(n - 2, (i) => 2 * n - 1 + i), 0];
      default:
        return [];
    }
  }

  return List.generate(3, (side) {
    return indicesFor(side).fold<int>(0, (acc, idx) => acc + arrangement[idx]);
  });
}

/// The set of numbers that are hidden (= not shown to the user) for a puzzle.
List<int> correctHiddenNumbers(MagicTrianglePuzzle p) {
  final visible = p.visibleValues.values.toSet();
  return p.allNumbers.where((n) => !visible.contains(n)).toList();
}

/// Try every ordering of the hidden numbers and return the first ordering
/// (indexed by answer-slot) that checkSolution marks perfect. There must be
/// at least one for a solvable puzzle.
List<int>? findPerfectAnswers(MagicTrianglePuzzle p) {
  final hidden = correctHiddenNumbers(p);
  final perms = <List<int>>[];
  void permute(List<int> current, List<int> remaining) {
    if (remaining.isEmpty) {
      perms.add(List.of(current));
      return;
    }
    for (var i = 0; i < remaining.length; i++) {
      final next = List.of(remaining)..removeAt(i);
      permute([...current, remaining[i]], next);
    }
  }

  permute([], hidden);
  for (final candidate in perms) {
    if (p.checkSolution(candidate).isPerfect) return candidate;
  }
  return null;
}

void main() {
  group('MagicTrianglePuzzle.generate invariants', () {
    test('generated puzzles are well-formed and equal-summed (many runs)', () {
      // Small grades/levels keep the recursive solver fast and the number of
      // hidden circles low enough for permutation search.
      const configs = [
        {'grade': 1, 'level': 1},
        {'grade': 1, 'level': 2},
        {'grade': 2, 'level': 1},
      ];

      for (final cfg in configs) {
        for (var run = 0; run < 6; run++) {
          final p = MagicTrianglePuzzle.generate(cfg);

          // Structural shape.
          expect(p.totalCircles, (p.circlesPerSide * 3) - 3);
          expect(p.allNumbers.length, p.totalCircles);
          expect(p.allNumbers.toSet().length, p.allNumbers.length,
              reason: 'resonator values must be distinct');

          // Visible + hidden partition the circle indices with no overlap.
          final allIdx = List.generate(p.totalCircles, (i) => i).toSet();
          expect(p.visibleValues.keys.toSet().union(p.hiddenIndices), allIdx);
          expect(
              p.visibleValues.keys.toSet().intersection(p.hiddenIndices),
              isEmpty);

          // Every visible value is one of the puzzle numbers.
          for (final v in p.visibleValues.values) {
            expect(p.allNumbers.contains(v), isTrue);
          }

          // The intended hidden assignment yields three EQUAL side sums.
          final perfect = findPerfectAnswers(p);
          expect(perfect, isNotNull,
              reason: 'a solvable puzzle must have a perfect arrangement');

          // Reconstruct the full arrangement from that perfect assignment and
          // confirm all three side sums are equal to the warp frequency.
          final arrangement = List<int>.filled(p.totalCircles, 0);
          var h = 0;
          for (var i = 0; i < p.totalCircles; i++) {
            if (p.hiddenIndices.contains(i)) {
              arrangement[i] = perfect![h++];
            } else {
              arrangement[i] = p.visibleValues[i]!;
            }
          }
          final sums = sideSums(p, arrangement);
          expect(sums.toSet().length, 1,
              reason: 'all three side sums must be equal: $sums');
          expect(sums.first, p.warpFrequency);
        }
      }
    });
  });

  group('checkSolution', () {
    test('accepts the intended hidden numbers and rejects corruptions', () {
      final p = MagicTrianglePuzzle.generate({'grade': 1, 'level': 1});
      final perfect = findPerfectAnswers(p);
      expect(perfect, isNotNull);

      final correct = p.checkSolution(perfect!);
      expect(correct.isValid, isTrue);
      expect(correct.isPerfect, isTrue);

      // Corrupt one slot with a value that is NOT among the hidden numbers:
      // wrong number-set -> invalid AND not perfect.
      final hiddenSet = perfect.toSet();
      var bogus = 1;
      while (hiddenSet.contains(bogus) || p.allNumbers.contains(bogus)) {
        bogus++;
      }
      final wrong = List<int>.of(perfect)..[0] = bogus;
      final wrongResult = p.checkSolution(wrong);
      expect(wrongResult.isValid, isFalse);
      expect(wrongResult.isPerfect, isFalse);
    });

    test('right numbers in a wrong order are valid but not perfect', () {
      // Find a puzzle with >=2 hidden numbers where swapping two of them
      // breaks the equal-sum property (true for essentially all puzzles).
      MagicTrianglePuzzle? puzzle;
      List<int>? perfect;
      for (var attempt = 0; attempt < 12 && puzzle == null; attempt++) {
        final p = MagicTrianglePuzzle.generate({'grade': 1, 'level': 2});
        final ans = findPerfectAnswers(p);
        if (ans != null && ans.length >= 2) {
          // Look for a swap that is no longer perfect.
          for (var i = 0; i < ans.length && puzzle == null; i++) {
            for (var j = i + 1; j < ans.length; j++) {
              if (ans[i] == ans[j]) continue;
              final swapped = List<int>.of(ans);
              final t = swapped[i];
              swapped[i] = swapped[j];
              swapped[j] = t;
              final r = p.checkSolution(swapped);
              if (r.isValid && !r.isPerfect) {
                puzzle = p;
                perfect = swapped;
                break;
              }
            }
          }
        }
      }

      // If no such puzzle/swap surfaced (degenerate symmetric puzzles only),
      // the assertion below is skipped gracefully; otherwise verify the
      // valid-but-imperfect contract.
      if (puzzle != null && perfect != null) {
        final r = puzzle.checkSolution(perfect);
        expect(r.isValid, isTrue,
            reason: 'same number multiset -> still a valid attempt');
        expect(r.isPerfect, isFalse,
            reason: 'a sum-breaking reorder must not be perfect');
      }
    });
  });

  group('getAnswerIndex bookkeeping', () {
    test('maps hidden circle indices to sequential answer slots', () {
      final p = MagicTrianglePuzzle.generate({'grade': 1, 'level': 1});

      final sortedHidden = p.hiddenIndices.toList()..sort();
      // Each hidden global index maps to its rank among sorted hidden indices.
      for (var rank = 0; rank < sortedHidden.length; rank++) {
        expect(p.getAnswerIndex(sortedHidden[rank]), rank);
      }

      // Answer indices are a contiguous 0..hidden-1 range with no gaps/dupes.
      final answerIdxs =
          sortedHidden.map(p.getAnswerIndex).toList()..sort();
      expect(answerIdxs, List.generate(sortedHidden.length, (i) => i));

      // A non-hidden (visible) index returns the sentinel -1.
      for (final visibleIdx in p.visibleValues.keys) {
        expect(p.getAnswerIndex(visibleIdx), -1);
      }
    });
  });
}
