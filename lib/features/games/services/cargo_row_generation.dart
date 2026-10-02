import 'dart:async';
import 'dart:math';
import 'package:dart_csp/dart_csp.dart';
import 'algorithm_path.dart';
import 'cargo_generation.dart';
import 'generator_random.dart';

/// A reachable rotate/shift/hard-drop placement. Cell indices refer to the
/// original piece's row-major filled cells, so values travel with rotations.
class CargoLanding {
  final int rotations, x, y;
  final List<List<int?>> cells;
  CargoLanding(this.rotations, this.x, this.y, this.cells);
}

class CargoRowGeneration {
  final CargoPiece piece;
  final CargoLanding? landing;
  final List<int> targetRows;
  final String implementation;
  CargoRowGeneration(this.piece, this.implementation,
      {this.landing, this.targetRows = const []});
}

bool _collision(List<List<int?>> board, List<List<int?>> cells, int x, int y) {
  for (var r = 0; r < cells.length; r++) {
    for (var c = 0; c < cells[r].length; c++) {
      if (cells[r][c] == null) continue;
      final bx = x + c, by = y + r;
      if (bx < 0 || bx >= board.first.length || by >= board.length) return true;
      if (by >= 0 && board[by][bx] != null) return true;
    }
  }
  return false;
}

/// Restrict assistance to an empty spawn corridor. Then every enumerated
/// rotation and horizontal shift is reachable before the hard drop; no claim
/// is made about paths through a crowded top of the stack.
List<CargoLanding> cargoLandings(List<List<int?>> board, CargoPiece piece) {
  if (board.isEmpty ||
      board.first.isEmpty ||
      board.any((row) => row.length != board.first.length)) {
    throw ArgumentError('Cargo board must be a nonempty rectangle');
  }
  final n = piece.shape.length;
  if (piece.shape.any((row) => row.length != n)) {
    throw ArgumentError('Cargo shape must be square');
  }
  if (piece.y != -2 || board.take(n).any((row) => row.any((v) => v != null))) {
    return [];
  }
  var index = 0;
  var cells = [
    for (final row in piece.shape)
      [for (final filled in row) filled ? index++ : null]
  ];
  final result = <CargoLanding>[];
  for (var rotation = 0; rotation < 4; rotation++) {
    // Rotations happen at the original spawn x, where the corridor is empty.
    if (!_collision(board, cells, piece.x, -2)) {
      for (var x = -n + 1; x < board.first.length; x++) {
        if (_collision(board, cells, x, -2)) continue;
        var y = -2;
        while (!_collision(board, cells, x, y + 1)) {
          y++;
        }
        var toppedOut = false;
        for (var r = 0; r < n; r++) {
          if (y + r < 0 && cells[r].any((cell) => cell != null)) {
            toppedOut = true;
          }
        }
        if (!toppedOut) result.add(CargoLanding(rotation, x, y, cells));
      }
    }
    cells =
        List.generate(n, (r) => List.generate(n, (c) => cells[n - 1 - c][r]));
  }
  return result;
}

/// Independent arithmetic verification against the actual board, not the CSP.
bool verifiesCargoTarget(List<List<int?>> board, CargoPiece piece,
    CargoLanding landing, List<int> targetRows, int target) {
  if (targetRows.isEmpty) return false;
  final values = [
    for (final row in piece.cubes)
      for (final cube in row)
        if (cube != null) cube.value
  ];
  final placed = [for (final row in board) List<int?>.from(row)];
  for (var r = 0; r < landing.cells.length; r++) {
    for (var c = 0; c < landing.cells[r].length; c++) {
      final index = landing.cells[r][c];
      if (index == null) continue;
      final by = landing.y + r, bx = landing.x + c;
      if (by < 0 ||
          by >= placed.length ||
          bx < 0 ||
          bx >= placed.first.length ||
          placed[by][bx] != null ||
          index >= values.length) {
        return false;
      }
      placed[by][bx] = values[index];
    }
  }
  return targetRows.every((r) =>
      r >= 0 &&
      r < placed.length &&
      placed[r].every((v) => v != null) &&
      placed[r].fold<int>(0, (sum, v) => sum + v!) == target);
}

