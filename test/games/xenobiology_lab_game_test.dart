// Unit tests for the mathematical invariants of the Xenobiology Lab game.
//
// The game logic is fully private inside _XenobiologyLabGameState, so we
// cannot import and call it directly. Instead we reimplement the core
// puzzle-generation formulas and test the mathematical invariants that the
// game relies upon: system of equations uniqueness, total computation, and
// trait distinctness.

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

/// Reimplements the puzzle generation logic from xenobiology_lab_game.dart
/// to verify mathematical invariants without needing the widget.
class _XenoLabPuzzle {
  final int eyesA, legsA, eyesB, legsB;
  final int countA, countB;
  final int totalEyes, totalLegs;
  // Optional third type
  final bool hasThird;
  final int eyesC, legsC, countC;

  _XenoLabPuzzle({
    required this.eyesA,
    required this.legsA,
    required this.eyesB,
    required this.legsB,
    required this.countA,
    required this.countB,
    required this.totalEyes,
    required this.totalLegs,
    this.hasThird = false,
    this.eyesC = 0,
    this.legsC = 0,
    this.countC = 0,
  });

  /// Generate a puzzle matching the game's logic for a given grade.
  static _XenoLabPuzzle generate(int grade, math.Random random) {
    int eyesA, legsA, eyesB, legsB;
    int countA, countB;
    bool hasThird = grade >= 3;
    int eyesC = 0, legsC = 0, countC = 0;

    if (grade <= 2) {
      eyesA = random.nextInt(3) + 2;
      legsA = random.nextInt(3) + 2;
      eyesB = random.nextInt(3) + 2;
      legsB = random.nextInt(3) + 2;

      while (eyesA * legsB == eyesB * legsA) {
        eyesB = random.nextInt(3) + 2;
        legsB = random.nextInt(3) + 2;
      }

      countA = random.nextInt(5) + 1;
      countB = random.nextInt(5) + 1;
    } else {
      eyesA = random.nextInt(4) + 2;
      legsA = random.nextInt(5) + 2;
      eyesB = random.nextInt(4) + 2;
      legsB = random.nextInt(5) + 2;

      while (eyesA * legsB == eyesB * legsA) {
        eyesB = random.nextInt(4) + 2;
        legsB = random.nextInt(5) + 2;
      }

      countA = random.nextInt(6) + 2;
      countB = random.nextInt(6) + 2;

      if (hasThird) {
        eyesC = random.nextInt(3) + 1;
        legsC = random.nextInt(4) + 2;
        countC = random.nextInt(3) + 1;
      }
    }

    final totalEyes =
        countA * eyesA + countB * eyesB + (hasThird ? countC * eyesC : 0);
    final totalLegs =
        countA * legsA + countB * legsB + (hasThird ? countC * legsC : 0);

    return _XenoLabPuzzle(
      eyesA: eyesA,
      legsA: legsA,
      eyesB: eyesB,
      legsB: legsB,
      countA: countA,
      countB: countB,
      totalEyes: totalEyes,
      totalLegs: totalLegs,
      hasThird: hasThird,
      eyesC: eyesC,
      legsC: legsC,
      countC: countC,
    );
  }
}

void main() {
  group('Xenobiology Lab: trait distinctness', () {
    test('traits differ such that the 2x2 system has a unique solution', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final puzzle = _XenoLabPuzzle.generate(1, random);
        // The determinant eyesA*legsB - eyesB*legsA must be non-zero
        // for the system of equations to have a unique solution.
        final det = puzzle.eyesA * puzzle.legsB - puzzle.eyesB * puzzle.legsA;
        expect(det, isNot(0),
            reason: 'Traits must produce a non-degenerate system');
      }
    });

    test('trait values are in the expected range for grade <= 2', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final puzzle = _XenoLabPuzzle.generate(1, random);
        expect(puzzle.eyesA, inInclusiveRange(2, 4));
        expect(puzzle.legsA, inInclusiveRange(2, 4));
        expect(puzzle.eyesB, inInclusiveRange(2, 4));
        expect(puzzle.legsB, inInclusiveRange(2, 4));
        expect(puzzle.countA, inInclusiveRange(1, 5));
        expect(puzzle.countB, inInclusiveRange(1, 5));
      }
    });

    test('trait values are in the expected range for grade >= 3', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final puzzle = _XenoLabPuzzle.generate(3, random);
        expect(puzzle.eyesA, inInclusiveRange(2, 5));
        expect(puzzle.legsA, inInclusiveRange(2, 6));
        expect(puzzle.eyesB, inInclusiveRange(2, 5));
        expect(puzzle.legsB, inInclusiveRange(2, 6));
        expect(puzzle.countA, inInclusiveRange(2, 7));
        expect(puzzle.countB, inInclusiveRange(2, 7));
      }
    });
  });

  group('Xenobiology Lab: totals computation', () {
    test('totalEyes and totalLegs match formula (2 types)', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _XenoLabPuzzle.generate(2, random);
        expect(p.totalEyes, p.countA * p.eyesA + p.countB * p.eyesB);
        expect(p.totalLegs, p.countA * p.legsA + p.countB * p.legsB);
        expect(p.hasThird, isFalse);
      }
    });

    test('totalEyes and totalLegs match formula (3 types)', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _XenoLabPuzzle.generate(4, random);
        expect(p.hasThird, isTrue);
        expect(p.totalEyes,
            p.countA * p.eyesA + p.countB * p.eyesB + p.countC * p.eyesC);
        expect(p.totalLegs,
            p.countA * p.legsA + p.countB * p.legsB + p.countC * p.legsC);
      }
    });
  });

  group('Xenobiology Lab: solution uniqueness (2-type case)', () {
    test('given totals, solving the 2x2 system recovers the counts', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _XenoLabPuzzle.generate(2, random);

        // Solve:
        //   countA * eyesA + countB * eyesB = totalEyes
        //   countA * legsA + countB * legsB = totalLegs
        // Using Cramer's rule:
        final det = p.eyesA * p.legsB - p.eyesB * p.legsA;
        expect(det, isNot(0));

        final solA = (p.totalEyes * p.legsB - p.eyesB * p.totalLegs) / det;
        final solB = (p.eyesA * p.totalLegs - p.totalEyes * p.legsA) / det;

        expect(solA, p.countA.toDouble(),
            reason: 'Cramer solution for countA must match');
        expect(solB, p.countB.toDouble(),
            reason: 'Cramer solution for countB must match');
      }
    });
  });

  group('Xenobiology Lab: third type (grade >= 3)', () {
    test('third type has valid trait ranges', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _XenoLabPuzzle.generate(4, random);
        expect(p.eyesC, inInclusiveRange(1, 3));
        expect(p.legsC, inInclusiveRange(2, 5));
        expect(p.countC, inInclusiveRange(1, 3));
      }
    });
  });
}
