import 'kenken_logic.dart' as kenken;
import 'dart:convert';
import 'dart:math' as math;
import '../game_keys.dart';
export '../game_keys.dart';
import '../constants/difficulty_manager.dart';
import '../models/math_problem.dart';
import '../models/starloader_level_model.dart';
import '../../../shared/utils/arithmancer.dart' as duel;
import 'generator_random.dart';
import 'generation_configs.dart';
import 'round_generation.dart';
import 'molecule_level_data.dart';
import 'gridlock_level_data.dart';
import 'sokoban_generator.dart' as sokoban;
import 'alien_tribunal_logic.dart' as alien_tribunal;
import 'arithmetic_square_logic.dart' as arithmetic_square;
import 'arithmancer_crosswords_logic.dart' as arithmancer_crosswords;
import 'asteroid_duel_logic.dart' as asteroid_duel;
import 'blocks_counter_logic.dart' as blocks_counter;
import 'cargo_generation.dart' as cargo;
import 'chrono_repair_logic.dart' as chrono_repair;
import 'circuit_repair_logic.dart' as circuit_repair;
import 'codebreaker_logic.dart' as codebreaker;
import 'comm_relay_logic.dart' as comm_relay;
import 'crew_manifest_logic.dart' as crew_manifest;
import 'cryptex_logic.dart' as cryptex;
import 'cube_scanner_logic.dart' as cube_scanner;
import 'dark_matter_grid_logic.dart' as dark_matter_grid;
import 'galactic_market_logic.dart' as galactic_market;
import 'gravity_well_logic.dart' as gravity_well;
import 'hive_station_logic.dart' as hive_station;
import 'hull_plating_logic.dart' as hull_plating;
import 'ion_chain_logic.dart' as ion_chain;
import 'launch_sequence_logic.dart' as launch_sequence;
import 'magic_triangle_puzzle.dart' as magic_triangle;
import 'nebula_matrix_logic.dart' as nebula_matrix;
import 'number_walls_logic.dart' as number_walls;
import 'orbital_towers_logic.dart' as orbital_towers;
import 'perspective_logic.dart' as perspective;
import 'relic_assembly_logic.dart' as relic_assembly;
import 'robot_path_logic.dart' as robot_path;
import 'sector_painter_logic.dart' as sector_painter;
import 'solarpanel_logic.dart' as solarpanel;
import 'star_chart_scan_logic.dart' as star_chart_scan;
import 'star_forge_logic.dart' as star_forge;
import 'vault_cracker_logic.dart' as vault_cracker;
import 'void_crossing_logic.dart' as void_crossing;
import 'warp_fold_logic.dart' as warp_fold;
import 'xenobiology_lab_logic.dart' as xenobiology_lab;

/// Only decoded assets are injected. This library has no IO, widgets, plugins,
/// platform channels, or Flutter dependency; CLI and tests use identical logic.
class GenerationAssets {
  final List<Map<String, dynamic>> molecules;
  final GridlockLevelDatabase gridlock;
  final LevelDatabase starloader;
  GenerationAssets(
      {required String moleculeSource,
      required String gridlockSource,
      required String starloaderSource})
      : molecules = parseMoleculeLevels(moleculeSource),
        gridlock = GridlockLevelDatabase.fromJson(gridlockSource),
        starloader = LevelDatabase.fromJson(jsonDecode(starloaderSource));
}

