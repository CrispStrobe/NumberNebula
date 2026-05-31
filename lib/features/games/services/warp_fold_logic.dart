import 'dart:math' as math;

/// Direction of a fold.
enum FoldDirection { left, right, top, bottom }

/// Represents a single fold operation.
class FoldStep {
  final FoldDirection direction;
  const FoldStep(this.direction);
}

/// Represents a cut position on the folded paper.
class CutPosition {
  final double x; // 0..1 normalized
  final double y; // 0..1 normalized
  final double size; // size of the cut hole
  const CutPosition(this.x, this.y, this.size);
}

/// The puzzle: a sequence of folds + cuts, and the correct unfolded result
/// plus 4 distractors.
class WarpFoldPuzzle {
  /// The sequence of folds to perform.
  final List<FoldStep> folds;

  /// Cut positions applied after folding.
  final List<CutPosition> cuts;

  /// Grid size for the paper (e.g., 8x8).
  final int gridSize;

  /// The correct unfolded result as a 2D bool grid (true = hole).
  final List<List<bool>> correctResult;

  /// All 5 options (including correct one), shuffled.
  final List<List<List<bool>>> options;

  /// Index of the correct option in [options].
  final int correctIndex;

  WarpFoldPuzzle({
    required this.folds,
    required this.cuts,
    required this.gridSize,
    required this.correctResult,
    required this.options,
    required this.correctIndex,
  });
}

class WarpFoldGenerator {
  final math.Random _random;

  WarpFoldGenerator({int? seed}) : _random = math.Random(seed);

  /// Generate a puzzle:
  /// - grade 1: 1 fold
  /// - grade 2: 2 folds
  /// - grade 3: 2-3 folds
  /// - grade 4: 3 folds with more cuts
  WarpFoldPuzzle generate({required int grade, required int level}) {
    int numFolds;
    int numCuts;
    const gridSize = 8;

    if (grade <= 1) {
      numFolds = 1;
      numCuts = 1;
    } else if (grade <= 2) {
      numFolds = 2;
      numCuts = 1 + (level > 5 ? 1 : 0);
    } else if (grade <= 3) {
      numFolds = level > 8 ? 3 : 2;
      numCuts = 2;
    } else {
      numFolds = 3;
      numCuts = 2 + (level > 10 ? 1 : 0);
    }

    // Generate random folds
    final directions = [
      FoldDirection.left,
      FoldDirection.right,
      FoldDirection.top,
      FoldDirection.bottom,
    ];
    final folds = <FoldStep>[];
    for (int i = 0; i < numFolds; i++) {
      folds.add(FoldStep(directions[_random.nextInt(directions.length)]));
    }

    // Generate cut positions in the folded paper region
    final cuts = <CutPosition>[];
    for (int i = 0; i < numCuts; i++) {
      // Keep cuts away from edges
      final x = 0.2 + _random.nextDouble() * 0.6;
      final y = 0.2 + _random.nextDouble() * 0.6;
      cuts.add(CutPosition(x, y, 0.1));
    }

    // Compute the correct unfolded result
    final correctResult = _computeUnfoldedResult(folds, cuts, gridSize);

    // Generate 4 distractors
    final allOptions = <List<List<bool>>>[correctResult];
    for (int i = 0; i < 4; i++) {
      allOptions.add(_generateDistractor(correctResult, gridSize));
    }

    // Shuffle options
    final correctIndex = _random.nextInt(5);
    final shuffled = List<List<List<bool>>>.from(allOptions);
    // Move the correct answer to the chosen index
    final correct = shuffled.removeAt(0);
    shuffled.insert(correctIndex, correct);

    return WarpFoldPuzzle(
      folds: folds,
      cuts: cuts,
      gridSize: gridSize,
      correctResult: correctResult,
      options: shuffled,
      correctIndex: correctIndex,
    );
  }

  /// Compute what the paper looks like after folding and cutting.
  List<List<bool>> _computeUnfoldedResult(
    List<FoldStep> folds,
    List<CutPosition> cuts,
    int gridSize,
  ) {
    // Start with all false (no holes)
    final grid = List.generate(gridSize, (_) => List.filled(gridSize, false));

    // For each cut, compute where it appears when unfolded.
    // Apply folds in reverse to find all symmetric positions.
    for (final cut in cuts) {
      // Start with the cut position
      var positions = [math.Point(cut.x, cut.y)];

      // Unfold in reverse order
      for (int f = folds.length - 1; f >= 0; f--) {
        final newPositions = <math.Point<double>>[];
        for (final pos in positions) {
          newPositions.add(pos);
          // Add the mirror position for this fold
          final mirrored = _mirrorPoint(pos, folds[f].direction);
          newPositions.add(mirrored);
        }
        positions = newPositions;
      }

      // Mark all positions on the grid
      final cutRadius = (cut.size * gridSize / 2).ceil();
      for (final pos in positions) {
        final cx = (pos.x * gridSize).round().clamp(0, gridSize - 1);
        final cy = (pos.y * gridSize).round().clamp(0, gridSize - 1);
        for (int dy = -cutRadius; dy <= cutRadius; dy++) {
          for (int dx = -cutRadius; dx <= cutRadius; dx++) {
            final nx = cx + dx;
            final ny = cy + dy;
            if (nx >= 0 && nx < gridSize && ny >= 0 && ny < gridSize) {
              grid[ny][nx] = true;
            }
          }
        }
      }
    }

    return grid;
  }

  math.Point<double> _mirrorPoint(math.Point<double> p, FoldDirection dir) {
    switch (dir) {
      case FoldDirection.left:
        return math.Point(1.0 - p.x, p.y); // mirror across vertical center
      case FoldDirection.right:
        return math.Point(1.0 - p.x, p.y);
      case FoldDirection.top:
        return math.Point(p.x, 1.0 - p.y); // mirror across horizontal center
      case FoldDirection.bottom:
        return math.Point(p.x, 1.0 - p.y);
    }
  }

  /// Generate a distractor by modifying the correct result.
  List<List<bool>> _generateDistractor(
    List<List<bool>> correct,
    int gridSize,
  ) {
    final distractor =
        correct.map((row) => List<bool>.from(row)).toList();

    // Strategy: flip some holes and add/remove some
    final modifications = 2 + _random.nextInt(3);
    for (int m = 0; m < modifications; m++) {
      final r = _random.nextInt(gridSize);
      final c = _random.nextInt(gridSize);
      distractor[r][c] = !distractor[r][c];
    }

    // Make sure it differs from correct
    bool same = true;
    for (int r = 0; r < gridSize && same; r++) {
      for (int c = 0; c < gridSize && same; c++) {
        if (distractor[r][c] != correct[r][c]) same = false;
      }
    }
    if (same) {
      // Force a difference
      final r = _random.nextInt(gridSize);
      final c = _random.nextInt(gridSize);
      distractor[r][c] = !distractor[r][c];
    }

    return distractor;
  }
}
