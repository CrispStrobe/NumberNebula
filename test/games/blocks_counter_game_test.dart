// Unit tests for blocks_counter_game.dart (Block Counter, spatial 3D game).
//
// TESTABILITY NOTES:
//   The whole 3D rendering surface (flutter_cube, AnimationControllers, the
//   GameProvider/DifficultyManager wiring, success dialogs and HapticFeedback)
//   lives in the private _BlockCounterGameState and is not unit-testable without
//   a full provider tree + plugin mocks. However, the GAME LOGIC is cleanly
//   separated into public, top-level, pure-ish surfaces:
//     - BlockCountingPuzzle.generate(Map<String,int>)  (the compute() entry)
//     - BlockPosition3D / BlockStructure / BlockCountingPuzzle data models
//   `generate` internally uses an UNSEEDED math.Random() with no injection seam
//   (it is built for compute() isolates). We therefore cannot assert exact
//   literal output; instead we assert the structural INVARIANTS that every
//   generated puzzle must satisfy, across many iterations. These invariants are
//   load-bearing: the correct answer is the rendered block count and the choice
//   set is what the player taps, so violations would make the game unwinnable
//   or ambiguous.

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/screens/blocks_counter_game.dart';

void main() {
  group('BlockCountingPuzzle.generate invariants', () {
    // Sweep a range of grade/level combinations and many repeats so the
    // assertions exercise the unseeded RNG broadly.
    final paramSets = <Map<String, int>>[
      {'grade': 1, 'level': 1},
      {'grade': 1, 'level': 8},
      {'grade': 3, 'level': 4},
      {'grade': 5, 'level': 12},
      {'grade': 2, 'level': 20},
    ];

    test('every generated puzzle is internally consistent (200 iterations)', () {
      for (final params in paramSets) {
        for (int i = 0; i < 40; i++) {
          final puzzle = BlockCountingPuzzle.generate(params);
          final structure = puzzle.blockStructure;

          // correctAnswer must equal the actual number of blocks placed.
          expect(puzzle.correctAnswer, equals(structure.blocks.length),
              reason: 'The displayed correct answer must be the real block '
                  'count, otherwise the puzzle is unwinnable.');
          expect(puzzle.correctAnswer, greaterThan(0),
              reason: 'A structure with zero blocks would render nothing.');

          // Exactly four distinct answer choices, one of which is correct.
          expect(puzzle.answerChoices.length, equals(4));
          expect(puzzle.answerChoices.toSet().length, equals(4),
              reason: 'Choices come from a Set, so all four must be distinct.');
          expect(puzzle.answerChoices, contains(puzzle.correctAnswer),
              reason: 'The correct answer must be one of the tappable choices.');

          // All choices are positive (the generator clamps to >= 1).
          for (final c in puzzle.answerChoices) {
            expect(c, greaterThanOrEqualTo(1));
          }

          // Difficulty is bounded as designed: min(5, grade + level~/4).
          expect(puzzle.difficulty, inInclusiveRange(1, 5));
        }
      }
    });

    test('all blocks lie within the declared grid bounds', () {
      for (final params in paramSets) {
        for (int i = 0; i < 20; i++) {
          final structure = BlockCountingPuzzle.generate(params).blockStructure;
          expect(structure.gridWidth, greaterThan(0));
          expect(structure.gridDepth, greaterThan(0));
          expect(structure.maxHeight, greaterThan(0));

          for (final b in structure.blocks) {
            expect(b.x, inInclusiveRange(0, structure.gridWidth - 1));
            expect(b.z, inInclusiveRange(0, structure.gridDepth - 1));
            // y is a 0-based stack index; the tallest stack defines maxHeight.
            expect(b.y, inInclusiveRange(0, structure.maxHeight - 1));
          }
        }
      }
    });

    test('block positions are unique and stacks are gapless (no floating blocks)',
        () {
      // Each (x,z) column must contain a contiguous run y = 0..h-1 with no
      // duplicates and no gaps, so the rendered structure is physically valid.
      for (final params in paramSets) {
        for (int i = 0; i < 20; i++) {
          final structure = BlockCountingPuzzle.generate(params).blockStructure;

          final seen = <String>{};
          final columnHeights = <String, List<int>>{};
          for (final b in structure.blocks) {
            final pos = '${b.x},${b.y},${b.z}';
            expect(seen.add(pos), isTrue, reason: 'Duplicate block at $pos.');
            (columnHeights['${b.x},${b.z}'] ??= <int>[]).add(b.y);
          }

          columnHeights.forEach((col, ys) {
            ys.sort();
            // Contiguous 0,1,2,... with no gaps.
            for (int y = 0; y < ys.length; y++) {
              expect(ys[y], equals(y),
                  reason: 'Column $col has a gap/float: y-values $ys.');
            }
          });

          // maxHeight equals the tallest column.
          final tallest = columnHeights.values
              .map((ys) => ys.length)
              .fold<int>(0, (a, b) => a > b ? a : b);
          expect(structure.maxHeight, equals(tallest));
        }
      }
    });

    test('higher progress trends to higher difficulty than the easiest puzzle',
        () {
      // difficulty is deterministic given grade+level (no RNG), so this is a
      // hard equality on the design formula min(5, grade + level~/4).
      expect(BlockCountingPuzzle.generate({'grade': 1, 'level': 1}).difficulty,
          equals(1));
      expect(BlockCountingPuzzle.generate({'grade': 5, 'level': 12}).difficulty,
          equals(5),
          reason: 'min(5, 5 + 12~/4) = min(5, 8) = 5 (capped).');
      expect(BlockCountingPuzzle.generate({'grade': 2, 'level': 8}).difficulty,
          equals(4),
          reason: 'min(5, 2 + 8~/4) = min(5, 4) = 4.');
    });

    test('a consistent puzzle color is assigned to all blocks', () {
      for (int i = 0; i < 20; i++) {
        final blocks = BlockCountingPuzzle
            .generate({'grade': 3, 'level': 4})
            .blockStructure
            .blocks;
        final colors = blocks.map((b) => b.color.toARGB32()).toSet();
        expect(colors.length, equals(1),
            reason: 'generate() picks one puzzleColor for the whole structure.');
      }
    });
  });

  group('data models', () {
    test('BlockPosition3D preserves its fields', () {
      const c = Color(0xFF00C8FF);
      final b = BlockPosition3D(x: 1, y: 2, z: 3, isVisible: true, color: c);
      expect(b.x, 1);
      expect(b.y, 2);
      expect(b.z, 3);
      expect(b.isVisible, isTrue);
      expect(b.color, c);
    });

    test('BlockStructure preserves its fields', () {
      final blocks = [
        BlockPosition3D(
            x: 0, y: 0, z: 0, isVisible: true, color: const Color(0xFF000000)),
      ];
      final s = BlockStructure(
          blocks: blocks, gridWidth: 4, gridDepth: 5, maxHeight: 6);
      expect(s.blocks, same(blocks));
      expect(s.gridWidth, 4);
      expect(s.gridDepth, 5);
      expect(s.maxHeight, 6);
    });
  });
}