Future<Map<String, dynamic>> generateGameBoard(
        String game, int grade, int level,
        {required int seed,
        required GenerationAssets assets,
        bool freshSokoban = false,
        String? language,
        String? mechanic}) =>
    withGeneratorSeed(seed, () async {
      if (!gameKeys.contains(game)) throw ArgumentError.value(game, 'game');
      if (grade < 1 || grade > 6 || level < 1 || level > 20) {
        throw ArgumentError('Grade 1..6, level 1..20 required');
      }
      final settings = GenerationSettings(grade: grade);
      final difficulty = DifficultyManager.getDifficulty(settings, level);
      final g = difficulty.grade, l = difficulty.level;
      final args = <String, dynamic>{
        'grade': grade,
        'level': level,
        'difficulty': difficulty,
        'useCSP': codebreaker.USE_CSP_GENERATION,
        'useCustomSettings': false,
        'customOps': <String>[],
        'customMin': 1,
        'customMax': 20
      };
      Map<String, dynamic> puzzle(dynamic model) {
        final p = Map<String, dynamic>.from(model.toJson() as Map);
        return {
          'puzzle': p,
          'numberPool': p['numberPool'] ?? <int>[],
          'userSolution': <String, int>{},
          '_coloring': <String, int>{},
          '_currentShift': 0,
          '_playerChain': p['chain'] ?? <dynamic>[],
          '_currentDigits': p['displayedDigits'] ?? <int>[]
        };
      }

      switch (game) {
        case 'magic_triangles':
          return puzzle(magic_triangle.MagicTrianglePuzzle.generate(
              {'grade': grade, 'level': level}));
        case 'number_walls':
          return puzzle(number_walls.NumberWallPuzzle.generate(args));
        case 'solarpanel_game':
          return puzzle(solarpanel.SolarPanelPuzzle.generate(args));
        case 'arithmatic_square':
          return puzzle(
              await arithmetic_square.ArithmeticSquarePuzzle.generate(args));
        case 'kenken':
          return puzzle(await kenken.KenkenPuzzle.generate(args));
        case 'arithmancer_crosswords':
          return puzzle(
              await arithmancer_crosswords.CrosswordPuzzle.generate(args));
        case 'codebreaker':
          return puzzle(
              await codebreaker.AdvancedCodebreakerPuzzle.generate(args));
        case 'alien_tribunal':
          return puzzle(alien_tribunal.AlienTribunalLogic.generate(args));
        case 'crew_manifest':
          return puzzle(crew_manifest.CrewManifestLogic.generate(args));
        case 'gravity_well':
          return puzzle(gravity_well.GravityWellLogic.generate(args));
        case 'vault_cracker':
          return puzzle(vault_cracker.VaultCrackerLogic.generate(args));
        case 'cryptex_lock_breaker':
          return puzzle(cryptex.CryptexPuzzle.generate(grade, level));
        case 'block_counter':
          return puzzle(blocks_counter.BlockCountingPuzzle.generate(
              {'grade': grade, 'level': level}));
        case 'perspective_puzzle':
          return {
            '_perspectivesToSolve': ['Front', 'Back', 'Left', 'Right'],
            '_currentTurnIndex': 0,
            ...puzzle(perspective.PerspectivePuzzle.generate(
                {'grade': grade, 'level': level}))
          };
        case 'warp_fold':
          return puzzle(
              warp_fold.WarpFoldGenerator().generate(grade: g, level: l));
        case 'cube_scanner':
          return puzzle(
              cube_scanner.CubeScannerGenerator().generate(grade: g, level: l));
        case 'circuit_repair':
          return puzzle(circuit_repair.CircuitRepairGenerator()
              .generate(grade: g, level: l));
        case 'sector_painter':
          return puzzle(sector_painter.SectorPainterGenerator()
              .generate(grade: g, level: l));
        case 'hull_plating':
          return puzzle(
              hull_plating.HullPlatingPuzzle.generate(grade: g, level: l));
        case 'star_chart_scan':
          return puzzle(star_chart_scan.StarChartScanPuzzle.generate(
              gridSize: g <= 1
                  ? 7
                  : g <= 2
                      ? 8
                      : g <= 3
                          ? 9
                          : 10,
              equationCount: g <= 1
                  ? 3
                  : g <= 2
                      ? 5
                      : g <= 3
                          ? 6
                          : 8,
              allowDiagonal: g >= 3,
              operators: g <= 1
                  ? ['+']
                  : g <= 2
                      ? ['+', '-']
                      : g <= 3
                          ? ['+', '-', 'x']
                          : ['+', '-', 'x']));
        case 'comm_relay':
          return puzzle(comm_relay.CommRelayPuzzle.generate(
              grade: g,
              level: l,
              isGerman: language == null ? seed.isOdd : language == 'de',
              cipherTypeOverride: mechanic == null
                  ? null
                  : comm_relay.CipherType.values.byName(mechanic)));
        case 'star_forge':
          final c = StarForgeGenerationConfig(g, l);
          return puzzle(await star_forge.StarForgeGenerator().generate(
              points: c.getStarPoints(), clueCount: c.getClueCount()));
        case 'nebula_matrix':
          final c = NebulaMatrixGenerationConfig(g, l);
          return puzzle(await nebula_matrix.NebulaMatrixGenerator()
              .generate(size: c.getGridSize(), clueCount: c.getClueCount()));
        case 'orbital_towers':
          final c = OrbitalTowersGenerationConfig(g, l);
          return puzzle(await orbital_towers.OrbitalTowersGenerator().generate(
              size: c.getGridSize(),
              edgeClueCount: c.getEdgeClueCount(),
              cellClueCount: c.getCellClueCount()));
        case 'hive_station':
          final c = HiveStationGenerationConfig(g, l);
          return puzzle(await hive_station.HiveStationGenerator().generate(
              radius: c.getRadius(),
              energyFraction: c.getEnergyFraction(),
              hintFraction: c.getHintFraction()));
        case 'relic_assembly':
          final c = RelicAssemblyGenerationConfig(g, l);
          return puzzle(await relic_assembly.RelicAssemblyGenerator().generate(
              rows: c.getRows(),
              cols: c.getCols(),
              edgeValueCount: c.getEdgeValueCount()));
        case 'dark_matter_grid':
          final size = g <= 1
              ? 3
              : g <= 2
                  ? 4
                  : 5;
          final p = dark_matter_grid.DarkMatterGridPuzzle.generate(
              gridSize: size,
              toggleCount: (size + l).clamp(3, size * size - 1));
          return {...puzzle(p), 'grid': p.grid, 'moves': 0};
        case 'launch_sequence':
          final config = launch_sequence.LaunchSequenceGenerationConfig(g, l);
          final p = launch_sequence.LaunchSequencePuzzle.generate(
              itemCount: config.itemCount, minInversions: config.inversions);
          return {...puzzle(p), 'sequence': p.sequence};
        case 'ion_chain':
          return puzzle(ion_chain.IonChainPuzzle.generate(
              chainLength: g <= 1
                  ? 5
                  : g <= 2
                      ? 6 + (l > 5 ? 1 : 0)
                      : 7 + (l > 5 ? 2 : 0),
              ionTypeCount: g <= 2 ? 3 : 4,
              ruleCount: g <= 1
                  ? 1
                  : g <= 2
                      ? 1 + (l > 5 ? 1 : 0)
                      : 2 + (l > 8 ? 1 : 0),
              blanksToRemove: g <= 1
                  ? 2
                  : g <= 2
                      ? 3
                      : 3 + (l > 5 ? 1 : 0)));
        case 'void_crossing':
          final p =
              void_crossing.VoidCrossingLogic.generatePuzzle(grade, level);
          return {
            '_puzzle': p.toJson(),
            '_gameState':
                void_crossing.VoidCrossingLogic.createInitialState(p).toJson()
          };
        case 'chrono_repair':
          return chrono_repair.generateChronoRepair(g, l);
        case 'galactic_market':
          return galactic_market.generateGalacticMarket(g, l);
        case 'xenobiology_lab':
          return xenobiology_lab.generateXenobiologyLab(g, l);
        case 'asteroid_duel':
          return asteroid_duel.generateAsteroidDuel(g, l);
        case 'robot_path_game':
          final p = robot_path.PathLevel.generate(grade, level);
          return {
            'currentLevel': p.toJson(),
            'maxCommands': p.commandAllowance,
            'commandSequence': <dynamic>[]
          };
        case 'signal_triangulation':
          return generateSignalRound(grade, level);
        case 'asteroid_field_navigator':
          final complexity = grade + level / 5;
          final (size, count) = complexity <= 2.5
              ? (6, 6)
              : complexity <= 3.5
                  ? (8, 10)
                  : complexity <= 4.5
                      ? (10, 15)
                      : complexity <= 5.5
                          ? (12, 25)
                          : complexity <= 6.5
                              ? (15, 40)
                              : (20, 70);
          return {
            'gridRows': size,
            'gridCols': size,
            'mineCount': count,
            'grid': generateMineField(size, size, count)
                .map((r) => r.map((c) => c.toJson()).toList())
                .toList(),
            'isFirstClick': true
          };
        case 'grid_filler_game':
          final n = gridFillerPieceTypes(grade, level);
          return {
            '_pieceTypes': n,
            'gridSize': n * (n + 1) ~/ 2,
            'availablePieces': [
              for (int i = 1; i <= n; i++)
                {'size': i, 'count': i, 'remainingCount': i}
            ],
            'placedPieces': <dynamic>[]
          };
        case 'asteroid_math':
          final problems = generateAsteroidProblems(settings, level,
              const NoProblemReviews(), difficulty.objectCount);
          final order = problems.map((p) => p.answer).toList()..sort();
          return {
            'levelProblems': problems.map((p) => p.toJson()).toList(),
            'targetOrder': order,
            'currentTargetIndex': 0,
            'timeLeft': difficulty.timeLimit
          };
        case 'planet_hopping':
          final problems = generatePlanetProblems(
              settings,
              level,
              const NoProblemReviews(),
              (5 + (grade + level) / 4).clamp(5, 8).toInt());
          final order = problems.map((p) => p.answer).toList()..sort();
          return {
            'planets': [
              for (final p in problems) {'problem': p.toJson()}
            ],
            'targetSequence':
                grade > 1 && level.isEven ? order.reversed.toList() : order,
            'nextTargetIndex': 0
          };
        case 'hyperdrive_gates':
        case 'pathfinder':
          final p = MathProblem.generateProblem(
              settings, level, const NoProblemReviews());
          final count = game == 'pathfinder'
              ? math.min(5, 2 + grade ~/ 2)
              : generatorRandom().nextInt(2) + 2;
          return {
            'currentProblem': p.toJson(),
            'choices': game == 'pathfinder'
                ? generatePathAnswers(p, count)
                : p.generateMultipleChoiceOptions(optionsCount: count)
          };
        case 'puzzle_math':
          final columns = grade <= 2 ? 2 : 3,
              rows = grade <= 1
                  ? 2
                  : grade <= 3
                      ? 3
                      : 4;
          final problems = generateJigsawProblems(
              settings, level, const NoProblemReviews(), columns * rows);
          return {
            'columns': columns,
            'rows': rows,
            'pieces': [
              for (int i = 0; i < problems.length; i++)
                {
                  'id': i,
                  'problem': problems[i].toJson(),
                  'row': i ~/ columns,
                  'col': i % columns
                }
            ],
            'placedPieces': <dynamic>[]
          };
        case 'cargo_bay_arranger':
          final config = cargo.CargoGenerationConfig(grade, level);
          final bag = cargo.CargoShapeBag();
          return {
            'numberMin': config.numberMin,
            'numberMax': config.numberMax,
            'targetSum': config.targetSum,
            'dropSpeed': config.dropSpeed,
            'rowsToWin': config.rowsToWin,
            'currentPiece': cargo.CargoPiece.random(
                    config.numberMin, config.numberMax, 8,
                    shapeIndex: bag.next(7),
                    targetSum: config.targetSum,
                    sequenceChance: 0.30,
                    targetSumChance: 0.30)
                .toJson(),
            'nextPiece': cargo.CargoPiece.random(
                    config.numberMin, config.numberMax, 8,
                    shapeIndex: bag.next(7),
                    targetSum: config.targetSum,
                    sequenceChance: 0.30,
                    targetSumChance: 0.30)
                .toJson()
          };
        case 'arithmancer_duel':
          final ai = level % 3 == 0
              ? duel.PrimeHunterAI()
              : level % 3 == 1
                  ? duel.SequenceWeaverAI()
                  : duel.DefensiveMathAI();
          final engine =
              duel.ArithmancerGame(ai, generatorRandom(), verbose: false);
          engine.startNewBattle();
          return {
            'engine': engine.toJson(),
            'hand': engine.hand.map((c) => c.toJson()).toList(),
            'battlefield': <dynamic>[]
          };
        case 'space_station_gridlock':
          final raw = grade + level / 10;
          final complexity = raw < 1.7
              ? 1.0
              : raw < 2.4
                  ? 2.0
                  : raw < 3.3
                      ? 3.0
                      : raw < 4.2
                          ? 4.0
                          : raw < 5
                              ? 5.0
                              : raw < 5.7
                                  ? 6.0
                                  : 7.0;
          final pool = assets.gridlock.byComplexity(complexity);
          final p = pool[generatorRandom().nextInt(pool.length)];
          return {
            'ships': p.ships,
            'playerShipIndex': 0,
            'exitRow': 2,
            'minMoves': p.minMoves,
            '_currentPuzzleId': p.id,
            '_currentComplexity': p.complexity
          };
        case 'quantum_molecule_builder':
          final index = (level - 1).clamp(0, assets.molecules.length - 1);
          final p = assets.molecules[index];
          final count = (p['playfield'] as List)
              .expand((r) => r as List)
              .where((c) => c['type'] == 'atom')
              .length;
          final moveLimit = ((p['duration'] / 4.5 + count * 1.5) *
                  (grade == 1
                      ? 1.3
                      : grade == 2
                          ? 1.2
                          : grade == 3
                              ? 1.1
                              : 1.0))
              .round()
              .clamp(20, 150);
          return {
            '_currentLevel': index + 1,
            'levelData': p,
            'atoms': [
              for (final row in p['playfield'] as List)
                for (final c in row as List)
                  if (c['type'] == 'atom') c
            ],
            'targetPattern': p['solution'],
            'moveLimit': moveLimit
          };
        case 'star_loader_game':
          final d = ((const {1: 2, 2: 3, 3: 4, 4: 5}[grade] ?? 5) +
                  (level ~/ 4).clamp(0, 2))
              .clamp(1, 10);
          final target = sokoban.PARAMS[d]!.minPushes;
          if (freshSokoban) {
            final p = sokoban.generate(d, seed: seed, timeBudget: 0.5);
            return {
              'ascii': p.ascii(),
              'solution': p.solution,
              'stats': p.stats,
              '_optimalMoves': p.stats['pushes'],
              'requestedMinPushes': target,
              'generationMode': 'fresh'
            };
          }
          final pool = assets.starloader.levels
              .where((p) =>
                  !assets.starloader.retiredLevelIds.contains(p.id) &&
                  p.difficulty == 'grade_${grade.clamp(1, 4)}' &&
                  p.optimalMoves >= target)
              .toList();
          if (pool.isEmpty) {
            throw StateError(
                'No verified Star Loader pool for grade $grade level $level');
          }
          final p = pool[generatorRandom().nextInt(pool.length)];
          return {
            '_currentLevelData': p.toJson(),
            '_playerPos': [
              for (int y = 0; y < p.roomState.length; y++)
                for (int x = 0; x < p.roomState[y].length; x++)
                  if (p.roomState[y][x] == 5 || p.roomState[y][x] == 6) [x, y]
            ].single,
            '_boxPositions': [
              for (int y = 0; y < p.roomState.length; y++)
                for (int x = 0; x < p.roomState[y].length; x++)
                  if (p.roomState[y][x] == 3 || p.roomState[y][x] == 4) [x, y]
            ],
            '_targetPositions': [
              for (int y = 0; y < p.roomState.length; y++)
                for (int x = 0; x < p.roomState[y].length; x++)
                  if (p.roomStructure[y][x] == 2) [x, y]
            ],
            '_optimalMoves': p.optimalMoves,
            'requestedMinPushes': target,
            'generationMode': 'bundled'
          };
        default:
          throw StateError('Missing generator: $game');
      }
    });
