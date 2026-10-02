// ignore_for_file: avoid_relative_lib_imports
import 'dart:math';
import '../lib/features/games/services/cargo_generation.dart';
import '../lib/features/games/services/cargo_row_generation.dart';

bool cargoReplayCollision(
    List<List<int?>> board, CargoPiece piece, int x, int y) {
  for (var r = 0; r < piece.shape.length; r++) {
    for (var c = 0; c < piece.shape[r].length; c++) {
      if (!piece.shape[r][c]) continue;
      final bx = x + c, by = y + r;
      if (bx < 0 || bx >= board.first.length || by >= board.length) return true;
      if (by >= 0 && board[by][bx] != null) return true;
    }
  }
  return false;
}

void cargoReplayRotate(CargoPiece piece) {
  final n = piece.shape.length;
  final shape = piece.shape, cubes = piece.cubes;
  piece.shape =
      List.generate(n, (r) => List.generate(n, (c) => shape[n - 1 - c][r]));
  piece.cubes =
      List.generate(n, (r) => List.generate(n, (c) => cubes[n - 1 - c][r]));
}

/// Replay the same primitive moves available in the UI, carrying actual cubes
/// through rotations. This oracle does not use the candidate's cell-index map.
List<List<int?>> replayCargoLanding(
    List<List<int?>> board, CargoPiece original, CargoLanding landing) {
  final piece = CargoPiece.fromJson(original.toJson());
  for (var i = 0; i < landing.rotations; i++) {
    cargoReplayRotate(piece);
    if (cargoReplayCollision(board, piece, piece.x, piece.y)) {
      throw StateError('Unreachable rotation');
    }
  }
  while (piece.x != landing.x) {
    final x = piece.x + (piece.x < landing.x ? 1 : -1);
    if (cargoReplayCollision(board, piece, x, piece.y)) {
      throw StateError('Unreachable shift');
    }
    piece.x = x;
  }
  while (!cargoReplayCollision(board, piece, piece.x, piece.y + 1)) {
    piece.y++;
  }
  if (piece.y != landing.y) throw StateError('Incorrect hard-drop landing');
  final placed = [for (final row in board) List<int?>.from(row)];
  for (var r = 0; r < piece.cubes.length; r++) {
    for (var c = 0; c < piece.cubes[r].length; c++) {
      final cube = piece.cubes[r][c];
      if (cube != null) {
        if (piece.y + r < 0 || placed[piece.y + r][piece.x + c] != null) {
          throw StateError('Invalid placement');
        }
        placed[piece.y + r][piece.x + c] = cube.value;
      }
    }
  }
  return placed;
}

({CargoPiece piece, List<List<int?>> board, CargoGenerationConfig config})
    cargoScenario(int grade, int level, int shape, int rotation, int seed) {
  final rng = Random(seed), config = CargoGenerationConfig(grade, level);
  final piece = CargoPiece.random(config.numberMin, config.numberMax, 8,
      shapeIndex: shape,
      random: rng,
      targetSum: config.targetSum,
      sequenceChance: .30,
      targetSumChance: .30);
  final pose = CargoPiece.fromJson(piece.toJson());
  for (var i = 0; i < rotation; i++) {
    cargoReplayRotate(pose);
  }
  final cols = [
    for (var r = 0; r < pose.shape.length; r++)
      for (var c = 0; c < pose.shape[r].length; c++)
        if (pose.shape[r][c]) c
  ];
  pose.x =
      -cols.reduce(min) + rng.nextInt(8 - cols.reduce(max) + cols.reduce(min));
  final board = List.generate(18, (_) => List<int?>.filled(8, null));
  while (!cargoReplayCollision(board, pose, pose.x, pose.y + 1)) {
    pose.y++;
  }
  var remaining = config.targetSum;
  for (var c = 0; c < 8; c++) {
    final after = 7 - c;
    final lower = max(config.numberMin, remaining - after * config.numberMax);
    final upper = min(config.numberMax, remaining - after * config.numberMin);
    board.last[c] = lower + rng.nextInt(upper - lower + 1);
    remaining -= board.last[c]!;
  }
  for (var r = 0; r < pose.shape.length; r++) {
    for (var c = 0; c < pose.shape[r].length; c++) {
      if (pose.shape[r][c] && pose.y + r == 17) board.last[pose.x + c] = null;
    }
  }
  return (piece: piece, board: board, config: config);
}
