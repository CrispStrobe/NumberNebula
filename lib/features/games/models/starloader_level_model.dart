// lib/features/games/models/starloader_level_model.dart:


/// Represents a single level entry in the database.
class LevelEntry {
  final String id;
  final String difficulty; // e.g. "grade_1", "grade_2"
  final int dimX;
  final int dimY;
  final List<List<int>> roomStructure;
  final List<List<int>> roomState;
  final int optimalMoves;

  final double avgRating;
  final int ratingCount;

  LevelEntry({
    required this.id,
    required this.difficulty,
    required this.dimX,
    required this.dimY,
    required this.roomStructure,
    required this.roomState,
    required this.optimalMoves,
    this.avgRating = 0.0, // Default 0
    this.ratingCount = 0,
  });

  factory LevelEntry.fromJson(Map<String, dynamic> json) {
    return LevelEntry(
      id: json['id'] as String,
      difficulty: json['difficulty'] as String,
      dimX: json['dimX'] as int,
      dimY: json['dimY'] as int,
      roomStructure: _parseGrid(json['roomStructure']),
      roomState: _parseGrid(json['roomState']),
      optimalMoves: json['optimalMoves'] as int,
      avgRating: (json['avgRating'] ?? 0.0).toDouble(),
      ratingCount: json['ratingCount'] ?? 0,
    );
  }

  /// Generates a unique hash based on the physical layout of the level.
  /// Ignores ID, difficulty label, and ratings.
  String get contentHash {
    final buffer = StringBuffer();
    buffer.write('${dimX}x$dimY:');
    
    // Encode Structure (Walls/Targets)
    for (var row in roomStructure) {
      buffer.write(row.join(''));
    }
    buffer.write('|');
    
    // Encode State (Player/Boxes)
    for (var row in roomState) {
      buffer.write(row.join(''));
    }
    // Simple String hash is sufficient for layout comparison
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'difficulty': difficulty,
        'dimX': dimX,
        'dimY': dimY,
        'roomStructure': roomStructure,
        'roomState': roomState,
        'optimalMoves': optimalMoves,
        'avgRating': avgRating,
        'ratingCount': ratingCount,
      };

  static List<List<int>> _parseGrid(dynamic list) {
    return (list as List).map((row) => List<int>.from(row)).toList();
  }
}

/// The container for all pre-generated levels.
class LevelDatabase {
  final List<LevelEntry> levels;

  LevelDatabase({required this.levels});

  factory LevelDatabase.fromJson(Map<String, dynamic> json) {
    var list = json['levels'] as List;
    List<LevelEntry> levelsList = list.map((i) => LevelEntry.fromJson(i)).toList();
    return LevelDatabase(levels: levelsList);
  }

  Map<String, dynamic> toJson() => {
        'levels': levels.map((e) => e.toJson()).toList(),
      };
      
  factory LevelDatabase.empty() => LevelDatabase(levels: []);
}