import 'dart:math' as math;

/// Direction offsets for equation placement: (dr, dc)
class EquationDirection {
  final int dr;
  final int dc;
  final String name;
  const EquationDirection(this.dr, this.dc, this.name);
}

const List<EquationDirection> allDirections = [
  EquationDirection(0, 1, 'right'),
  EquationDirection(1, 0, 'down'),
  EquationDirection(1, 1, 'downRight'),
  EquationDirection(1, -1, 'downLeft'),
  EquationDirection(0, -1, 'left'),
  EquationDirection(-1, 0, 'up'),
  EquationDirection(-1, -1, 'upLeft'),
  EquationDirection(-1, 1, 'upRight'),
];

const List<EquationDirection> cardinalDirections = [
  EquationDirection(0, 1, 'right'),
  EquationDirection(1, 0, 'down'),
];

class PlacedEquation {
  final String equation; // e.g. "3+4=7"
  final int startRow;
  final int startCol;
  final EquationDirection direction;
  final List<(int, int)> cells;

  PlacedEquation({
    required this.equation,
    required this.startRow,
    required this.startCol,
    required this.direction,
    required this.cells,
  });
}

class StarChartScanPuzzle {
  final int gridSize;
  final List<List<String>> grid;
  final List<PlacedEquation> placedEquations;
  final List<String> equationsToFind;

  StarChartScanPuzzle({
    required this.gridSize,
    required this.grid,
    required this.placedEquations,
    required this.equationsToFind,
  });

  /// Generate valid equations for the given operators
  static List<String> _generateEquations(
      List<String> operators, int count, math.Random random) {
    final equations = <String>{};
    int attempts = 0;

    while (equations.length < count && attempts < 500) {
      attempts++;
      final op = operators[random.nextInt(operators.length)];
      int a, b, result;

      switch (op) {
        case '+':
          a = random.nextInt(9) + 1; // 1-9
          b = random.nextInt(9) + 1;
          result = a + b;
          if (result > 9) {
            // Keep single-digit results for simpler equations
            // but allow double-digit sometimes for variety
            if (result > 18) continue;
          }
          break;
        case '-':
          result = random.nextInt(8) + 1; // 1-8
          b = random.nextInt(8) + 1; // 1-8
          a = result + b;
          if (a > 9) continue; // Keep a single digit
          break;
        case 'x':
          a = random.nextInt(8) + 2; // 2-9
          b = random.nextInt(8) + 2; // 2-9
          result = a * b;
          if (result > 81) continue;
          break;
        default:
          continue;
      }

      final eq = '$a$op$b=$result';
      // Only allow equations where all parts are representable
      // in the grid (each character is one cell)
      equations.add(eq);
    }

    return equations.toList()..shuffle(random);
  }

  /// Try to place an equation on the grid
  static PlacedEquation? _tryPlaceEquation(
    List<List<String>> grid,
    String equation,
    int gridSize,
    List<EquationDirection> directions,
    math.Random random,
  ) {
    final dirList = List<EquationDirection>.from(directions)..shuffle(random);
    final chars = equation.split('');

    for (final dir in dirList) {
      final positions = <(int, int)>[];

      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          final endR = r + dir.dr * (chars.length - 1);
          final endC = c + dir.dc * (chars.length - 1);

          if (endR >= 0 && endR < gridSize && endC >= 0 && endC < gridSize) {
            positions.add((r, c));
          }
        }
      }

      positions.shuffle(random);

      for (final (startR, startC) in positions) {
        bool canPlace = true;
        final cells = <(int, int)>[];

        for (int i = 0; i < chars.length; i++) {
          final r = startR + dir.dr * i;
          final c = startC + dir.dc * i;
          cells.add((r, c));

          if (grid[r][c].isNotEmpty && grid[r][c] != chars[i]) {
            canPlace = false;
            break;
          }
        }

        if (canPlace) {
          // Place the equation
          for (int i = 0; i < chars.length; i++) {
            final r = startR + dir.dr * i;
            final c = startC + dir.dc * i;
            grid[r][c] = chars[i];
          }

          return PlacedEquation(
            equation: equation,
            startRow: startR,
            startCol: startC,
            direction: dir,
            cells: cells,
          );
        }
      }
    }

    return null;
  }

  /// Generate an equation search puzzle.
  static StarChartScanPuzzle generate({
    required int gridSize,
    required int equationCount,
    required bool allowDiagonal,
    required List<String> operators,
    int? seed,
  }) {
    final random = math.Random(seed);
    final directions = allowDiagonal ? allDirections : cardinalDirections;

    // Generate more candidate equations than needed
    final candidateEquations =
        _generateEquations(operators, equationCount * 3, random);

    // Initialize empty grid
    final grid = List.generate(gridSize, (_) => List.filled(gridSize, ''));

    final placedEquations = <PlacedEquation>[];

    for (final eq in candidateEquations) {
      if (placedEquations.length >= equationCount) break;

      final placed =
          _tryPlaceEquation(grid, eq, gridSize, directions, random);
      if (placed != null) {
        placedEquations.add(placed);
      }
    }

    // Fill remaining empty cells with random numbers and operators
    const fillerChars = '0123456789+-x=';
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (grid[r][c].isEmpty) {
          grid[r][c] = fillerChars[random.nextInt(fillerChars.length)];
        }
      }
    }

    return StarChartScanPuzzle(
      gridSize: gridSize,
      grid: grid,
      placedEquations: placedEquations,
      equationsToFind: placedEquations.map((pe) => pe.equation).toList(),
    );
  }
}
