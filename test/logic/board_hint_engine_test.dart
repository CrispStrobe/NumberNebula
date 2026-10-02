import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/board_hint_engine.dart';

void main() {
  test(
      'light hints solve the actual all-lit goal across sizes and seeded states',
      () {
    final rng = Random(61);
    for (int n = 2; n <= 8; n++) {
      for (int sample = 0; sample < 10; sample++) {
        final grid = List.generate(n, (_) => List.filled(n, true));
        void tap(int i) {
          final r = i ~/ n, c = i % n;
          for (final (dr, dc) in [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)]) {
            final y = r + dr, x = c + dc;
            if (y >= 0 && y < n && x >= 0 && x < n) grid[y][x] = !grid[y][x];
          }
        }

        for (int i = 0; i < n * n; i++) {
          if (rng.nextBool()) tap(i);
        }
        final taps = solveLights(grid);
        expect(taps, isNotNull);
        for (final i in taps!) {
          tap(i);
        }
        expect(grid.expand((r) => r).every((v) => v), isTrue);
      }
    }
  });
  test('a current target is matched by value rather than generated order', () {
    final hint = findBoardHint('asteroid_math', {
      'targetOrder': [4, 8],
      'currentTargetIndex': 0,
      'levelProblems': [
        {'expression': '4 + 4', 'answer': 8},
        {'expression': '2 + 2', 'answer': 4}
      ]
    });
    expect(hint!.value, 4);
    expect(hint.working, contains('2 + 2 = 4'));
  });
  test('matrix hints preserve alternate valid player placements', () {
    final state = {
      'puzzle': {
        'size': 2,
        'clues': <String, int>{},
        'emptyCells': ['r0c0', 'r0c1', 'r1c0', 'r1c1'],
        'zones': <List<String>>[]
      },
      'answers': {'r0c0': 2}
    };
    final hint = findBoardHint('nebula_matrix', state)!;
    expect(hint.verified, isTrue);
    expect(hint.target, 'r0c1');
    expect(hint.value, 1);
    expect((state['answers'] as Map)['r0c0'], 2);
  });
  test('Solar Panel uses multiplication below and addition at its top', () {
    final hint = findBoardHint('solarpanel_game', {
      'currentPuzzle': {
        'hiddenCells': [0],
        'visibleValues': [
          [1, 6],
          [2, 8],
          [3, 3],
          [4, 2],
          [5, 4]
        ],
        'numberPool': [14]
      },
      'userAnswers': [null]
    })!;
    expect(hint.value, 14);
    expect(hint.verified, isTrue);
  });
  test('a wrong full row does not invent a compatible hint', () {
    final hint = findBoardHint('nebula_matrix', {
      'puzzle': {
        'size': 2,
        'clues': <String, int>{},
        'emptyCells': ['r0c0', 'r0c1', 'r1c0', 'r1c1'],
        'zones': <List<String>>[]
      },
      'answers': {'r0c0': 1, 'r0c1': 1}
    })!;
    expect(hint.verified, isFalse);
    expect(hint.value, isNull);
  });
  test('launch sequence hints reduce inversions against the actual target', () {
    final hint = findBoardHint('launch_sequence', {
      'sequence': [3, 1, 2],
      'puzzle': {
        'target': [1, 2, 3]
      }
    })!;
    expect(hint.target, '0');
    expect(hint.value, 1);
    expect(hint.verified, isTrue);
  });
  test('misere duel never recommends taking the final asteroid', () {
    for (int remaining = 1; remaining <= 25; remaining++) {
      final hint = findBoardHint(
          'asteroid_duel', {'_remaining': remaining, '_maxPerTurn': 3})!;
      if (hint.verified) {
        final take = hint.value as int;
        expect(take, inInclusiveRange(1, 3));
        expect(take, lessThan(remaining));
        expect((remaining - take - 1) % 4, 0);
      }
    }
  });
}
