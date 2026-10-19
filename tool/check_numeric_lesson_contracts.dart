// ignore_for_file: avoid_relative_lib_imports, avoid_print
// Fixed fixtures only. No generation, network, Flutter, rendering or search.
import 'dart:convert';
import '../lib/features/games/models/lessons_numeric.dart';
import '../lib/features/games/models/practice_lesson.dart';
import '../lib/features/games/services/numeric_hint_guidance.dart';
import '../lib/features/games/services/number_walls_logic.dart';
import '../lib/features/games/services/orbital_towers_logic.dart';
import '../lib/features/games/services/solarpanel_logic.dart';
import '../lib/features/games/services/nebula_matrix_logic.dart';
import '../lib/features/games/services/cryptex_logic.dart';
import '../lib/features/games/services/kenken_logic.dart';
import '../lib/features/games/services/launch_sequence_logic.dart';

var _checks = 0;
void check(bool condition, String message) {
  _checks++;
  if (!condition) throw StateError(message);
}

List<int> numbers(String text) =>
    RegExp(r'\d+').allMatches(text).map((m) => int.parse(m[0]!)).toList();
PracticeLesson lesson(String key) =>
    numericLessons[key] ?? (throw StateError('Missing $key'));
void choices(String key, bool Function(String) valid) {
  final l = lesson(key);
  final accepted = <int>[];
  for (var i = 0; i < l.optionsEn.length; i++) {
    if (valid(l.optionsEn[i])) accepted.add(i);
  }
  check(accepted.length == 1 && accepted.single == l.correctIndex,
      '$key must have exactly one semantically correct option: $accepted');
  check(
      numbers(l.optionsEn[l.correctIndex]).join(',') ==
          numbers(l.optionsDe[l.correctIndex]).join(','),
      '$key EN/DE answer quantities differ');
}

