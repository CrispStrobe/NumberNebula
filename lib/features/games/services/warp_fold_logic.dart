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
  /// - grade 1: 1 fold, 4x4 grid
  /// - grade 2: 1-2 folds, 6x6 grid
  /// - grade 3: 2 folds, 6x6 grid
  /// - grade 4: 2-3 folds with more cuts, 6x6 grid
  WarpFoldPuzzle generate({required int grade, required int level}) {
    int numFolds;
    int numCuts;
    int gridSize;

    if (grade <= 1) {
      numFolds = 1;
      numCuts = 1;
      gridSize = 4;
    } else if (grade <= 2) {
      numFolds = 1 + (level > 5 ? 1 : 0);
      numCuts = 1;
      gridSize = 6;
    } else if (grade <= 3) {
      numFolds = 2;
      numCuts = 1 + (level > 5 ? 1 : 0);
      gridSize = 6;
    } else {
      numFolds = level > 8 ? 3 : 2;
      numCuts = 2;
      gridSize = 6;
    }

    // Generate random folds -- avoid consecutive same-axis folds
    final folds = <FoldStep>[];
    for (int i = 0; i < numFolds; i++) {
      List<FoldDirection> available;
      if (i == 0) {
        available = FoldDirection.values.toList();
      } else {
        // Avoid repeating the same axis
        final prev = folds[i - 1].direction;
        final isHorizontal = prev == FoldDirection.left || prev == FoldDirection.right;
        if (isHorizontal) {
          available = [FoldDirection.top, FoldDirection.bottom];
        } else {
          available = [FoldDirection.left, FoldDirection.right];
        }
      }
      folds.add(FoldStep(available[_random.nextInt(available.length)]));
    }

    // Generate cut positions constrained to the VISIBLE portion after folding.
    // After each fold, the visible area halves. Track the visible region.
    double visMinX = 0.0, visMaxX = 1.0, visMinY = 0.0, visMaxY = 1.0;
    for (final fold in folds) {
      switch (fold.direction) {
        case FoldDirection.left:
          visMinX = 0.5; // left folded onto right; right half visible
        case FoldDirection.right:
          visMaxX = 0.5; // right folded onto left; left half visible
        case FoldDirection.top:
          visMinY = 0.5; // top folded down; bottom half visible
        case FoldDirection.bottom:
          visMaxY = 0.5; // bottom folded up; top half visible
      }
    }

    final cuts = <CutPosition>[];
    for (int i = 0; i < numCuts; i++) {
      // Place cut within visible area with margin
      const margin = 0.08;
      final x = (visMinX + margin) + _random.nextDouble() * (visMaxX - visMinX - 2 * margin);
      final y = (visMinY + margin) + _random.nextDouble() * (visMaxY - visMinY - 2 * margin);
      cuts.add(CutPosition(x.clamp(0.05, 0.95), y.clamp(0.05, 0.95), 0.1));
    }

    // Compute the correct unfolded result
    final correctResult = _computeUnfoldedResult(folds, cuts, gridSize);

    // Generate 4 unique distractors
    final allOptions = <List<List<bool>>>[correctResult];
    for (int attempt = 0; attempt < 40 && allOptions.length < 5; attempt++) {
      final distractor = _generateDistractor(correctResult, gridSize, folds);
      // Check it's unique among all options so far
      bool isDuplicate = false;
      for (final existing in allOptions) {
        if (_gridsEqual(distractor, existing, gridSize)) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) allOptions.add(distractor);
    }
    // Fill remaining with random flips if needed
    while (allOptions.length < 5) {
      final d = correctResult.map(List<bool>.from).toList();
      for (int m = 0; m < 4; m++) {
        d[_random.nextInt(gridSize)][_random.nextInt(gridSize)] = _random.nextBool();
      }
      allOptions.add(d);
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

  bool _gridsEqual(List<List<bool>> a, List<List<bool>> b, int size) {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (a[r][c] != b[r][c]) return false;
      }
    }
    return true;
  }

  /// Generate a plausible distractor that looks like it could be a valid fold result.
  /// Strategy: break the symmetry slightly — shift holes, rotate the pattern,
  /// or use a different fold axis.
  List<List<bool>> _generateDistractor(
    List<List<bool>> correct,
    int gridSize,
    List<FoldStep> folds,
  ) {
    final strategy = _random.nextInt(3);

    if (strategy == 0) {
      // Shift all holes by 1 cell in a random direction
      final dx = _random.nextInt(3) - 1; // -1, 0, 1
      final dy = _random.nextInt(3) - 1;
      if (dx == 0 && dy == 0) {
        return _flipRandomCells(correct, gridSize);
      }
      final shifted = List.generate(gridSize, (_) => List.filled(gridSize, false));
      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          if (correct[r][c]) {
            final nr = r + dy, nc = c + dx;
            if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
              shifted[nr][nc] = true;
            }
          }
        }
      }
      return shifted;
    } else if (strategy == 1) {
      // Break symmetry: for one fold axis, don't mirror
      final d = correct.map(List<bool>.from).toList();
      // Remove holes from one half
      final axis = _random.nextBool(); // true = vertical, false = horizontal
      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          if (axis && c >= gridSize ~/ 2 && d[r][c] && _random.nextBool()) {
            d[r][c] = false;
          }
          if (!axis && r >= gridSize ~/ 2 && d[r][c] && _random.nextBool()) {
            d[r][c] = false;
          }
        }
      }
      return d;
    } else {
      return _flipRandomCells(correct, gridSize);
    }
  }

  List<List<bool>> _flipRandomCells(List<List<bool>> correct, int gridSize) {
    final d = correct.map(List<bool>.from).toList();
    final modifications = 2 + _random.nextInt(3);
    for (int m = 0; m < modifications; m++) {
      d[_random.nextInt(gridSize)][_random.nextInt(gridSize)] =
          !d[_random.nextInt(gridSize)][_random.nextInt(gridSize)];
    }
    // Ensure differs from correct
    if (_gridsEqual(d, correct, gridSize)) {
      d[_random.nextInt(gridSize)][_random.nextInt(gridSize)] =
          !d[_random.nextInt(gridSize)][_random.nextInt(gridSize)];
    }
    return d;
  }
}
