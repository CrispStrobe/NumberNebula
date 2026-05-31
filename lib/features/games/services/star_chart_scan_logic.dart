// lib/features/games/services/star_chart_scan_logic.dart
import 'dart:math' as math;

/// Direction offsets for word placement: (dr, dc)
class WordDirection {
  final int dr;
  final int dc;
  final String name;
  const WordDirection(this.dr, this.dc, this.name);
}

const List<WordDirection> allDirections = [
  WordDirection(0, 1, 'right'),
  WordDirection(0, -1, 'left'),
  WordDirection(1, 0, 'down'),
  WordDirection(-1, 0, 'up'),
  WordDirection(1, 1, 'downRight'),
  WordDirection(1, -1, 'downLeft'),
  WordDirection(-1, 1, 'upRight'),
  WordDirection(-1, -1, 'upLeft'),
];

const List<WordDirection> cardinalDirections = [
  WordDirection(0, 1, 'right'),
  WordDirection(0, -1, 'left'),
  WordDirection(1, 0, 'down'),
  WordDirection(-1, 0, 'up'),
];

class PlacedWord {
  final String word;
  final int startRow;
  final int startCol;
  final WordDirection direction;
  final List<(int, int)> cells;

  PlacedWord({
    required this.word,
    required this.startRow,
    required this.startCol,
    required this.direction,
    required this.cells,
  });
}

class StarChartScanPuzzle {
  final int gridSize;
  final List<List<String>> grid;
  final List<PlacedWord> placedWords;
  final List<String> wordsToFind;
  final String mysteryLetter;

  StarChartScanPuzzle({
    required this.gridSize,
    required this.grid,
    required this.placedWords,
    required this.wordsToFind,
    required this.mysteryLetter,
  });

  /// Generate a word search puzzle.
  /// [wordPool] list of candidate words to choose from.
  /// [gridSize] size of the square grid.
  /// [wordCount] number of words to place.
  /// [allowDiagonal] whether diagonal directions are allowed.
  static StarChartScanPuzzle generate({
    required List<String> wordPool,
    required int gridSize,
    required int wordCount,
    required bool allowDiagonal,
    int? seed,
  }) {
    final random = math.Random(seed);
    final directions = allowDiagonal ? allDirections : cardinalDirections;

    // Sort words by length descending so longer words get placed first
    final shuffled = List<String>.from(wordPool)..shuffle(random);
    shuffled.sort((a, b) => b.length.compareTo(a.length));

    // Filter words that fit in the grid
    final candidates = shuffled.where((w) => w.length <= gridSize).toList();

    // Initialize empty grid
    final grid = List.generate(gridSize, (_) => List.filled(gridSize, ''));

    final placedWords = <PlacedWord>[];

    for (final word in candidates) {
      if (placedWords.length >= wordCount) break;

      final placed = _tryPlaceWord(grid, word, gridSize, directions, random);
      if (placed != null) {
        placedWords.add(placed);
      }
    }

    // Count how many cells are used by words
    final usedCells = <String>{};
    for (final pw in placedWords) {
      for (final cell in pw.cells) {
        usedCells.add('${cell.$1},${cell.$2}');
      }
    }

    // Fill remaining cells with random letters
    // Choose the mystery letter first
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final mysteryLetter = alphabet[random.nextInt(26)];

    // We need exactly one cell for the mystery letter
    // Find first empty cell to place mystery letter
    bool mysteryPlaced = false;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (grid[r][c].isEmpty) {
          if (!mysteryPlaced) {
            grid[r][c] = mysteryLetter;
            mysteryPlaced = true;
          } else {
            grid[r][c] = alphabet[random.nextInt(26)];
          }
        }
      }
    }

    return StarChartScanPuzzle(
      gridSize: gridSize,
      grid: grid,
      placedWords: placedWords,
      wordsToFind: placedWords.map((pw) => pw.word).toList(),
      mysteryLetter: mysteryLetter,
    );
  }

  static PlacedWord? _tryPlaceWord(
    List<List<String>> grid,
    String word,
    int gridSize,
    List<WordDirection> directions,
    math.Random random,
  ) {
    // Try random positions and directions
    final dirList = List<WordDirection>.from(directions)..shuffle(random);

    for (final dir in dirList) {
      // Calculate valid start positions for this direction
      final positions = <(int, int)>[];

      for (int r = 0; r < gridSize; r++) {
        for (int c = 0; c < gridSize; c++) {
          // Check if word fits starting at (r, c) in this direction
          final endR = r + dir.dr * (word.length - 1);
          final endC = c + dir.dc * (word.length - 1);

          if (endR >= 0 && endR < gridSize && endC >= 0 && endC < gridSize) {
            positions.add((r, c));
          }
        }
      }

      positions.shuffle(random);

      for (final (startR, startC) in positions) {
        // Check if word can be placed here (no conflicts)
        bool canPlace = true;
        final cells = <(int, int)>[];

        for (int i = 0; i < word.length; i++) {
          final r = startR + dir.dr * i;
          final c = startC + dir.dc * i;
          cells.add((r, c));

          if (grid[r][c].isNotEmpty && grid[r][c] != word[i]) {
            canPlace = false;
            break;
          }
        }

        if (canPlace) {
          // Place the word
          for (int i = 0; i < word.length; i++) {
            final r = startR + dir.dr * i;
            final c = startC + dir.dc * i;
            grid[r][c] = word[i];
          }

          return PlacedWord(
            word: word,
            startRow: startR,
            startCol: startC,
            direction: dir,
            cells: cells,
          );
        }
      }
    }

    return null; // Could not place word
  }
}
