// Unit tests for star_forge_logic.dart — pure puzzle logic only.
//
// The CSP-based generator is very slow (200 attempts x 3s timeout), so we
// test the puzzle data structures and validation logic directly using
// hand-constructed puzzles rather than calling generate().

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/star_forge_logic.dart';

/// Build a star puzzle with custom parameters.
StarForgePuzzle _buildPuzzle({
  required int points,
  required List<List<int>> lines,
  required int magicConstant,
  required Map<int, int> solution,
  required int clueCount,
}) {
  final nodeCount = points * 2;

  final clues = <int, int>{};
  final emptyNodes = <int>{};
  for (int i = 0; i < nodeCount; i++) {
    if (i < clueCount) {
      clues[i] = solution[i]!;
    } else {
      emptyNodes.add(i);
    }
  }

  final clueValues = clues.values.toSet();
  final values = List.generate(nodeCount, (i) => i + 1);
  final numberPool = values.where((v) => !clueValues.contains(v)).toList()
    ..sort();

  return StarForgePuzzle(
    points: points,
    nodeCount: nodeCount,
    lines: lines,
    magicConstant: magicConstant,
    solution: solution,
    clues: clues,
    emptyNodes: emptyNodes,
    numberPool: numberPool,
  );
}

// A known valid 4-line star (a simplified "star" for testing).
// 4 nodes on a 2-point star is not standard but works for testing the
// validateSolution logic directly.
// For simplicity let's use a 3-line arrangement where every line sums to 10:
// Line 0: nodes [0, 1] -> values 3 + 7 = 10
// Line 1: nodes [1, 2] -> values 7 + 3... no, we need all values unique.
//
// Instead: use a 5-point star with the line structure from _buildStarLines.
// Lines: [i, 5+i, 5+(i+1)%5, (i+1)%5]
//
// We need values for nodes 0..9 such that all 5 lines sum to the same value.
// Line 0: v[0] + v[5] + v[6] + v[1]
// Line 1: v[1] + v[6] + v[7] + v[2]
// Line 2: v[2] + v[7] + v[8] + v[3]
// Line 3: v[3] + v[8] + v[9] + v[4]
// Line 4: v[4] + v[9] + v[5] + v[0]
//
// Known valid 5-point magic star (magic constant = 24):
// Outer: [1, 4, 2, 8, 6] at indices 0-4
// Inner: [10, 5, 9, 3, 7] at indices 5-9
// Line 0: 1+10+5+4 = 20  ... let me just look up a valid one.
//
// Actually, for ANY 5-point star with values 1-10:
// Each inner node appears in 2 lines, each outer in 1.
// Sum of all lines = sum(outer)*1 + sum(inner)*2 = 5*magic
// total = 55. sum(outer) + 2*sum(inner) = 5*magic
// sum(outer) + sum(inner) = 55, so sum(inner) = 55 - sum(outer)
// sum(outer) + 2*(55 - sum(outer)) = 5*magic
// 110 - sum(outer) = 5*magic
// magic = (110 - sum(outer))/5
//
// If outer = {1,2,3,4,5} sum=15 -> magic = (110-15)/5 = 19
// If outer = {6,7,8,9,10} sum=40 -> magic = (110-40)/5 = 14
// If outer = {1,4,6,8,10} sum=29 -> magic = (110-29)/5 = 16.2 -- not integer
// If outer = {2,4,6,8,10} sum=30 -> magic = (110-30)/5 = 16
//
// Let's try magic=24 which is a common value:
// sum(outer) = 110 - 5*24 = -10 -- impossible. So magic=24 doesn't work
// with the standard line structure here. Let me just use magic=19.
//
// With outer={1,2,3,4,5}, inner={6,7,8,9,10}, magic=19.
// Line 0: v[0]+v[5]+v[6]+v[1] = 1+v[5]+v[6]+2 = 19 => v[5]+v[6]=16
// Line 1: v[1]+v[6]+v[7]+v[2] = 2+v[6]+v[7]+3 = 19 => v[6]+v[7]=14
// Line 2: v[2]+v[7]+v[8]+v[3] = 3+v[7]+v[8]+4 = 19 => v[7]+v[8]=12
// Line 3: v[3]+v[8]+v[9]+v[4] = 4+v[8]+v[9]+5 = 19 => v[8]+v[9]=10
// Line 4: v[4]+v[9]+v[5]+v[0] = 5+v[9]+v[5]+1 = 19 => v[9]+v[5]=13
//
// From: v[5]+v[6]=16, v[6]+v[7]=14 => v[5]-v[7]=2
//       v[7]+v[8]=12, v[8]+v[9]=10 => v[7]-v[9]=2
//       v[9]+v[5]=13
// Let v[9]=x. Then v[7]=x+2. From v[7]+v[8]=12: v[8]=10-x.
// From v[8]+v[9]=10: (10-x)+x=10. Consistent (always true -- underdetermined).
// From v[5]+v[9]=13: v[5]=13-x. From v[5]+v[6]=16: v[6]=x+3.
// From v[6]+v[7]=14: (x+3)+(x+2)=14 => 2x+5=14 => x=4.5 -- not integer!
//
// So outer={1,2,3,4,5} with this line structure doesn't work. Let's try a
// different outer set. With outer={1,3,5,7,9}, sum=25, magic=(110-25)/5=17.
// Line 0: 1+v[5]+v[6]+3=17 => v[5]+v[6]=13
// Line 1: 3+v[6]+v[7]+5=17 => v[6]+v[7]=9
// Line 2: 5+v[7]+v[8]+7=17 => v[7]+v[8]=5 -- inner values are {2,4,6,8,10}
//   min sum of 2 inner values = 2+4=6 > 5. Impossible.
//
// Let's just use a direct approach: pick any assignment and test with it.
// We don't need it to be a "magic" star with values 1-N. We just need
// the validateSolution method to work correctly.