void main() {
  check(numericLessons.length == 16, 'Expected exactly 16 numeric games');
  for (final entry in numericLessons.entries) {
    final l = entry.value;
    check(
        l.optionsEn.length == 3 &&
            l.optionsDe.length == 3 &&
            l.correctIndex >= 0 &&
            l.correctIndex < 3,
        '${entry.key} choice structure');
    check(l.optionsEn.toSet().length == 3 && l.optionsDe.toSet().length == 3,
        '${entry.key} duplicate choices');
    check(
        [
          l.rulesEn,
          l.rulesDe,
          l.boardEn,
          l.boardDe,
          l.questionEn,
          l.questionDe,
          l.explanationEn,
          l.explanationDe,
          l.focusEn,
          l.focusDe,
          l.strategyEn,
          l.strategyDe
        ].every((s) => s.trim().isNotEmpty),
        '${entry.key} missing teaching text');
  }

  // Star fixture is deliberately the two specified intersecting lines, not a
  // manufactured claim about an unseen full star completion.
  choices('star_forge', (s) {
    final x = int.parse(s);
    return 1 + 6 + 10 + x == 22 && 2 + 7 + 8 + x == 22;
  });
  final wall = NumberWallPuzzle(
      wallHeight: 3,
      operation: WallOperation.addition,
      hiddenCells: {2},
      visibleValues: {0: 13, 1: 7, 3: 3, 4: 4, 5: 2},
      fullSolution: [13, 7, 6, 3, 4, 2],
      numberPool: [8, 9, 6]);
  choices('number_walls', (s) => wall.validateSolution([int.parse(s)]));
  for (final operation in [WallOperation.subtraction, WallOperation.division]) {
    final model = NumberWallPuzzle(
        wallHeight: 2,
        operation: operation,
        hiddenCells: {0},
        visibleValues: {1: 2, 2: 8},
        fullSolution: [],
        numberPool: [4, 6]);
    check(
        model
            .validateSolution([operation == WallOperation.subtraction ? 6 : 4]),
        'Wall uses abs difference and either exact division orientation');
    check(
        !model.validateSolution(
            [operation == WallOperation.subtraction ? -6 : 3]),
        'Wall rejects signed difference / wrong quotient');
  }
  choices('orbital_towers', (s) {
    final row = [2, numbers(s).first, 1, 3];
    return row.toSet().length == 4 &&
        row.every((v) => v >= 1 && v <= 4) &&
        OrbitalTowersPuzzle.visibilityAlongLine(row).where((v) => v).length ==
            2;
  });
  check(
      OrbitalTowersPuzzle.visibilityAlongLine([2, 4, 1, 3]).join(',') ==
          'true,true,false,false',
      'Visibility must hide both shorter towers behind 4');
  check(
      OrbitalTowersPuzzle.visibilityAlongLine([3, 1, 4, 2])
              .where((v) => v)
              .length ==
          2,
      'Sightline direction changes height order');
  choices('magic_triangles', (s) {
    final x = int.parse(s);
    return {1, 6, 2, 4, 3, x}.length == 6 &&
        1 + 6 + 2 == 9 &&
        2 + 4 + 3 == 9 &&
        1 + x + 3 == 9;
  });
  choices('arithmatic_square', (s) {
    final x = int.parse(s);
    return (2 + x) * 3 == 18 && x + 1 == 5;
  });
  check(
      lesson('arithmatic_square').boardEn.contains('(2 + X)') &&
          lesson('arithmatic_square').boardDe.contains('(2 + X)'),
      'Mixed-operation teaching fixture needs explicit grouping');
  choices('arithmancer_crosswords', (s) {
    final x = int.parse(s);
    return x + 3 == 8 && 2 * x == 10;
  });
  final solar = SolarPanelPuzzle(
      baseNumbers: [2, 3, 4],
      hiddenCells: {0},
      visibleValues: {1: 6, 2: 12, 3: 2, 4: 3, 5: 4},
      fullSolution: [18, 6, 12, 2, 3, 4],
      numberPool: [72, 18, 24]);
  choices('solarpanel_game', (s) => solar.validateSolution([int.parse(s)]));
  check(!solar.validateSolution([72]),
      'Solar top must add, not multiply middle panels');
  choices('codebreaker', (s) {
    final n = numbers(s);
    return n.length == 2 && n[0] + 3 == 8 && 2 * n[0] == n[1];
  });
  final cryptexSum = CryptexEquation(
      leftOperandIndices: [0, 1],
      operator: '+',
      rightSide: 9,
      resultDialIndex: null);
  final cryptexProduct = CryptexEquation(
      leftOperandIndices: [1, 2],
      operator: '*',
      rightSide: 12,
      resultDialIndex: null);
  choices('cryptex_lock_breaker', (s) {
    final dials = [5, 4, 2];
    final value = numbers(s).single;
    if (s.startsWith('SetC') || s.startsWith('Set C')) {
      dials[2] = value;
    } else if (s.startsWith('SetB') || s.startsWith('Set B')) {
      dials[1] = value;
    } else {
      dials[0] = value;
    }
    return cryptexSum.isSatisfied(dials) && cryptexProduct.isSatisfied(dials);
  });
  check(
      CryptexEquation(
              leftOperandIndices: [0, 1],
              operator: '-',
              rightSide: 5,
              resultDialIndex: null)
          .isSatisfied([2, 7]),
      'Cryptex subtraction currently uses absolute difference');
  check(
      CryptexEquation(
              leftOperandIndices: [0, 1],
              operator: '/',
              rightSide: 3,
              resultDialIndex: null)
          .isSatisfied([7, 2]),
      'Cryptex current quotient truncation must be disclosed, not silently changed');
  choices('kenken', (s) {
    final x = int.parse(s);
    return {1, 2, x, 4}.length == 4 &&
        x >= 1 &&
        x <= 4 &&
        KenkenMultiplication().calculate([2, x]) == 6;
  });
  final matrixValues = <String, int>{};
  final rows = [
    [1, 2, 3, 4],
    [3, 4, 1, 2],
    [2, 1, 4, 3],
    [4, 3, 2, 1]
  ];
  for (var r = 0; r < 4; r++) {
    for (var c = 0; c < 4; c++) {
      if (r != 0 || c != 1) matrixValues['r${r}c$c'] = rows[r][c];
    }
  }
  final matrix = NebulaMatrixPuzzle(
      size: 4,
      solution: {},
      clues: matrixValues,
      emptyCells: {'r0c1'},
      numberPool: [2, 3, 4],
      zones: NebulaMatrixPuzzle.buildZones(4));
  choices(
      'nebula_matrix', (s) => matrix.validateSolution({'r0c1': int.parse(s)}));
  check(
      NebulaMatrixPuzzle.buildZones(3).isEmpty &&
          NebulaMatrixPuzzle.buildZones(5).isEmpty,
      'Do not invent regions for size3/5');
  choices('gravity_well', (s) {
    final n = numbers(s);
    return n.length == 2 && n[0] + 2 == 8 && n[0] + n[1] == 10;
  });
  choices('galactic_market', (s) {
    final coin = int.parse(s);
    return 5 + 2 + 3 * coin == 22;
  });
  choices('chrono_repair', (s) {
    final n = numbers(s);
    return n.length == 2 && n[0] * 60 + n[1] + 90 == 3 * 60 + 10;
  });
  choices('vault_cracker', (s) {
    final n = numbers(s);
    return n.length == 3 &&
        n.every((v) => v >= 1 && v <= 5) &&
        n[0] == 2 &&
        n.reduce((a, b) => a + b) == 6 &&
        n[2] == n[0] + n[1];
  });
  choices('launch_sequence', (s) {
    if (!s.startsWith('Tap 3')) return false;
    final row = [1, 3, 2, 4];
    final old = row[1];
    row[1] = row[2];
    row[2] = old;
    return LaunchSequencePuzzle.isSorted(row);
  });
  check(LaunchSequencePuzzle.countInversions([1, 3, 2, 4]) == 1,
      'Launch fixture is one adjacent inversion');

  void guidance(String key, Map<String, dynamic> state, List<String> required,
      {bool verified = false}) {
    final before = jsonEncode(state);
    for (final german in [false, true]) {
      final result = numericHintGuidance(key, state, german: german);
      check(
          result != null &&
              ['focus', 'strategy', 'working']
                  .every((k) => result[k]?.trim().isNotEmpty ?? false),
          '$key needs bilingual readable live guidance');
      final text = result!.values.join('\n');
      for (final snippet in required) {
        check(text.contains(snippet),
            '$key guidance missing actual fixture fact $snippet');
      }
      check(
          !text.contains('PRIVATE_SOLUTION_SENTINEL') &&
              !text.contains('null') &&
              !text.contains('{'),
          '$key leaks solution or map/null dump');
      check(jsonEncode(state) == before, '$key hint mutated snapshot');
      if (verified) {
        check(
            state['_hintVerified'] == true &&
                state['_hintTarget'] != null &&
                state['_hintValue'] != null,
            '$key changed original same-move metadata');
        check(!result.containsKey('replaceMove'),
            '$key unexpectedly replaced original solver move');
      }
    }
  }

  Map<String, dynamic> metadata(String target, int value) =>
      {'_hintTarget': target, '_hintValue': value, '_hintVerified': true};
  guidance(
      'star_forge',
      {
        'puzzle': {
          'clues': {'0': 1, '1': 6, '2': 10, '4': 2, '5': 7, '6': 8},
          'lines': [
            [0, 1, 2, 3],
            [4, 5, 6, 3]
          ],
          'magicConstant': 22,
          'solution': 'PRIVATE_SOLUTION_SENTINEL'
        },
        'answers': {},
        ...metadata('3', 5)
      },
      ['[5]', '1 + 6 + 10', '22'],
      verified: true);
  guidance(
      'number_walls',
      {
        'puzzle': wall.toJson(),
        'answers': [null],
        ...metadata('2', 6)
      },
      ['[6]', '4 + 2', '13'],
      verified: true);
  guidance(
      'solarpanel_game',
      {
        'puzzle': solar.toJson(),
        'userAnswers': [null],
        ...metadata('0', 18)
      },
      ['[18]', '6 + 12'],
      verified: true);
  final grid = {
    'size': 4,
    'clues': {'r0c0': 1, 'r0c2': 3, 'r0c3': 4},
    'edgeClues': {'left_0': 4},
    'cages': [
      {
        'clue': '6×',
        'cells': ['r0c1', 'r1c1']
      }
    ],
    'zones': [
      ['r0c0', 'r0c1', 'r1c0', 'r1c1']
    ],
    'solution': 'PRIVATE_SOLUTION_SENTINEL'
  };
  for (final key in ['orbital_towers', 'nebula_matrix', 'kenken']) {
    guidance(
        key, {'puzzle': grid, 'answers': {}, ...metadata('r0c1', 2)}, ['[2]'],
        verified: true);
  }
  guidance('arithmatic_square', {
    'puzzle': {
      'gridSize': 4,
      'clues': [
        ['r0c0', 2],
        ['r0c2', 3],
        ['r0c3', 18]
      ],
      'playerHints': [],
      'rowOperators': [
        ['+', '×'],
        ['+', '+'],
        ['+', '+'],
        ['+', '+']
      ],
      'columnOperators': [
        ['+', '+'],
        ['+', '+'],
        ['+', '+'],
        ['+', '+']
      ],
      'fullSolution': 'PRIVATE_SOLUTION_SENTINEL'
    },
    'userSolution': []
  }, [
    '((2 + □) × 3) = 18'
  ]);
  guidance('arithmatic_square', {
    'puzzle': {
      'gridSize': 3,
      'clues': [
        ['r0c0', 2],
        ['r0c1', 3],
        ['r0c2', 9]
      ],
      'rowOperators': [
        ['+'],
        ['+'],
        ['+']
      ],
      'columnOperators': [
        ['+'],
        ['+'],
        ['+']
      ]
    },
    'userSolution': []
  }, [
    '(2 + 3) = 9'
  ]);
  guidance('arithmancer_crosswords', {
    'puzzle': {
      'clues': [
        ['C_0_0', 2],
        ['C_0_4', 10]
      ],
      'equations': [
        {
          'numberCells': [
            [0, 0],
            [2, 0],
            [4, 0]
          ],
          'operator': '×'
        }
      ]
    },
    'userSolution': []
  }, [
    '2 × □ = 10'
  ]);
  guidance('codebreaker', {
    'puzzle': {
      'knownSymbolValues': {'★': 5},
      'equations': [
        {'term1': 2, 'term2': '★', 'op': '*', 'result': '●'}
      ],
      '_fullSolution': 'PRIVATE_SOLUTION_SENTINEL'
    },
    'answers': {}
  }, [
    '★(5)',
    '×',
    '●'
  ]);
  guidance('cryptex_lock_breaker', {
    'currentPuzzle': {
      'equations': [cryptexSum.toJson(), cryptexProduct.toJson()],
      'solution': 'PRIVATE_SOLUTION_SENTINEL'
    },
    'dialValues': [5, 4, 2]
  }, [
    'B(4)',
    'C(2)',
    '12',
    '8'
  ]);
  guidance('cryptex_lock_breaker', {
    'currentPuzzle': {
      'equations': [
        CryptexEquation(
                leftOperandIndices: [0, 1],
                operator: '/',
                rightSide: 4,
                resultDialIndex: null)
            .toJson()
      ]
    },
    'dialValues': [7, 2]
  }, [
    '3'
  ]);
  guidance('gravity_well', {
    'puzzle': {
      'scales': [
        {
          'leftSide': [
            {'label': 'A', 'isKnown': false},
            {'weight': 2, 'isKnown': true}
          ],
          'rightSide': [
            {'weight': 8, 'isKnown': true}
          ]
        }
      ],
      'unknownWeights': 'PRIVATE_SOLUTION_SENTINEL'
    },
    '_userAnswers': [
      ['A', 6]
    ]
  }, [
    'A + 2 kg = 8 kg',
    'A = 6 kg'
  ]);
  guidance('galactic_market', {
    '_changeTotal': 22,
    '_knownCoins': [5, 2],
    '_unknownCount': 3,
    '_correctDenomination': 'PRIVATE_SOLUTION_SENTINEL'
  }, [
    '22 − 7 = 15',
    '15 ÷ 3 = 5'
  ]);
  guidance('chrono_repair', {
    '_displayedHour': 3,
    '_displayedMinute': 10,
    '_malfunction': 'combined',
    '_offsetHours': 1,
    '_offsetMinutes': 30,
    '_correctHour': 'PRIVATE_SOLUTION_SENTINEL'
  }, [
    '1:40'
  ]);
  guidance('chrono_repair', {
    '_displayedHour': 8,
    '_displayedMinute': 20,
    '_malfunction': 'mirror',
    '_correctMinute': 'PRIVATE_SOLUTION_SENTINEL'
  }, [
    '3:40'
  ]);
  guidance('chrono_repair', {
    '_displayedHour': 12,
    '_displayedMinute': 15,
    '_malfunction': 'offset',
    '_offsetHours': 1,
    '_offsetMinutes': 30
  }, [
    '10:45'
  ]);
  guidance('vault_cracker', {
    'puzzle': {
      'clues': [
        {'en': 'The first digit is2.', 'de': 'Die erste Ziffer ist2.'}
      ],
      'secretCode': 'PRIVATE_SOLUTION_SENTINEL'
    },
    'answer': [2, null, null]
  }, [
    '2 · □ · □'
  ]);
  check(
      numericHintGuidance('galactic_market', {
            '_changeTotal': 22,
            '_knownCoins': [5, 2],
            '_unknownCount': 0
          }) ==
          null,
      'Zero coin count must not divide');
  check(
      numericHintGuidance('galactic_market', {
            '_changeTotal': 22,
            '_knownCoins': [5, 2],
            '_unknownCount': 4
          }) ==
          null,
      'Inexact coin division must not claim a denomination');
  for (final key in [
    'star_forge',
    'number_walls',
    'solarpanel_game',
    'orbital_towers',
    'nebula_matrix',
    'kenken'
  ]) {
    check(numericHintGuidance(key, {'puzzle': {}}) == null,
        '$key cannot invent solver proof without metadata');
  }
  for (final key in ['magic_triangles', 'launch_sequence']) {
    check(numericHintGuidance(key, {'puzzle': {}}) == null,
        '$key deliberately retains verified engine guidance');
  }
  print(
      'PASS: 16 numeric lesson contracts; bilingual fixed-board guidance; $_checks bounded checks. No generation, stress run, rendering, or child-difficulty claims.');
}
