// lib/features/games/services/starloader_level_manager.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/level_database.dart';
import 'starloader_level_generator.dart';

class StarLoaderLevelManager {
  static const String DB_PATH = 'assets/data/starloader_levels.json';
  static const String PROGRESS_PATH = 'starloader_progress.json';
  
  LevelDatabase? _database;
  ProgressTracker? _progressTracker;
  final LevelGenerator _generator = LevelGenerator();
  final Random _random = Random();
  
  String? _dataDir;

  Future<void> initialize({String? dataDir}) async {
    _dataDir = dataDir;
    await _loadDatabase();
    await _loadProgress();
  }

  Future<void> _loadDatabase() async {
    try {
      // Try to load from assets
      final String jsonString = await rootBundle.loadString(DB_PATH);
      final json = jsonDecode(jsonString);
      _database = LevelDatabase.fromJson(json);
      print('📦 Loaded level database with ${_database!.levels.length} levels');
    } catch (e) {
      print('⚠️  Could not load level database: $e');
      print('   Will generate levels on demand');
      _database = null;
    }
  }

  Future<void> _loadProgress() async {
    if (_dataDir == null) return;

    final file = File('$_dataDir/$PROGRESS_PATH');
    
    try {
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        _progressTracker = ProgressTracker.fromJson(json);
        print('📊 Loaded progress: ${_progressTracker!.playedLevels.length} levels played');
      } else {
        _progressTracker = ProgressTracker.empty();
      }
    } catch (e) {
      print('⚠️  Error loading progress: $e');
      _progressTracker = ProgressTracker.empty();
    }
  }

  Future<void> _saveProgress() async {
    if (_dataDir == null || _progressTracker == null) return;

    final file = File('$_dataDir/$PROGRESS_PATH');
    await file.parent.create(recursive: true);
    
    final json = jsonEncode(_progressTracker!.toJson());
    await file.writeAsString(json);
  }

  Future<LoadedLevel> getLevel({required String difficulty}) async {
    // Try to get from database first
    if (_database != null && _progressTracker != null) {
      final unplayedLevels = _database!.getLevelsByDifficulty(difficulty)
          .where((level) => !_progressTracker!.hasPlayed(level.id))
          .toList();

      if (unplayedLevels.isNotEmpty) {
        // Pick a random unplayed level
        final level = unplayedLevels[_random.nextInt(unplayedLevels.length)];
        
        return LoadedLevel(
          id: level.id,
          difficulty: level.difficulty,
          roomStructure: level.roomStructure,
          roomState: level.roomState,
          boxMapping: level.boxMapping,
          optimalMoves: level.optimalMoves,
          fromDatabase: true,
        );
      }

      print('⚠️  No unplayed $difficulty levels in database, generating new one...');
    }

    // Fall back to generator
    return await _generateLevel(difficulty);
  }

  Future<LoadedLevel> _generateLevel(String difficulty) async {
    final config = _getDifficultyConfig(difficulty);
    
    final generatedLevel = _generator.generateLevel(
      dimX: config.dimX,
      dimY: config.dimY,
      numBoxes: config.numBoxes,
    );

    return LoadedLevel(
      id: 'generated_${DateTime.now().millisecondsSinceEpoch}',
      difficulty: difficulty,
      roomStructure: generatedLevel.roomStructure,
      roomState: generatedLevel.roomState,
      boxMapping: generatedLevel.boxMapping,
      optimalMoves: generatedLevel.optimalMoves,
      fromDatabase: false,
    );
  }

  DifficultyConfig _getDifficultyConfig(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'tutorial':
        return DifficultyConfig(dimX: 6, dimY: 6, numBoxes: 1);
      case 'easy':
        return DifficultyConfig(dimX: 7 + _random.nextInt(2), dimY: 7, numBoxes: 2);
      case 'medium':
        return DifficultyConfig(dimX: 8 + _random.nextInt(3), dimY: 8 + _random.nextInt(2), numBoxes: 3);
      case 'hard':
        return DifficultyConfig(dimX: 10 + _random.nextInt(3), dimY: 10 + _random.nextInt(2), numBoxes: 4);
      case 'expert':
        return DifficultyConfig(dimX: 12 + _random.nextInt(2), dimY: 12, numBoxes: 5);
      default:
        return DifficultyConfig(dimX: 8, dimY: 8, numBoxes: 3);
    }
  }

  Future<void> markLevelPlayed(String levelId) async {
    if (_progressTracker != null) {
      _progressTracker!.markPlayed(levelId);
      await _saveProgress();
    }
  }

  Future<void> markLevelCompleted(String levelId, int moveCount) async {
    await markLevelPlayed(levelId);
    // You can extend this to track completion stats
  }

  int getUnplayedCount(String difficulty) {
    if (_database == null || _progressTracker == null) return 0;
    
    return _database!.getLevelsByDifficulty(difficulty)
        .where((level) => !_progressTracker!.hasPlayed(level.id))
        .length;
  }

  int getTotalCount(String difficulty) {
    if (_database == null) return 0;
    return _database!.getLevelsByDifficulty(difficulty).length;
  }

  Map<String, int> getUnplayedCountByDifficulty() {
    if (_database == null || _progressTracker == null) return {};
    
    final counts = <String, int>{};
    for (final level in _database!.levels) {
      if (!_progressTracker!.hasPlayed(level.id)) {
        counts[level.difficulty] = (counts[level.difficulty] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> resetProgress() async {
    _progressTracker = ProgressTracker.empty();
    await _saveProgress();
  }
}

class LoadedLevel {
  final String id;
  final String difficulty;
  final List<List<int>> roomStructure;
  final List<List<int>> roomState;
  final Map<String, List<int>> boxMapping;
  final int optimalMoves;
  final bool fromDatabase;

  LoadedLevel({
    required this.id,
    required this.difficulty,
    required this.roomStructure,
    required this.roomState,
    required this.boxMapping,
    required this.optimalMoves,
    required this.fromDatabase,
  });
}

class DifficultyConfig {
  final int dimX;
  final int dimY;
  final int numBoxes;

  DifficultyConfig({
    required this.dimX,
    required this.dimY,
    required this.numBoxes,
  });
}