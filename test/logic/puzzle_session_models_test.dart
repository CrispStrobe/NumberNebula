import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/services/star_forge_logic.dart';
import 'package:space_math_academy/features/games/services/orbital_towers_logic.dart';
import 'package:space_math_academy/features/games/services/nebula_matrix_logic.dart';
import 'package:space_math_academy/features/games/services/dark_matter_grid_logic.dart';
import 'package:space_math_academy/features/games/services/vault_cracker_logic.dart';
import 'package:space_math_academy/features/games/services/codebreaker_logic.dart';
import 'package:space_math_academy/features/games/screens/number_walls_game.dart';
import 'package:space_math_academy/features/games/screens/kenken_game.dart';

Map<String, dynamic> persisted(Map<String, dynamic> data) =>
    jsonDecode(jsonEncode(data));
void main() {
  final gp = GameProvider(
      progressService: ProgressService(),
      sriService: SriService(),
      cognitiveProfileService: CognitiveProfileService());
  final config = DifficultyManager.getDifficulty(gp, 1);
  final args = <String, dynamic>{
    'grade': 1,
    'level': 1,
    'difficulty': config,
    'useCustomSettings': false,
    'customOps': ['addition'],
    'customMin': 1,
    'customMax': 20,
    'useCSP': false
  };
  test('star and towers retain clues, solutions and exact puzzle order',
      () async {
    final star = await StarForgeGenerator().generate(points: 5, clueCount: 8);
    final starCopy = StarForgePuzzle.fromJson(persisted(star.toJson()));
    expect(starCopy.validateSolution(star.solution), isTrue);
    expect(starCopy.toJson(), star.toJson());
    final towers = await OrbitalTowersGenerator()
        .generate(size: 3, edgeClueCount: 9, cellClueCount: 2);
    final towerCopy = OrbitalTowersPuzzle.fromJson(persisted(towers.toJson()));
    expect(towerCopy.validateSolution(towers.solution), isTrue);
    expect(towerCopy.toJson(), towers.toJson());
  });
  test('number wall keeps duplicate brick pool and validates the saved board',
      () {
    final wall = NumberWallPuzzle.generate(args);
    final copy = NumberWallPuzzle.fromJson(persisted(wall.toJson()));
    final hidden = copy.hiddenCells.toList()..sort();
    expect(
        copy.validateSolution(hidden.map((i) => copy.fullSolution[i]).toList()),
        isTrue);
    expect(copy.toJson(), wall.toJson());
  });
  test('KenKen restores cage membership and arithmetic validation', () async {
    final puzzle = await KenkenPuzzle.generate(args);
    final copy = KenkenPuzzle.fromJson(persisted(puzzle.toJson()), config);
    expect(copy.validateSolution(puzzle.fullSolution), isTrue);
    for (final row in copy.board) {
      for (final cell in row) {
        expect(copy.getCageForCell(cell), cell.group);
      }
    }
    expect(copy.toJson(), puzzle.toJson());
  });
  test('Codebreaker restores equations and hidden position identities',
      () async {
    final puzzle = await AdvancedCodebreakerPuzzle.generate(args);
    final copy = AdvancedCodebreakerPuzzle.fromJson(persisted(puzzle.toJson()));
    expect(copy.toJson(), puzzle.toJson());
  });
  test(
      'Vault restores the exact clue predicates, including direct-clue fallback',
      () {
    for (int run = 0; run < 5; run++) {
      final puzzle = VaultCrackerLogic.generate(args);
      final copy = VaultCrackerPuzzle.fromJson(persisted(puzzle.toJson()));
      expect(copy.toJson(), puzzle.toJson());
      for (int i = 0; i < copy.clues.length; i++) {
        expect(copy.clues[i].check(puzzle.secretCode), isTrue);
        final guess = List<int>.from(puzzle.secretCode)
          ..[0] = puzzle.secretCode[0] % puzzle.digitRange + 1;
        expect(copy.clues[i].check(guess), puzzle.clues[i].check(guess));
      }
    }
  });
  test('Latin-square zones and lights-out initial state survive JSON storage',
      () async {
    final matrix =
        await NebulaMatrixGenerator().generate(size: 4, clueCount: 8);
    final matrixCopy = NebulaMatrixPuzzle.fromJson(persisted(matrix.toJson()));
    expect(matrixCopy.validateSolution(matrix.solution), isTrue);
    expect(matrixCopy.toJson(), matrix.toJson());
    final lights =
        DarkMatterGridPuzzle.generate(gridSize: 3, toggleCount: 4, seed: 42);
    expect(DarkMatterGridPuzzle.fromJson(persisted(lights.toJson())).toJson(),
        lights.toJson());
  });
}