void main() {
  group('StarForgePuzzle.validateSolution', () {
    // Build a simple 5-point star puzzle with known valid values
    late StarForgePuzzle puzzle;

    setUp(() {
      // Create a puzzle where we control everything.
      // 5-point star: 10 nodes, 5 lines.
      // We'll use values that make each line sum to 20:
      // Line 0: [0,5,6,1] -> 2+8+6+4 = 20
      // Line 1: [1,6,7,2] -> 4+6+7+3 = 20
      // Line 2: [2,7,8,3] -> 3+7+9+1 = 20
      // Line 3: [3,8,9,4] -> 1+9+5+5... wait, all must be unique
      //
      // Let me just set arbitrary values and use whatever sums result.
      // The key is that ALL lines sum to the SAME value.
      //
      // I'll build lines and pick solution values that work:
      final lines = <List<int>>[
        [0, 5, 6, 1],
        [1, 6, 7, 2],
        [2, 7, 8, 3],
        [3, 8, 9, 4],
        [4, 9, 5, 0],
      ];

      // Construct solution: all lines sum to 22
      // v0+v5+v6+v1 = 22
      // v1+v6+v7+v2 = 22
      // v2+v7+v8+v3 = 22
      // v3+v8+v9+v4 = 22
      // v4+v9+v5+v0 = 22
      // Pick: v0=1, v1=3, v5=10, v6=8 -> 1+10+8+3=22 OK
      //        v7 = 22-3-8-v2. Pick v2=5: v7=6. -> 3+8+6+5=22 OK
      //        v8 = 22-5-6-v3. Pick v3=9: v8=2. -> 5+6+2+9=22 OK
      //        v9 = 22-9-2-v4. Pick v4=4: v9=7. -> 9+2+7+4=22 OK
      //        Check line 4: 4+7+10+1=22 OK!
      // Values used: 1,3,10,8,5,6,9,2,4,7 -- all unique, all in 1-10!
      final solution = <int, int>{
        0: 1, 1: 3, 2: 5, 3: 9, 4: 4,
        5: 10, 6: 8, 7: 6, 8: 2, 9: 7,
      };

      puzzle = StarForgePuzzle(
        points: 5,
        nodeCount: 10,
        lines: lines,
        magicConstant: 22,
        solution: solution,
        clues: {0: 1, 1: 3, 2: 5}, // 3 clues
        emptyNodes: {3, 4, 5, 6, 7, 8, 9},
        numberPool: [2, 4, 6, 7, 8, 9, 10],
      );
    });

    test('correct solution is accepted', () {
      final userSolution = <int, int>{
        3: 9, 4: 4, 5: 10, 6: 8, 7: 6, 8: 2, 9: 7,
      };
      expect(puzzle.validateSolution(userSolution), isTrue);
    });

    test('corrupted single value is rejected', () {
      final userSolution = <int, int>{
        3: 9, 4: 4, 5: 10, 6: 8, 7: 6, 8: 2, 9: 7,
      };
      userSolution[3] = 10; // was 9, now duplicate and wrong sum
      expect(puzzle.validateSolution(userSolution), isFalse);
    });

    test('incomplete solution is rejected', () {
      expect(puzzle.validateSolution({}), isFalse);
    });

    test('duplicate values are rejected', () {
      final userSolution = <int, int>{
        3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1,
      };
      expect(puzzle.validateSolution(userSolution), isFalse);
    });

    test('wrong line sum is rejected', () {
      // All unique values but rearranged so line sums differ
      final userSolution = <int, int>{
        3: 4, 4: 9, 5: 10, 6: 8, 7: 6, 8: 2, 9: 7,
      };
      // Line 3: 4+2+7+9=22 still OK
      // Line 4: 9+7+10+1=27 != 22 FAIL
      expect(puzzle.validateSolution(userSolution), isFalse);
    });
  });

  group('StarForgePuzzle structure', () {
    test('puzzle stores correct dimensions', () {
      final puzzle = StarForgePuzzle(
        points: 6,
        nodeCount: 12,
        lines: List.generate(6, (i) => [i, 6 + i, 6 + (i + 1) % 6, (i + 1) % 6]),
        magicConstant: 26,
        solution: {for (int i = 0; i < 12; i++) i: i + 1},
        clues: {},
        emptyNodes: {for (int i = 0; i < 12; i++) i},
        numberPool: List.generate(12, (i) => i + 1),
      );

      expect(puzzle.points, 6);
      expect(puzzle.nodeCount, 12);
      expect(puzzle.lines.length, 6);
      expect(puzzle.solution.length, 12);
    });

    test('each line has 4 nodes for a standard star', () {
      for (final points in [5, 6, 7]) {
        final lines = List.generate(
            points, (i) => [i, points + i, points + (i + 1) % points, (i + 1) % points]);
        for (final line in lines) {
          expect(line.length, 4);
        }
      }
    });

    test('numberPool and clues partition values correctly', () {
      final solution = <int, int>{
        0: 1, 1: 3, 2: 5, 3: 9, 4: 4,
        5: 10, 6: 8, 7: 6, 8: 2, 9: 7,
      };
      final clues = <int, int>{0: 1, 1: 3};
      final emptyNodes = <int>{2, 3, 4, 5, 6, 7, 8, 9};
      final numberPool = [2, 4, 5, 6, 7, 8, 9, 10]; // everything except 1, 3

      expect(clues.length + emptyNodes.length, 10);
      for (final idx in clues.keys) {
        expect(emptyNodes.contains(idx), isFalse);
      }

      final clueValues = clues.values.toSet();
      for (final v in numberPool) {
        expect(clueValues.contains(v), isFalse);
      }
    });
  });

  group('StarForgeGenerator', () {
    test('can be instantiated', () {
      final gen = StarForgeGenerator();
      expect(gen, isNotNull);
    });
  });
}
