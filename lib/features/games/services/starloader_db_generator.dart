// lib/features/games/services/starloader_db_generator.dart
import 'dart:convert';
import 'dart:io';
import '../lib/features/games/services/starloader_level_generator.dart';
import '../lib/features/games/models/starloader_level_database.dart';

class DatabaseGenerator {
  final String dbPath;
  final String tempPath;
  
  DatabaseGenerator({
    required this.dbPath,
    required this.tempPath,
  });

  Future<void> generate({
    required List<DifficultyConfig> configs,
    required int levelsPerConfig,
    Function(int current, int total)? onProgress,
  }) async {
    print('🎮 StarLoader Level Database Generator\n');
    print('=' * 60);
    
    // Load existing database or create new
    LevelDatabase db = await _loadOrCreateDatabase();
    print('📦 Loaded existing database with ${db.levels.length} levels\n');

    final generator = LevelGenerator();
    int totalToGenerate = configs.length * levelsPerConfig;
    int currentProgress = 0;

    for (final config in configs) {
      print('\n🎯 Generating ${config.difficulty} levels (${config.dimX}x${config.dimY}, ${config.numBoxes} boxes)...');
      
      int successCount = 0;
      int attempts = 0;
      final maxAttempts = levelsPerConfig * 3;

      while (successCount < levelsPerConfig && attempts < maxAttempts) {
        attempts++;
        
        try {
          final level = generator.generateLevel(
            dimX: config.dimX,
            dimY: config.dimY,
            numBoxes: config.numBoxes,
          );

          // Create entry
          final entry = LevelEntry(
            difficulty: config.difficulty,
            dimX: config.dimX,
            dimY: config.dimY,
            numBoxes: config.numBoxes,
            roomStructure: level.roomStructure,
            roomState: level.roomState,
            boxMapping: level.boxMapping,
            optimalMoves: level.optimalMoves,
          );

          db.addLevel(entry);
          successCount++;
          currentProgress++;

          // Atomic write every 10 levels
          if (successCount % 10 == 0) {
            await _atomicWrite(db);
            stdout.write('\r  Progress: $successCount/$levelsPerConfig (${attempts} attempts)');
          }

          if (onProgress != null) {
            onProgress(currentProgress, totalToGenerate);
          }

        } catch (e) {
          // Continue on failure
          continue;
        }
      }

      print('\n  ✓ Generated $successCount levels (${attempts} attempts)');
      
      // Save after each difficulty
      await _atomicWrite(db);
    }

    // Final save
    await _atomicWrite(db);
    
    print('\n' + '=' * 60);
    print('✅ Database generation complete!');
    print('   Total levels: ${db.levels.length}');
    print('   Database file: $dbPath');
    _printStatistics(db);
  }

  Future<LevelDatabase> _loadOrCreateDatabase() async {
    final file = File(dbPath);
    
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        return LevelDatabase.fromJson(json);
      } catch (e) {
        print('⚠️  Error loading database, creating new one: $e');
        return LevelDatabase.empty();
      }
    }
    
    return LevelDatabase.empty();
  }

  Future<void> _atomicWrite(LevelDatabase db) async {
    final tempFile = File(tempPath);
    final targetFile = File(dbPath);

    // Ensure directory exists
    await targetFile.parent.create(recursive: true);

    // Write to temp file first
    final json = jsonEncode(db.toJson());
    await tempFile.writeAsString(json);

    // Atomic rename
    await tempFile.rename(dbPath);
  }

  void _printStatistics(LevelDatabase db) {
    final difficulties = <String, int>{};
    for (final level in db.levels) {
      difficulties[level.difficulty] = (difficulties[level.difficulty] ?? 0) + 1;
    }

    print('\n📊 Level Distribution:');
    for (final entry in difficulties.entries) {
      print('   ${entry.key}: ${entry.value} levels');
    }
  }
}

class DifficultyConfig {
  final String difficulty;
  final int dimX;
  final int dimY;
  final int numBoxes;

  DifficultyConfig({
    required this.difficulty,
    required this.dimX,
    required this.dimY,
    required this.numBoxes,
  });
}

void main(List<String> args) async {
  final dbPath = args.isNotEmpty ? args[0] : 'data/levels.json';
  final tempPath = '$dbPath.tmp';

  final configs = [
    // Tutorial levels
    DifficultyConfig(difficulty: 'tutorial', dimX: 6, dimY: 6, numBoxes: 1),
    
    // Easy levels
    DifficultyConfig(difficulty: 'easy', dimX: 7, dimY: 7, numBoxes: 2),
    DifficultyConfig(difficulty: 'easy', dimX: 8, dimY: 7, numBoxes: 2),
    
    // Medium levels
    DifficultyConfig(difficulty: 'medium', dimX: 8, dimY: 8, numBoxes: 3),
    DifficultyConfig(difficulty: 'medium', dimX: 9, dimY: 8, numBoxes: 3),
    DifficultyConfig(difficulty: 'medium', dimX: 10, dimY: 9, numBoxes: 3),
    
    // Hard levels
    DifficultyConfig(difficulty: 'hard', dimX: 10, dimY: 10, numBoxes: 4),
    DifficultyConfig(difficulty: 'hard', dimX: 11, dimY: 10, numBoxes: 4),
    DifficultyConfig(difficulty: 'hard', dimX: 12, dimY: 11, numBoxes: 4),
    
    // Expert levels
    DifficultyConfig(difficulty: 'expert', dimX: 12, dimY: 12, numBoxes: 5),
    DifficultyConfig(difficulty: 'expert', dimX: 13, dimY: 12, numBoxes: 5),
  ];

  final levelsPerConfig = args.length > 1 ? int.parse(args[1]) : 50;

  final generator = DatabaseGenerator(
    dbPath: dbPath,
    tempPath: tempPath,
  );

  await generator.generate(
    configs: configs,
    levelsPerConfig: levelsPerConfig,
    onProgress: (current, total) {
      // Optional progress callback
    },
  );
}