import 'generator_random.dart';
import '../models/math_problem.dart';
import '../constants/app_constants.dart';
import '../constants/difficulty_manager.dart';

List<MathProblem> generateAsteroidProblems(DifficultySource gameProvider,
    int level, ProblemReviewSource sriService, int asteroidCount) {
  final difficulty = DifficultyManager.getDifficulty(gameProvider, level);
  final random = generatorRandom();
  final problems = <MathProblem>[];
  final usedAnswers = <int>{};
  int attempts = 0;
  while (problems.length < asteroidCount && attempts < 100) {
    attempts++;

    final problem =
        MathProblem.generateProblem(gameProvider, level, sriService);

    if (!usedAnswers.contains(problem.answer) &&
        problem.answer > 0 &&
        problem.answer < 1000) {
      problems.add(problem);
      usedAnswers.add(problem.answer);
    }
  }

  final range = difficulty.numberRange;
  final span = range['max']! - range['min']!;
  var fillGuard = 0;
  while (problems.length < asteroidCount && fillGuard++ < 500) {
    // Find a DISTINCT filler answer. `span <= 0` (possible with custom
    // min>=max settings) would make nextInt throw, so guard it.
    int? plainNumber;
    for (var attempt = 0; attempt < 200; attempt++) {
      final candidate =
          span > 0 ? random.nextInt(span) + range['min']! : range['min']!;
      if (!usedAnswers.contains(candidate)) {
        plainNumber = candidate;
        break;
      }
    }
    // No distinct value left — stop rather than spawn a duplicate-answer
    // asteroid that can never be a valid target (and would penalise the
    // player when tapped).
    if (plainNumber == null) break;

    final simpleProblem = MathProblem(
      expression: plainNumber.toString(),
      answer: plainNumber,
      operation: MathOperation.addition,
      operandA: plainNumber,
      operandB: 0,
      difficulty: 1,
    );

    problems.add(simpleProblem);
    usedAnswers.add(plainNumber);
  }

  return problems;
}

List<MathProblem> generatePlanetProblems(DifficultySource gameProvider,
    int level, ProblemReviewSource sriService, int planetCount) {
  final problems = <MathProblem>[];
  final usedAnswers = <int>{};
  int attempts = 0;
  while (problems.length < planetCount && attempts < 100) {
    attempts++;
    final problem =
        MathProblem.generateProblem(gameProvider, level, sriService);

    if (!usedAnswers.contains(problem.answer)) {
      problems.add(problem);
      usedAnswers.add(problem.answer);
    }
  }

  return problems;
}

List<int> generatePathAnswers(MathProblem problem, int numPaths) {
  final random = generatorRandom();
  final pathAnswers = {problem.answer};
  var outerGuard = 0;
  while (pathAnswers.length < numPaths && outerGuard++ < 500) {
    int wrongAnswer = 0;
    for (var i = 0; i < 200; i++) {
      wrongAnswer = problem.answer +
          (random.nextBool() ? 1 : -1) * (random.nextInt(10) + 1);
      if (wrongAnswer > 0 && !pathAnswers.contains(wrongAnswer)) break;
    }
    if (wrongAnswer > 0) pathAnswers.add(wrongAnswer);
  }
  final shuffledAnswers = pathAnswers.toList()..shuffle(random);

  return shuffledAnswers;
}

class AsteroidCell {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'row': row,
        'col': col,
        'isMine': isMine,
        'isRevealed': isRevealed,
        'isFlagged': isFlagged,
        'isExploded': isExploded,
        'adjacentMines': adjacentMines
      };
  factory AsteroidCell.fromJson(Map<String, dynamic> json) => AsteroidCell(
      row: json['row'] as int,
      col: json['col'] as int,
      isMine: json['isMine'] as bool,
      isRevealed: json['isRevealed'] as bool,
      isFlagged: json['isFlagged'] as bool,
      isExploded: json['isExploded'] as bool,
      adjacentMines: json['adjacentMines'] as int);

  final int row;
  final int col;
  bool isMine;
  bool isRevealed;
  bool isFlagged;
  bool isExploded;
  int adjacentMines;

  AsteroidCell({
    required this.row,
    required this.col,
    this.isMine = false,
    this.isRevealed = false,
    this.isFlagged = false,
    this.isExploded = false,
    this.adjacentMines = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsteroidCell &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

int countAdjacentMines(List<List<AsteroidCell>> grid, int row, int col) {
  int count = 0;
  for (int dr = -1; dr <= 1; dr++) {
    for (int dc = -1; dc <= 1; dc++) {
      if (dr == 0 && dc == 0) continue;
      final newRow = row + dr;
      final newCol = col + dc;
      if (newRow >= 0 &&
          newRow < grid.length &&
          newCol >= 0 &&
          newCol < grid.first.length) {
        if (grid[newRow][newCol].isMine) count++;
      }
    }
  }
  return count;
}

List<List<AsteroidCell>> generateMineField(
    int gridRows, int gridCols, int mineCount) {
  if (mineCount < 0 || mineCount > gridRows * gridCols) {
    throw ArgumentError('Invalid mine count');
  }
  late List<List<AsteroidCell>> grid;
  final random = generatorRandom();

  grid = List.generate(
    gridRows,
    (row) => List.generate(
      gridCols,
      (col) => AsteroidCell(row: row, col: col),
    ),
  );

  int minesPlaced = 0;
  while (minesPlaced < mineCount) {
    final row = random.nextInt(gridRows);
    final col = random.nextInt(gridCols);

    if (!grid[row][col].isMine) {
      grid[row][col].isMine = true;
      minesPlaced++;
    }
  }

  for (int row = 0; row < gridRows; row++) {
    for (int col = 0; col < gridCols; col++) {
      if (!grid[row][col].isMine) {
        grid[row][col].adjacentMines = countAdjacentMines(grid, row, col);
      }
    }
  }
  return grid;
}

Map<String, dynamic> generateSignalRound(int grade, int level) {
  final complexity = grade + level / 5;
  final length = complexity <= 3.5
      ? 4
      : complexity <= 5
          ? 5
          : 6;
  final maxGuesses = complexity <= 2
      ? 10
      : complexity <= 3.5
          ? 8
          : complexity <= 5
              ? 9
              : 10;
  final count = complexity <= 2
      ? 5
      : complexity <= 3.5
          ? 6
          : complexity <= 5
              ? 7
              : 8;
  final glyphs = [
    'alpha',
    'beta',
    'gamma',
    'delta',
    'epsilon',
    'zeta',
    'eta',
    'theta'
  ].take(count).toList();
  return {
    'length': length,
    'maxGuesses': maxGuesses,
    'glyphs': glyphs,
    'secret':
        List.generate(length, (_) => glyphs[generatorRandom().nextInt(count)]),
    'guess': List.filled(length, 'empty'),
    'history': <dynamic>[]
  };
}

int gridFillerPieceTypes(int grade, int level) {
  final complexity = grade + level / 5;
  return complexity <= 2
      ? 4
      : complexity <= 3
          ? 5
          : complexity <= 4
              ? 6
              : complexity <= 5.5
                  ? 7
                  : complexity <= 7
                      ? 8
                      : 9;
}

List<MathProblem> generateJigsawProblems(DifficultySource settings, int level,
        ProblemReviewSource reviews, int count) =>
    List.generate(
        count, (_) => MathProblem.generateProblem(settings, level, reviews));