/// Preserve shape, colours and unrelated values. Only refine a newly created
/// preview: an already advertised or held piece must never be renumbered.
Future<CargoRowGeneration> generateCargoRowValues({
  required CargoPiece baseline,
  required List<List<int?>> board,
  required int minValue,
  required int maxValue,
  required int targetSum,
  double assistanceChance = 0.30,
  Random? random,
}) async {
  CargoRowGeneration fallback(String reason) {
    recordAlgorithm('cargo-values', reason);
    return CargoRowGeneration(baseline, reason);
  }

  if (algorithmPath == AlgorithmPath.legacy) return fallback('legacy');
  if (minValue > maxValue || assistanceChance < 0 || assistanceChance > 1) {
    throw ArgumentError(
        'Valid Cargo value range and assistance chance required');
  }
  final rng = random ?? generatorRandom();
  if (rng.nextDouble() >= assistanceChance) {
    return fallback('candidate-unassisted');
  }
  try {
    final placements = cargoLandings(board, baseline)..shuffle(rng);
    final count = baseline.cubes
        .expand((row) => row)
        .where((cube) => cube != null)
        .length;
    for (final landing in placements) {
      final rows = <int, List<int>>{};
      for (var r = 0; r < landing.cells.length; r++) {
        final by = landing.y + r;
        final indices = landing.cells[r].whereType<int>().toList();
        if (indices.isEmpty) continue;
        final occupied = board[by].where((value) => value != null).length;
        if (occupied + indices.length != board.first.length) continue;
        final existing =
            board[by].whereType<int>().fold<int>(0, (a, b) => a + b);
        final needed = targetSum - existing;
        if (needed >= indices.length * minValue &&
            needed <= indices.length * maxValue) {
          rows[by] = indices;
        }
      }
      if (rows.isEmpty) continue;
      final problem = Problem();
      final original = baseline.cubes
          .expand((row) => row)
          .whereType<CargoCube>()
          .map((cube) => cube.value)
          .toList();
      final constrained = rows.values.expand((indices) => indices).toSet();
      for (var i = 0; i < count; i++) {
        final domain = constrained.contains(i)
            ? (List.generate(maxValue - minValue + 1, (v) => minValue + v)
              ..shuffle(rng))
            : [original[i]];
        problem.addVariable('v$i', domain);
      }
      for (final row in rows.entries) {
        final existing =
            board[row.key].whereType<int>().fold<int>(0, (a, b) => a + b);
        problem.addLinearEquals(row.value.map((i) => 'v$i').toList(),
            List.filled(row.value.length, 1), targetSum - existing);
      }
      final token = CancellationToken();
      final timer = Timer(const Duration(milliseconds: 25), token.cancel);
      dynamic solution;
      try {
        solution = await problem.getSolution(cancelToken: token);
      } finally {
        timer.cancel();
      }
      if (solution is! Map) return fallback('candidate-solver-fallback');
      final piece = CargoPiece.fromJson(baseline.toJson());
      var i = 0;
      for (var r = 0; r < piece.cubes.length; r++) {
        for (var c = 0; c < piece.cubes[r].length; c++) {
          final cube = piece.cubes[r][c];
          if (cube != null) {
            piece.cubes[r][c] =
                CargoCube(value: solution['v${i++}'] as int, color: cube.color);
          }
        }
      }
      if (!verifiesCargoTarget(
          board, piece, landing, rows.keys.toList(), targetSum)) {
        throw StateError(
            'Cargo CSP result failed independent row verification');
      }
      recordAlgorithm('cargo-values', 'candidate-board-aware');
      return CargoRowGeneration(piece, 'candidate-board-aware',
          landing: landing, targetRows: rows.keys.toList());
    }
    return fallback('candidate-no-opportunity');
  } catch (_) {
    if (algorithmPath == AlgorithmPath.candidate) rethrow;
    return fallback('legacy-error-fallback');
  }
}
