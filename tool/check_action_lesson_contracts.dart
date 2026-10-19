// ignore_for_file: avoid_relative_lib_imports, avoid_print
import 'dart:convert';
import '../lib/features/games/game_keys.dart';
import '../lib/features/games/models/practice_lesson_catalog.dart';
import '../lib/features/games/services/action_hint_guidance.dart';
import '../lib/features/games/services/board_hint_engine.dart';
import '../lib/features/games/services/alien_tribunal_logic.dart';
import '../lib/features/games/services/crew_manifest_logic.dart';
import '../lib/features/games/services/hive_station_logic.dart';

int checks = 0;
void check(bool valid, String why) {
  checks++;
  if (!valid) throw StateError(why);
}

void main() {
  check(practiceLessons.length == 48, 'Exactly 48 registered lessons');
  check(gameKeys.toSet().difference(practiceLessons.keys.toSet()).isEmpty,
      'No missing registered lesson');
  check(practiceLessons.keys.toSet().difference(gameKeys.toSet()).isEmpty,
      'No unregistered generic substitute');
  for (final entry in practiceLessons.entries) {
    final l = entry.value;
    check(l.optionsEn.length == 3 && l.optionsDe.length == 3,
        '${entry.key}: bilingual choices');
    check(l.optionsEn.toSet().length == 3 && l.optionsDe.toSet().length == 3,
        '${entry.key}: distinct actions');
  }

  // These answers are tied to the explicit independent witnesses below. Their
  // positions deliberately vary; selecting the first button must not pass all.
  const expectedActions = {
    'asteroid_math': '6 − 3, because its result is 3',
    'puzzle_math': 'Upright on 9',
    'hyperdrive_gates': 'Through the left gate marked 5',
    'pathfinder': 'Left: 4',
    'planet_hopping': '2 + 3, because the next result is 5',
    'signal_triangulation': '1 exact position, 2 misplaced glyphs',
    'arithmancer_duel': 'No: the three cards cost 3 energy',
    'asteroid_field_navigator': 'Both are safe to reveal',
    'cargo_bay_arranger':
        'Yes; being full clears it, though its sum is only 10',
    'star_chart_scan': 'Drag straight from 3 through every character to 5',
    'comm_relay': 'CAT',
    'crew_manifest': 'Zara–map, Kip–laser, Nova–helm',
    'alien_tribunal': 'A lies; B tells the truth',
    'hive_station': 'Mark it as energy',
    'xenobiology_lab': '2 of A and 1 of B',
    'asteroid_duel': 'Take 1, leaving 5',
  };
  for (final e in expectedActions.entries) {
    final lesson = practiceLessons[e.key]!;
    check(lesson.optionsEn[lesson.correctIndex] == e.value,
        '${e.key}: button selects the witnessed action');
  }

  // Independent arithmetic/constraint examples behind the action lessons.
  check(6 - 3 < 2 * 2 && 2 * 2 < 4 + 4, 'Asteroid ordering');
  check(4 + 5 == 9 && 4 + 5 != 6, 'Jigsaw result before orientation');
  check(9 - 4 == 5 && 9 + 4 == 13, 'Gate operator distractor');
  check(8 ~/ 2 == 4 && 8 - 2 == 6 && 8 + 2 == 10, 'Path distractors');
  check(8 > 2 + 3 && 2 + 3 > 6 - 3, 'Descending planets');
  const manifest = CrewManifestPuzzle(
    size: 3,
    crewNames: ['Zara', 'Kip', 'Nova'],
    itemNames: ['Map', 'Helm', 'Laser'],
    solution: {'Zara': 'Map', 'Kip': 'Laser', 'Nova': 'Helm'},
    structuredClues: [],
  );
  check(manifest.checkSolution({'Zara': 'Map', 'Kip': 'Laser', 'Nova': 'Helm'}),
      'Crew complete one-to-one assignment');
  check(
      !manifest.checkSolution({'Zara': 'Map', 'Kip': 'Helm', 'Nova': 'Laser'}),
      'Crew negative clue excludes plausible swap');
  const tribunal = AlienTribunalPuzzle(personCount: 2, people: [
    TribunalPerson(
        name: 'A',
        isTruthTeller: false,
        statement: '',
        targetIndex: 0,
        secondTargetIndex: 1,
        claimsTruthTeller: false,
        kind: TribunalClaimKind.pair),
    TribunalPerson(
        name: 'B',
        isTruthTeller: true,
        statement: '',
        targetIndex: 0,
        claimsTruthTeller: false),
  ]);
  final consistent = [
    for (final a in [false, true])
      for (final b in [false, true])
        if (tribunal.isConsistent([a, b])) [a, b],
  ];
  check(jsonEncode(consistent) == '[[false,true]]',
      'Tribunal unique whole claims');
  check(const HexCoord(0, 0).neighbors.length == 6, 'Hive six neighbors');
  check(2 * 2 + 1 * 4 == 8 && 2 * 4 + 1 * 6 == 14, 'Xeno both totals');
  check(4 * 2 == 8 && 4 * 4 != 14 && 2 * 4 == 8 && 2 * 6 != 14,
      'Xeno distractors satisfy eyes but fail legs');
  bool winning(int n, int max) {
    if (n == 1) return false;
    for (var take = 1; take <= max && take < n; take++) {
      if (!winning(n - take, max)) return true;
    }
    return false;
  }

  check(!winning(5, 3) && winning(6, 3), 'Misere leaves opponent losing five');

  final fixtures = <String, Map<String, dynamic>>{
    'asteroid_math': {
      'targetOrder': [3, 4, 8],
      'currentTargetIndex': 1,
      'levelProblems': [
        {'expression': '2 × 2', 'answer': 4}
      ]
    },
    'puzzle_math': {
      'pieces': [
        {
          'id': 7,
          'row': 0,
          'col': 0,
          'rotation': 0,
          'problem': {'expression': '4 + 5', 'answer': 9}
        },
        {
          'id': 9,
          'row': 0,
          'col': 1,
          'rotation': 2,
          'problem': {'expression': '3 + 3', 'answer': 6}
        },
      ],
      'placedPieces': [
        [9, 9]
      ]
    },
    'hyperdrive_gates': {
      'currentProblem': {'expression': '9 − 4', 'answer': 5}
    },
    'pathfinder': {
      'currentProblem': {'expression': '8 ÷ 2', 'answer': 4}
    },
    'planet_hopping': {
      'targetSequence': [8, 5, 3],
      'nextTargetIndex': 1
    },
    'signal_triangulation': {
      'length': 3,
      'history': [
        {
          'guess': ['alpha', 'gamma', 'beta'],
          'correct': 1,
          'present': 2
        },
      ],
      'secret': ['alpha', 'beta', 'gamma']
    },
    'arithmancer_duel': {
      'engine': {'playerEnergy': 2},
      'battlefield': [
        {'cost': 1},
        {'cost': 1},
        {'cost': 1}
      ],
      'hand': []
    },
    'cargo_bay_arranger': {
      'targetSum': 12,
      'grid': [
        [
          {'value': 2},
          {'value': 3},
          {'value': 4},
          null,
        ]
      ]
    },
    'star_chart_scan': {
      '_foundEquations': [],
      'puzzle': {
        'placedEquations': [
          {
            'equation': '3+2=5',
            'startRow': 1,
            'startCol': 2,
            'direction': {'dr': 0, 'dc': 1}
          },
        ]
      }
    },
    'comm_relay': {
      '_currentShift': 1,
      'puzzle': {'cipherType': 'caesar', 'cipherText': 'DBU', 'hintLetters': []}
    },
    'crew_manifest': {'puzzle': manifest.toJson(), '_gridState': []},
    'alien_tribunal': {
      'puzzle': tribunal.toJson(),
      '_userAssignment': [
        [0, true],
        [1, true]
      ]
    },
    'hive_station': {
      'puzzle': {
        'allCells':
            const HexCoord(0, 0).neighbors.map((c) => c.toJson()).toList()
              ..add(const HexCoord(0, 0).toJson()),
        'numberHints': [
          [
            {'q': 0, 'r': 0},
            1
          ]
        ],
        'revealedHints': [
          {'q': 0, 'r': 0}
        ],
        'energyCells': [
          {'q': 1, 'r': 0}
        ],
      },
      'userMarked': [
        {'q': 1, 'r': 0}
      ]
    },
    'xenobiology_lab': {
      '_eyesA': 2,
      '_legsA': 4,
      '_eyesB': 4,
      '_legsB': 6,
      '_sliderA': 2,
      '_sliderB': 1,
      '_hasThirdType': false,
      '_totalEyes': 8,
      '_totalLegs': 14,
      '_countA': 2,
      '_countB': 1
    },
    'asteroid_duel': {'_remaining': 6, '_maxPerTurn': 3},
  };
  for (final german in [false, true]) {
    for (final e in fixtures.entries) {
      final before = jsonEncode(e.value);
      final h = actionHintGuidance(e.key, e.value, german: german)!;
      check(h['working']!.isNotEmpty && !h['working']!.contains('null'),
          '${e.key}: current-board explanation');
      check(jsonEncode(e.value) == before, '${e.key}: snapshot not mutated');
      final live = findBoardHint(e.key, e.value, german: german)!;
      check(
          live.working == h['working'] && !live.verified && live.target == null,
          '${e.key}: public entry preserves observation without proof');
      check(h['replaceMove'] == 'true', '${e.key}: no inherited solver proof');
    }
    String working(String key) =>
        actionHintGuidance(key, fixtures[key]!, german: german)!['working']!;
    check(working('asteroid_math').contains('4 → 8'),
        'Restored target skips completed three');
    check(working('planet_hopping').contains('5 → 3'),
        'Descending current targets');
    check(working('puzzle_math').contains(german ? 'Spalte 1' : 'column 1'),
        'Jigsaw uses slot-to-piece map direction');
    check(
        working('comm_relay').contains('CAT'), 'Caesar trial actually decodes');
    check(
        working('arithmancer_duel')
            .contains(german ? 'zu teuer' : 'cannot be played'),
        'Three energy exceeds two');
    check(
        working('cargo_bay_arranger')
            .contains(german ? 'Bonuschance' : 'bonus'),
        'Cargo does not require target to clear');
    check(working('xenobiology_lab').contains('14'),
        'Both current totals calculated');
  }
  // Visible information stays fixed: hidden answers must not change coaching.
  for (final key in [
    'signal_triangulation',
    'crew_manifest',
    'alien_tribunal',
    'hive_station',
    'xenobiology_lab'
  ]) {
    final state = fixtures[key]!;
    final before = actionHintGuidance(key, state);
    final changed = jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
    changed['secret'] = ['HIDDEN_SENTINEL'];
    changed['_countA'] = 999;
    final p = changed['puzzle'];
    if (p is Map) {
      p['solution'] = 'HIDDEN_SENTINEL';
      p['energyCells'] = [];
      if (p['people'] is List) {
        for (final person in p['people'] as List) {
          (person as Map)['isTruthTeller'] = 'HIDDEN_SENTINEL';
        }
      }
    }
    check(jsonEncode(before) == jsonEncode(actionHintGuidance(key, changed)),
        '$key: hidden solution independence');
  }
  print('PASS: $checks fixed action/catalog checks; no generated samples.');
}
