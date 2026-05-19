// lib/features/games/models/level_database.dart
import 'package:uuid/uuid.dart';

class LevelDatabase {
  static const String version = '1.0';
  final List<LevelEntry> levels;

  LevelDatabase({required this.levels});

  factory LevelDatabase.fromJson(Map<String, dynamic> json) {
    return LevelDatabase(
      levels: (json['levels'] as List)
          .map((e) => LevelEntry.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'levels': levels.map((e) => e.toJson()).toList(),
  };

  factory LevelDatabase.empty() => LevelDatabase(levels: []);

  void addLevel(LevelEntry entry) {
    levels.add(entry);
  }

  List<LevelEntry> getLevelsByDifficulty(String difficulty) {
    return levels.where((l) => l.difficulty == difficulty).toList();
  }
}

class LevelEntry {
  final String id;
  final String difficulty;
  final int dimX;
  final int dimY;
  final int numBoxes;
  final List<List<int>> roomStructure;
  final List<List<int>> roomState;
  final Map<String, List<int>> boxMapping;
  final int optimalMoves;
  final DateTime createdAt;

  LevelEntry({
    String? id,
    required this.difficulty,
    required this.dimX,
    required this.dimY,
    required this.numBoxes,
    required this.roomStructure,
    required this.roomState,
    required this.boxMapping,
    required this.optimalMoves,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  factory LevelEntry.fromJson(Map<String, dynamic> json) {
    return LevelEntry(
      id: json['id'],
      difficulty: json['difficulty'],
      dimX: json['dimX'],
      dimY: json['dimY'],
      numBoxes: json['numBoxes'],
      roomStructure: (json['roomStructure'] as List)
          .map((row) => (row as List).cast<int>())
          .toList(),
      roomState: (json['roomState'] as List)
          .map((row) => (row as List).cast<int>())
          .toList(),
      boxMapping: (json['boxMapping'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as List).cast<int>()),
      ),
      optimalMoves: json['optimalMoves'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'difficulty': difficulty,
    'dimX': dimX,
    'dimY': dimY,
    'numBoxes': numBoxes,
    'roomStructure': roomStructure,
    'roomState': roomState,
    'boxMapping': boxMapping,
    'optimalMoves': optimalMoves,
    'createdAt': createdAt.toIso8601String(),
  };
}

class ProgressTracker {
  final Set<String> playedLevels;
  final Map<String, int> levelAttempts;
  DateTime lastPlayed;

  ProgressTracker({
    Set<String>? playedLevels,
    Map<String, int>? levelAttempts,
    DateTime? lastPlayed,
  }) : playedLevels = playedLevels ?? {},
       levelAttempts = levelAttempts ?? {},
       lastPlayed = lastPlayed ?? DateTime.now();

  factory ProgressTracker.fromJson(Map<String, dynamic> json) {
    return ProgressTracker(
      playedLevels: (json['playedLevels'] as List).cast<String>().toSet(),
      levelAttempts: (json['levelAttempts'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int)),
      lastPlayed: DateTime.parse(json['lastPlayed']),
    );
  }

  Map<String, dynamic> toJson() => {
    'playedLevels': playedLevels.toList(),
    'levelAttempts': levelAttempts,
    'lastPlayed': lastPlayed.toIso8601String(),
  };

  factory ProgressTracker.empty() => ProgressTracker();

  void markPlayed(String levelId) {
    playedLevels.add(levelId);
    levelAttempts[levelId] = (levelAttempts[levelId] ?? 0) + 1;
    lastPlayed = DateTime.now();
  }

  bool hasPlayed(String levelId) => playedLevels.contains(levelId);
}