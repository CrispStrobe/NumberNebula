// Bounded semantic fixtures only: no generation, searches, network or Flutter.
// Run: dart tool/check_spatial_lesson_contracts.dart
import 'dart:convert';
import 'dart:math' as math;

import '../lib/features/games/models/lessons_spatial.dart';
import '../lib/features/games/services/spatial_hint_guidance.dart';
import '../lib/features/games/services/blocks_counter_logic.dart' as blocks;
import '../lib/features/games/services/circuit_repair_logic.dart';
import '../lib/features/games/services/cube_scanner_logic.dart';
import '../lib/features/games/services/dark_matter_grid_logic.dart';
import '../lib/features/games/services/hull_plating_logic.dart' as hull;
import '../lib/features/games/services/ion_chain_logic.dart';
import '../lib/features/games/services/relic_assembly_logic.dart';
import '../lib/features/games/services/robot_path_logic.dart' as robot;
import '../lib/features/games/services/sector_painter_logic.dart';
import '../lib/features/games/services/void_crossing_logic.dart';

var _checks = 0;
void check(bool condition, String contract) {
  _checks++;
  if (!condition) {
    throw StateError('Spatial lesson contract failed: $contract');
  }
}

Map<String, dynamic> clone(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
Map<String, String> guide(
  String game,
  Map<String, dynamic> snapshot, {
  bool german = false,
}) =>
    spatialHintGuidance(game, snapshot, german: german) ??
    (throw StateError('Missing spatial guidance for $game'));

void main() {
  final expectedKeys = <String>{
    'block_counter',
    'perspective_puzzle',
    'hull_plating',
    'relic_assembly',
    'grid_filler_game',
    'quantum_molecule_builder',
    'space_station_gridlock',
    'star_loader_game',
    'robot_path_game',
    'warp_fold',
    'cube_scanner',
    'circuit_repair',
    'dark_matter_grid',
    'ion_chain',
    'sector_painter',
    'void_crossing',
  };
  check(
    spatialLessons.keys.toSet().containsAll(expectedKeys) &&
        spatialLessons.length == expectedKeys.length,
    'all sixteen spatial lessons',
  );
  for (final key in expectedKeys) {
    final lesson = spatialLessons[key]!;
    check(
      lesson.optionsEn.length == 3 && lesson.optionsDe.length == 3,
      '$key has three bilingual choices',
    );
    check(
      lesson.optionsEn.toSet().length == 3 &&
          lesson.optionsDe.toSet().length == 3,
      '$key choices are distinct',
    );
    check(
      lesson.correctIndex >= 0 && lesson.correctIndex < 3,
      '$key has a usable correct choice',
    );
    check(
      [
        lesson.rulesEn,
        lesson.rulesDe,
        lesson.boardEn,
        lesson.boardDe,
        lesson.questionEn,
        lesson.questionDe,
        lesson.explanationEn,
        lesson.explanationDe,
        lesson.focusEn,
        lesson.focusDe,
        lesson.strategyEn,
        lesson.strategyDe,
      ].every((text) => text.trim().isNotEmpty),
      '$key complete teaching copy',
    );
    for (final german in [false, true]) {
      check(
        spatialHintGuidance(key, {}, german: german) == null,
        '$key missing snapshot safely returns null ($german)',
      );
    }
  }

  // A height map with six solid cubes, not three occupied floor squares.
  final structure = blocks.BlockStructure(
    blocks: [
      for (final position in [
        (0, 0, 0),
        (0, 1, 0),
        (0, 0, 1),
        (1, 0, 1),
        (1, 1, 1),
        (1, 2, 1),
      ])
        blocks.BlockPosition3D(
          x: position.$1,
          y: position.$2,
          z: position.$3,
          isVisible: true,
          color: 0,
        ),
    ],
    gridWidth: 2,
    gridDepth: 2,
    maxHeight: 3,
  );
  check(
    structure.blocks.length == 6 &&
        structure.blocks.where((b) => b.y == 0).length == 3,
    'block lesson six cubes, three ground cubes',
  );
  check(
    spatialLessons['block_counter']!.correctIndex == 1,
    'block lesson selects total rather than occupied floor',
  );

  // Real Hull validator: rotation creates a legal vertical domino; holes fail.
  final domino = hull.PlatingPiece(
    id: 7,
    cells: [(0, 0), (0, 1)],
    color: hull.Color4.red,
  );
  final vertical = domino.rotated();
  final hullBoard = [
    [true, false],
    [true, false],
  ];
  check(
    hull.HullPlatingPuzzle.validatePlacement(
      [hull.PlacedPiece(pieceId: 7, absoluteCells: vertical.cells)],
      hullBoard,
      2,
      2,
    ),
    'Hull quarter-turn fills vertical gap',
  );
  check(
    !hull.HullPlatingPuzzle.validatePlacement(
      [hull.PlacedPiece(pieceId: 7, absoluteCells: domino.cells)],
      hullBoard,
      2,
      2,
    ),
    'Hull horizontal distractor covers hole',
  );
  check(
    spatialLessons['hull_plating']!.correctIndex == 2,
    'Hull lesson selects legal rotation',
  );

  final relic = RelicAssemblyPuzzle(
    rows: 1,
    cols: 2,
    solutionTiles: [],
    playerTiles: [
      RelicTile(edges: [1, 3, 1, 1]),
      RelicTile(edges: [3, 2, 1, 4]),
    ],
    edgeValueCount: 4,
  );
  check(
    relic.validatePlacement([0, 1], [0, 3]),
    'Relic three clockwise turns matches shared 3',
  );
  check(
    !relic.validatePlacement([0, 1], [0, 0]) &&
        !relic.validatePlacement([0, 1], [0, 1]),
    'Relic unchanged and clockwise distractors both mismatch',
  );
  check(
    spatialLessons['relic_assembly']!.correctIndex == 1,
    'Relic lesson selects counterclockwise equivalent',
  );

  // Validate a real robot program, including orientation, through production
  // transition functions. No generator or shortest-path search is called.
  final robotLevel = robot.PathLevel(
    gridSize: 3,
    grid: [
      [robot.CellType.start, robot.CellType.empty, robot.CellType.empty],
      [robot.CellType.wall, robot.CellType.wall, robot.CellType.goal],
      [robot.CellType.wall, robot.CellType.wall, robot.CellType.wall],
    ],
    startRow: 0,
    startCol: 0,
    startDirection: 1,
    goalRow: 1,
    goalCol: 2,
    optimalMoves: 4,
  );
  robot.RobotCommandState? run(List<robot.RobotCommand> program) {
    robot.RobotCommandState? state = robot.RobotCommandState.start(robotLevel);
    for (final command in program) {
      if (state == null) {
        return null;
      }
      state = robot.stepRobotCommand(state, command);
    }
    return state;
  }

  final program = [
    robot.RobotCommand.forward,
    robot.RobotCommand.forward,
    robot.RobotCommand.turnRight,
    robot.RobotCommand.forward,
  ];
  final reached = run(program);
  check(
    reached?.row == 1 && reached?.col == 2,
    'Robot lesson reaches goal through production transitions',
  );
  check(
    run([
          robot.RobotCommand.forward,
          robot.RobotCommand.turnRight,
          robot.RobotCommand.forward,
          robot.RobotCommand.forward,
        ]) ==
        null,
    'Robot early turn collides with wall',
  );
  check(
    run([
          robot.RobotCommand.forward,
          robot.RobotCommand.forward,
          robot.RobotCommand.turnLeft,
          robot.RobotCommand.forward,
        ]) ==
        null,
    'Robot left-turn distractor exits board',
  );
  check(
    spatialLessons['robot_path_game']!.correctIndex == 2,
    'Robot lesson chooses valid program',
  );

  // This orientation is explicitly present in Die._allOrientations (top=2).
  final die = Die([2, 6, 3, 4, 1, 5]);
  check(
    die.top == 2 && die.front == 6 && die.right == 3 && die.bottom == 5,
    'Cube fixture has valid opposite pairs and lesson bottom',
  );
  check(
    spatialLessons['cube_scanner']!.correctIndex == 1,
    'Cube lesson selects bottom 5',
  );
  final clock = CircuitRepairPuzzle(
    correctDigits: [1, 7, 2, 3],
    displayedDigits: [7, 1, 2, 3],
    swapPosA: 0,
    swapPosB: 1,
    maxAttempts: 3,
  );
  var validClockPairs = 0;
  for (var a = 0; a < 4; a++) {
    for (var b = a + 1; b < 4; b++) {
      if (CircuitRepairPuzzle.isValidTime(clock.previewSwap(a, b))) {
        validClockPairs++;
      }
    }
  }
  check(
    validClockPairs == 1 &&
        clock.checkAnswer(0, 1) &&
        CircuitRepairPuzzle.isValidTime(clock.previewSwap(0, 1)),
    'Circuit lesson has exactly one valid repair among all six pairs',
  );
  check(
    spatialLessons['circuit_repair']!.correctIndex == 2,
    'Circuit lesson selects the actual repair',
  );
  final darkGrid = [
    [true, false, true],
    [false, false, false],
    [true, false, true],
  ];
  check(
    DarkMatterGridPuzzle.isSolved(DarkMatterGridPuzzle.toggle(darkGrid, 1, 1)),
    'Dark Matter center cross lights every cell',
  );
  check(
    !DarkMatterGridPuzzle.isSolved(
          DarkMatterGridPuzzle.toggle(darkGrid, 0, 0),
        ) &&
        !DarkMatterGridPuzzle.isSolved(
          DarkMatterGridPuzzle.toggle(darkGrid, 0, 1),
        ),
    'Dark Matter corner and edge distractors fail',
  );
  check(
    spatialLessons['dark_matter_grid']!.correctIndex == 0,
    'Dark Matter lesson chooses center',
  );

  final redRule = IonRule.fromJson({
    'kind': 'noSelfPair',
    'a': 'red',
    'b': null,
  });
  final ionLesson = [
    IonType.red,
    null,
    IonType.red,
    IonType.blue,
    null,
    IonType.blue,
  ];
  final ionSolved = List<IonType?>.from(ionLesson)
    ..[1] = IonType.blue
    ..[4] = IonType.red;
  check(
    IonChainPuzzle.validateChain(ionSolved, [redRule]),
    'Ion six-slot lesson uses both actual tray beads',
  );
  final wrongIon = List<IonType?>.from(ionSolved)..[1] = IonType.red;
  check(
    !IonChainPuzzle.validateChain(wrongIon, [redRule]),
    'Ion red distractor violates actual pair rule',
  );
  check(
    spatialLessons['ion_chain']!.correctIndex == 1,
    'Ion lesson selects blue circle for first gap',
  );
  final noRepeat = IonRule.fromJson({
    'kind': 'noRepeatAtAll',
    'a': null,
    'b': null,
  });
  check(
    !IonChainPuzzle.validateChain(
      [IonType.red, IonType.blue, IonType.green, IonType.red],
      [noRepeat],
    ),
    'Ion actual validator rejects last-first self pair',
  );
  final sector = SectorPainterPuzzle(
    regions: [0, 1, 2],
    adjacency: {
      0: {1},
      1: {0, 2},
      2: {1},
    },
    chromaticNumber: 2,
    availableColors: 2,
    positions: [
      const math.Point(0.1, 0.5),
      const math.Point(0.5, 0.5),
      const math.Point(0.9, 0.5),
    ],
  );
  check(
    sector.validateColoring({0: 0, 1: 1, 2: 0}),
    'Sector non-neighbors may share color',
  );
  check(
    !sector.validateColoring({0: 0, 1: 0, 2: 0}) &&
        !sector.validateColoring({0: 0, 2: 0}),
    'Sector same-color connection and missing sector fail',
  );
  check(
    spatialLessons['sector_painter']!.correctIndex == 2,
    'Sector lesson selects neighbor exclusion',
  );
  final sectorLesson = spatialLessons['sector_painter']!;
  check(
      sectorLesson.optionsEn[sectorLesson.correctIndex].startsWith('Green') &&
          sectorLesson.optionsDe[sectorLesson.correctIndex]
              .startsWith('Grün') &&
          !sectorLesson.boardEn.contains('blue'),
      'Sector exercise must use actual red/green palette, not nonexistent blue');
  final conflicts = [
    const ConflictRule(entityA: 'A', entityB: 'B'),
    const ConflictRule(entityA: 'B', entityB: 'C'),
  ];
  check(
    !VoidCrossingLogic.hasConflict({'A', 'C'}, conflicts) &&
        VoidCrossingLogic.hasConflict({'B', 'C'}, conflicts) &&
        VoidCrossingLogic.hasConflict({'A', 'B'}, conflicts),
    'Void first passenger B leaves safe bank, both distractors fail',
  );
  check(
    spatialLessons['void_crossing']!.correctIndex == 0,
    'Void lesson chooses central conflict entity',
  );

  // The remaining screens have no exported pure transition model. These small
  // independent witnesses check only the teaching example, not runtime input.
  final lineOfSight = [
    (depth: 0, color: 'red'),
    (depth: 1, color: 'blue'),
  ]..sort((a, b) => b.depth.compareTo(a.depth));
  check(
      lineOfSight.first.color == 'blue' &&
          spatialLessons['perspective_puzzle']!.correctIndex == 0,
      'Perspective front witness keeps nearest blue, not hidden red');
  final largeGap = <(int, int)>{(0, 1), (0, 2), (1, 1), (1, 2)};
  final smallGap = <(int, int)>{(2, 3)};
  check(
      largeGap.intersection(smallGap).isEmpty &&
          largeGap.length + smallGap.length == 5 &&
          spatialLessons['grid_filler_game']!.correctIndex == 0,
      'Filler local crop fits 2x2 plus separate 1x1 without overlap');
  check(spatialLessons['quantum_molecule_builder']!.correctIndex == 2,
      'Molecule lesson chooses obstacle stopping cell');
  check(spatialLessons['space_station_gridlock']!.correctIndex == 0,
      'Gridlock lesson chooses upward clearance');
  check(spatialLessons['star_loader_game']!.correctIndex == 1,
      'Loader lesson chooses pushing from the adjacent left square');
  final cut = const math.Point(0.75, 0.25);
  final reflected = math.Point(1 - cut.x, cut.y);
  check(
      reflected.x == 0.25 &&
          reflected.y == cut.y &&
          spatialLessons['warp_fold']!.correctIndex == 0,
      'Warp vertical reflection preserves height; no raster-hole-count claim');

  final fixtures = <String, Map<String, dynamic>>{
    'block_counter': {
      'currentPuzzle': {'blockStructure': structure.toJson()},
    },
    'perspective_puzzle': {
      'currentPuzzle': {},
      '_perspectivesToSolve': ['Back', 'Front'],
      '_currentTurnIndex': 0,
    },
    'hull_plating': {
      'puzzle': {
        'board': hullBoard,
        'pieces': [domino.toJson()],
      },
      '_usedPieceIds': [],
      '_placedPieces': [],
    },
    'relic_assembly': {
      'puzzle': relic.toJson(),
      'placement': [0, -1],
      'rotations': [0, 0],
    },
    'grid_filler_game': {
      'gridSize': 10,
      'placedPieces': [],
      'availablePieces': [
        for (var size = 1; size <= 4; size++)
          {'size': size, 'count': size, 'remainingCount': size},
      ],
    },
    'quantum_molecule_builder': {
      'grid': [
        ['wall', 'wall', 'wall', 'wall', 'wall', 'wall'],
        ['wall', 'empty', 'empty', 'empty', 'empty', 'wall'],
        ['wall', 'wall', 'wall', 'wall', 'wall', 'wall'],
      ],
      'atoms': [
        {
          'type': {'symbol': 'H'},
          'row': 1,
          'col': 1,
          'atomixIndex': 0,
        },
        {
          'type': {'symbol': 'O'},
          'row': 1,
          'col': 4,
          'atomixIndex': 8,
        },
      ],
      'movesMade': 2,
      'moveLimit': 8,
      'targetPattern': {},
    },
    'space_station_gridlock': {
      'ships': [
        {
          'row': 2,
          'col': 0,
          'length': 2,
          'isHorizontal': true,
          'isPlayer': true,
          'isBlocking': false,
        },
        {
          'row': 1,
          'col': 2,
          'length': 2,
          'isHorizontal': false,
          'isPlayer': false,
          'isBlocking': false,
        },
      ],
      'playerShipIndex': 0,
      'exitRow': 2,
    },
    'star_loader_game': {
      '_grid': [
        ['wall', 'wall', 'wall', 'wall', 'wall', 'wall'],
        ['wall', 'floor', 'floor', 'target', 'floor', 'wall'],
        ['wall', 'wall', 'wall', 'wall', 'wall', 'wall'],
      ],
      '_playerPos': [1, 1],
      '_boxPositions': [
        [2, 1],
      ],
      '_targetPositions': [
        [3, 1],
      ],
    },
    'robot_path_game': {
      'currentLevel': robotLevel.toJson(),
      'commandSequence': [
        for (final c in program) {'command': c.name},
      ],
      'maxCommands': 20,
    },
    'warp_fold': {
      '_puzzle': {
        'folds': [
          {'direction': 'left'},
          {'direction': 'top'},
        ],
        'cuts': [
          {'x': 0.75, 'y': 0.75, 'size': 0.1},
        ],
      },
    },
    'cube_scanner': {
      '_puzzle': {
        'visibleFaces': [
          {'top': 2, 'front': 6, 'right': 3, 'left': null},
        ],
        'question': {
          'kind': 'hiddenFace',
          'face': 'bottom',
          'rolls': [],
          'diceCount': 1,
        },
      },
    },
    'circuit_repair': {
      '_puzzle': clock.toJson(),
      '_currentDigits': [7, 1, 2, 3],
    },
    'dark_matter_grid': {'grid': darkGrid},
    'ion_chain': {
      'puzzle': {
        'chain': ionLesson.map((v) => v?.name).toList(),
        'availableIons': ['red', 'blue'],
        'ionTypes': ['red', 'blue'],
        'rules': [redRule.toJson()],
      },
      '_playerChain': ionLesson.map((v) => v?.name).toList(),
    },
    'sector_painter': {
      'puzzle': sector.toJson(),
      '_coloring': [
        [0, 0],
        [2, 0],
      ],
    },
    'void_crossing': {
      '_puzzle': {
        'entities': [
          {'id': 'A', 'emoji': '🦊'},
          {'id': 'B', 'emoji': '🐔'},
          {'id': 'C', 'emoji': '🌾'},
        ],
        'conflicts': conflicts.map((v) => v.toJson()).toList(),
        'boatCapacity': 1,
        'maxMoves': 9,
      },
      '_gameState': {
        'leftStation': ['A', 'C'],
        'rightStation': [],
        'onShuttle': ['B'],
        'shuttleOnLeft': true,
        'movesTaken': 0,
      },
    },
  };
  check(
    fixtures.keys.toSet().containsAll(expectedKeys),
    'frozen screen fixtures cover all sixteen games',
  );
  const hidden = {
    'correctAnswer',
    'correctIndex',
    '_correctAnswerIndex',
    'solution',
    'solutionTiles',
    'correctDigits',
    'swapPosA',
    'swapPosB',
    'correctResult',
    'correctViews',
    'dice',
  };
  Object? poison(Object? value) {
    if (value is List) {
      return value.map(poison).toList();
    }
    if (value is Map) {
      return {
        for (final item in value.entries)
          '${item.key}': hidden.contains('${item.key}')
              ? 'HIDDEN_ANSWER_POISON'
              : poison(item.value),
        for (final key in hidden)
          if (!value.containsKey(key)) key: 'HIDDEN_ANSWER_POISON',
      };
    }
    return value;
  }

  for (final entry in fixtures.entries) {
    for (final german in [false, true]) {
      final before = jsonEncode(entry.value);
      final result = spatialHintGuidance(
        entry.key,
        entry.value,
        german: german,
      );
      check(
        jsonEncode(entry.value) == before,
        '${entry.key} snapshot not mutated ($german)',
      );
      if (entry.key == 'dark_matter_grid') {
        check(
          result == null,
          'Dark Matter retains separate verified solver ($german)',
        );
        continue;
      }
      check(
        result != null &&
            result.keys.toSet().containsAll({'focus', 'strategy', 'working'}),
        '${entry.key} complete current-board guidance ($german)',
      );
      final poisoned = Map<String, dynamic>.from(
        poison(clone(entry.value)) as Map,
      );
      final poisonedResult = spatialHintGuidance(
        entry.key,
        poisoned,
        german: german,
      );
      check(
        jsonEncode(result) == jsonEncode(poisonedResult),
        '${entry.key} independent of hidden answers ($german)',
      );
      check(
        !result!.values.any(
          (v) =>
              v.contains('HIDDEN_ANSWER_POISON') ||
              v.contains('Instance of') ||
              v.contains('null'),
        ),
        '${entry.key} no raw missing-object or hidden-answer dump ($german)',
      );
    }
  }

  // Ring end and depleted supply: a previously placed green bead must disappear
  // from the candidates even though green exists among the puzzle's ion types.
  final ring = clone(fixtures['ion_chain']!);
  ring['puzzle'] = {
    'chain': [null, 'blue', null, 'red'],
    'availableIons': ['green', 'yellow'],
    'ionTypes': ['red', 'blue', 'green', 'yellow'],
    'rules': [noRepeat.toJson()],
  };
  ring['_playerChain'] = [null, 'blue', 'green', 'red'];
  var text = guide('ion_chain', ring)['working']!;
  check(
    text.contains('red star and blue circle'),
    'Ion first-slot hint sees last-slot neighbor',
  );
  check(
    text.contains('pair rules: yellow diamond.') &&
        !text.contains('pair rules: green hexagon'),
    'Ion depleted tray excludes used green, keeps available yellow',
  );
  check(
      IonChainPuzzle.validateChain(
          [IonType.yellow, IonType.blue, IonType.green, IonType.red],
          [noRepeat]),
      'Ion depleted-supply fixture still has a valid completion');
  ring['puzzle']['availableIons'] = ['green', 'green'];
  text = guide('ion_chain', ring)['working']!;
  check(
    text.contains('pair rules: green hexagon.'),
    'Ion repeated supply leaves one available green candidate',
  );
  ring['_playerChain'] = ['red', 'blue', 'green', 'red'];
  check(
    guide('ion_chain', ring)['focus']!.contains('4 and 1'),
    'Ion full ring reports last-first violation',
  );

  final sectorPalette = clone(fixtures['sector_painter']!);
  sectorPalette['puzzle']['availableColors'] = 5;
  sectorPalette['_coloring'] = [
    [0, 0],
    [2, 1],
  ];
  final colored = guide('sector_painter', sectorPalette);
  check(
    colored['focus']!.contains('sector 2'),
    'Sector hint uses screen one-based numbering',
  );
  check(
    colored['working']!.contains('red, green') &&
        colored['working']!.contains('purple, yellow, pink') &&
        !colored['working']!.contains('blue'),
    'Sector palette matches actual green/purple/pink screen palette',
  );
  sectorPalette['_coloring'] = [
    [0, 0],
    [1, 2],
    [2, 1],
  ];
  check(
    guide(
      'sector_painter',
      sectorPalette,
    )['working']!
        .contains('do not have to use exactly'),
    'Sector valid full board has no exact chromatic target',
  );
  sectorPalette['_coloring'] = [
    [0, 0],
    [1, 0],
    [2, 1],
  ];
  check(
    guide('sector_painter', sectorPalette)['focus']!.contains('1 and 2'),
    'Sector current conflict is identified with screen numbers',
  );

  final molecule = guide(
    'quantum_molecule_builder',
    fixtures['quantum_molecule_builder']!,
  );
  check(
    molecule['working']!.contains('row 2, column 2') &&
        molecule['working']!.contains('right stops at row 2, column 4') &&
        molecule['working']!.contains('not a proved solution'),
    'Molecule legal endpoint stops before occupied O, not early or through it',
  );
  final gridlock = guide(
    'space_station_gridlock',
    fixtures['space_station_gridlock']!,
  );
  check(
    gridlock['focus']!.contains('row 3') &&
        gridlock['working']!.contains('row 2, column 3') &&
        gridlock['working']!.contains('only up/down'),
    'Gridlock blocker has actual location and vertical movement axis',
  );
  // The move taught by the lesson clears row 3; down does not.
  check(
    !(0 <= 2 && 2 < 0 + 2) && (2 <= 2 && 2 < 2 + 2),
    'Gridlock blocker moved up clears lane, down still occupies lane',
  );
  final clearGridlock = clone(fixtures['space_station_gridlock']!);
  clearGridlock['ships'] = (clearGridlock['ships'] as List).take(1).toList();
  check(
    guide(
      'space_station_gridlock',
      clearGridlock,
    )['working']!
        .contains('Slide the player right'),
    'Gridlock clear lane leads to player exit action',
  );

  final finishedRelic = clone(fixtures['relic_assembly']!);
  finishedRelic['placement'] = [0, 1];
  finishedRelic['rotations'] = [0, 3];
  check(
    guide('relic_assembly', finishedRelic)['focus'] == 'Every slot is filled.',
    'Relic finished matching board never requests slot zero',
  );
  finishedRelic['rotations'] = [0, 0];
  check(
    guide('relic_assembly', finishedRelic)['working']!.contains('3 against 4'),
    'Relic full wrong board reports actual shared-edge mismatch',
  );
  final seconds = clone(fixtures['circuit_repair']!);
  seconds['_currentDigits'] = [1, 2, 3, 4, 7, 0];
  check(
    guide(
      'circuit_repair',
      seconds,
    )['working']!
        .contains('Out of range: seconds'),
    'Circuit six-digit seconds are checked',
  );
  final pushes = guide('star_loader_game', fixtures['star_loader_game']!);
  check(
    pushes['working']!.contains('right would push a box to row 2, column 4'),
    'Loader hint observes actual immediate push, one-based x/y conversion',
  );
  final warp = guide('warp_fold', fixtures['warp_fold']!);
  check(
    warp['working']!.contains('horizontal crease → vertical crease'),
    'Warp unfolds axes in reverse order',
  );
  final back = guide(
    'perspective_puzzle',
    fixtures['perspective_puzzle']!,
    german: true,
  );
  check(
    back['focus']!.contains('hinten') && !back['focus']!.contains('Back'),
    'Perspective requested direction is translated',
  );
  final voidUnsafe = clone(fixtures['void_crossing']!);
  voidUnsafe['_gameState']['leftStation'] = ['B', 'C'];
  voidUnsafe['_gameState']['onShuttle'] = ['A'];
  check(
    guide('void_crossing', voidUnsafe)['working']!.contains('🐔 + 🌾'),
    'Void current forbidden pair is identified from departing bank',
  );

  print(
    jsonEncode({
      'status': 'passed',
      'checks': _checks,
      'lessons': 16,
      'guidanceFixtures': 16,
      'languages': ['en', 'de'],
      'scope':
          'fixed semantic/model fixtures; no generation, full suite, browser or child calibration',
    }),
  );
}
