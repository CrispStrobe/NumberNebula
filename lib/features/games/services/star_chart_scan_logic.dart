import 'generator_random.dart';
import 'dart:math' as math;

/// Direction offsets for equation placement: (dr, dc)
class EquationDirection {
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {'dr': dr, 'dc': dc, 'name': name};
  factory EquationDirection.fromJson(Map<String, dynamic> json) =>
      EquationDirection(
          json['dr'] as int, json['dc'] as int, json['name'] as String);

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
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'equation': equation,
        'startRow': startRow,
        'startCol': startCol,
        'direction': direction.toJson(),
        'cells': cells.map((v0) => [v0.$1, v0.$2]).toList()
      };
  factory PlacedEquation.fromJson(Map<String, dynamic> json) => PlacedEquation(
      equation: json['equation'] as String,
      startRow: json['startRow'] as int,
      startCol: json['startCol'] as int,
      direction: EquationDirection.fromJson(
          Map<String, dynamic>.from(json['direction'] as Map)),
      cells: (json['cells'] as List)
          .map((v0) => (v0[0] as int, v0[1] as int))
          .toList());

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
  /// Exact local-session snapshot, including mutable model state.
  Map<String, dynamic> toJson() => {
        'gridSize': gridSize,
        'grid': grid.map((v0) => v0.map((v1) => v1).toList()).toList(),
        'placedEquations': placedEquations.map((v0) => v0.toJson()).toList(),
        'equationsToFind': equationsToFind.map((v0) => v0).toList()
      };
  factory StarChartScanPuzzle.fromJson(Map<String, dynamic> json) =>
      StarChartScanPuzzle(
          gridSize: json['gridSize'] as int,
          grid: (json['grid'] as List)
              .map((v0) => (v0 as List).map((v1) => v1 as String).toList())
              .toList(),
          placedEquations: (json['placedEquations'] as List)
              .map((v0) =>
                  PlacedEquation.fromJson(Map<String, dynamic>.from(v0 as Map)))
              .toList(),
          equationsToFind: (json['equationsToFind'] as List)
              .map((v0) => v0 as String)
              .toList());

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

  /// The unbroken run of cells from [start] to [end], or null if the two do
  /// not share a row, a column or a diagonal.
  ///
  /// A drag reports pointer positions several cells apart, so the run has to be
  /// derived from its two endpoints. Collecting the cells the pointer happened
  /// to be sampled over instead leaves gaps, and a sweep across a correct
  /// equation then matches nothing.
  static List<(int, int)>? lineBetween((int, int) start, (int, int) end) {
    final dr = end.$1 - start.$1;
    final dc = end.$2 - start.$2;
    if (dr == 0 && dc == 0) return [start];
    // Straight lines only: horizontal, vertical, or exactly 45 degrees.
    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return null;

    final stepR = dr == 0 ? 0 : dr ~/ dr.abs();
    final stepC = dc == 0 ? 0 : dc ~/ dc.abs();
    final steps = math.max(dr.abs(), dc.abs());

    return [
      for (int i = 0; i <= steps; i++)
        (start.$1 + stepR * i, start.$2 + stepC * i)
    ];
  }

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
    final random = generatorRandom(seed);
    final directions = allowDiagonal ? allDirections : cardinalDirections;

    // Generate more candidate equations than needed
    final candidateEquations =
        _generateEquations(operators, equationCount * 3, random);

    // Initialize empty grid
    final grid = List.generate(gridSize, (_) => List.filled(gridSize, ''));

    final placedEquations = <PlacedEquation>[];

    for (final eq in candidateEquations) {
      if (placedEquations.length >= equationCount) break;

      final placed = _tryPlaceEquation(grid, eq, gridSize, directions, random);
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
