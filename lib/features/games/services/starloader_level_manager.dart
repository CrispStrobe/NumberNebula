// ignore_for_file: avoid_print, constant_identifier_names
// lib/features/games/services/starloader_level_manager.dart:

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/starloader_level_model.dart';
import 'starloader_level_generator.dart';
import 'sokoban_generator.dart' as sokoban;
import '../screens/star_loader_game.dart';

class StarLoaderLevelManager {
  static final StarLoaderLevelManager _instance = StarLoaderLevelManager._internal();
  factory StarLoaderLevelManager() => _instance;
  StarLoaderLevelManager._internal();

  // --- Generator-selection settings (persisted; read from SharedPreferences so
  // they take effect on the next level without an app restart). Defaults make
  // the new difficulty-parametrized Sokoban generator the PRIMARY generator and
  // prefer the curated pre-generated pool. Both are toggled from the debug-only
  // Star Loader dev card in Settings.
  static const String prefUseSokobanGen = 'starloader_use_sokoban_gen';
  static const String prefPreferPregenerated = 'starloader_prefer_pregenerated';
  bool _useSokobanGenerator = true;
  bool _preferPregenerated = true;

  LevelDatabase _database = LevelDatabase.empty();

  // Verbose generator so you see the logs in CLI
  final LevelGenerator _realTimeGenerator = LevelGenerator(verbose: true);

  final Set<String> _playedLevelIds = {};
  bool _initialized = false;
  File? _localFile;

  /// 1. INITIALIZE: ONLY Load Local File. Ignore Assets.
  Future<void> initialize() async {
    if (_initialized) return;

    // A. Load Played History (so we don't repeat levels in this session)
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('starloader_played_ids');
      if (history != null) _playedLevelIds.addAll(history);
    } catch (e) {
      print('⚠️ [Manager] Failed to load history: $e');
    }

    // B. Setup Local JSON File Access
    try {
      final directory = await getApplicationDocumentsDirectory();
      _localFile = File('${directory.path}/starloader_db.json');
      print('📂 [Manager] DB Path: ${_localFile!.path}');

      if (await _localFile!.exists()) {
        final content = await _localFile!.readAsString();
        if (content.isNotEmpty) {
          final jsonMap = jsonDecode(content);
          _database = LevelDatabase.fromJson(jsonMap);
          print('✅ [Manager] Loaded Local DB: ${_database.levels.length} levels.');
        } else {
          print('🆕 [Manager] Local DB file exists but is empty.');
        }
      } else {
        print('🆕 [Manager] No Local DB found. Starting fresh.');
        await _saveDatabase(); // Create the empty file
      }
    } catch (e) {
      print('❌ [Manager] File System Error: $e');
      _database = LevelDatabase.empty();
    }

    // C. Merge the shipped, solver-verified level pool (in-memory; not
    // persisted to the local file). These are the curated levels — runtime
    // generation is only a fallback when the pool runs dry.
    await _mergeBundledLevels();

    _printDiagnostics();
    _initialized = true;
  }

  /// Loads the pre-baked asset pool and merges any levels not already present
  /// (deduped by physical layout via `contentHash`). Safe to call even when the
  /// asset is missing or unreadable.
  Future<void> _mergeBundledLevels() async {
    try {
      final raw = await rootBundle.loadString('assets/data/starloader_levels.json');
      final bundled = LevelDatabase.fromJson(jsonDecode(raw));
      final existing = _database.levels.map((l) => l.contentHash).toSet();
      var added = 0;
      for (final lvl in bundled.levels) {
        if (existing.add(lvl.contentHash)) {
          _database.levels.add(lvl);
          added++;
        }
      }
      print('📦 [Manager] Merged $added bundled levels '
          '(${bundled.levels.length} in asset).');
    } catch (e) {
      print('⚠️ [Manager] Could not load bundled levels: $e');
    }
  }

  /// Re-read the generator-selection toggles from SharedPreferences. Cheap
  /// (the plugin caches the instance) and called before every selection so the
  /// debug settings apply to the very next level.
  Future<void> _refreshGeneratorSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _useSokobanGenerator = prefs.getBool(prefUseSokobanGen) ?? true;
      _preferPregenerated = prefs.getBool(prefPreferPregenerated) ?? true;
    } catch (e) {
      print('⚠️ [Manager] Failed to read generator settings: $e');
    }
  }

  /// 2. GET LEVEL: DB First -> Fallback to Generate -> Save -> Return
  Future<LevelData> getLevelForGrade(int grade, int difficultyLevel) async {
    if (!_initialized) await initialize();
    await _refreshGeneratorSettings();

    final difficultyKey = 'grade_$grade';
    LevelEntry? selectedEntry;

    // --- STRATEGY A: LOOK IN THE PRE-GENERATED POOL ---
    // Skipped entirely when the user turned off "prefer pre-generated levels"
    // (debug setting) — then we always generate a fresh level directly.
    // Filter candidates:
    // 1. Must match grade
    // 2. Must NOT have been played yet
    // 3. Must NOT have been rated (Rating = user is done with it)
    final candidates = !_preferPregenerated
        ? <LevelEntry>[]
        : _database.levels.where((l) =>
            l.difficulty == difficultyKey &&
            !_playedLevelIds.contains(l.id) &&
            l.ratingCount == 0
          ).toList();

    if (candidates.isNotEmpty) {
      // Sort by Rating (High to Low)
      candidates.sort((a, b) => b.avgRating.compareTo(a.avgRating));

      // Selection Logic:
      // If we have few levels, force variety (random).
      // If we have a clear 5-star winner, pick it.
      bool pickBest = candidates.first.avgRating > 0;
      if (candidates.length < 3) pickBest = false; // Force random if pool is tiny

      if (pickBest) {
         selectedEntry = candidates.first;
         print('⭐ [Manager] Selected highest rated level (${selectedEntry.avgRating} stars).');
      } else {
         int poolSize = (candidates.length / 2).ceil().clamp(1, candidates.length);
         selectedEntry = candidates[Random().nextInt(poolSize)];
         print('🎲 [Manager] Selected random level from top $poolSize candidates.');
      }
    }

    // --- STRATEGY B: GENERATE NEW ---
    if (selectedEntry == null) {
      final why = _preferPregenerated ? 'Pool empty' : 'Pool skipped (setting)';
      final gen = _useSokobanGenerator ? 'sokoban' : 'legacy';
      print('🔧 [Manager] $why. Generating new level '
          '(Grade $grade, $gen generator)...');

      selectedEntry = _generateRealTimeEntry(grade, difficultyLevel);
      
      // SAVE TO DB IMMEDIATELY
      _database.levels.add(selectedEntry);
      await _saveDatabase();
      print('💾 [Manager] New level generated and written to JSON file.');
    }

    // CRITICAL: Mark as played NOW so we don't get it again next click
    await _markAsPlayed(selectedEntry.id);

    return _convertToLevelData(selectedEntry);
  }

  /// 3. RATE LEVEL: Update Memory -> Write to File
  Future<void> rateLevel(String levelId, int stars) async {
    final index = _database.levels.indexWhere((l) => l.id == levelId);
    
    if (index != -1) {
      final level = _database.levels[index];
      
      // Update stats
      final newCount = level.ratingCount + 1;
      final totalScore = (level.avgRating * level.ratingCount) + stars;
      final newAvg = totalScore / newCount;

      // Replace entry
      _database.levels[index] = LevelEntry(
        id: level.id,
        difficulty: level.difficulty,
        dimX: level.dimX,
        dimY: level.dimY,
        roomStructure: level.roomStructure,
        roomState: level.roomState,
        optimalMoves: level.optimalMoves,
        avgRating: newAvg,      // Updated
        ratingCount: newCount,  // Updated
      );

      // WRITE TO FILE
      await _saveDatabase();
      print('⭐ [Manager] Rating saved to file. Level $levelId is now ${newAvg.toStringAsFixed(1)} stars.');
    } else {
      print('⚠️ [Manager] Level $levelId not found in DB to rate.');
    }
  }

  /// 4. HELPER: Write memory to disk
  Future<void> _saveDatabase() async {
    if (_localFile == null) return;
    try {
      // Pretty print for readability if you open the file manually
      final jsonStr = const JsonEncoder.withIndent('  ').convert(_database.toJson());
      await _localFile!.writeAsString(jsonStr);
    } catch (e) {
      print('❌ [Manager] Failed to save JSON file: $e');
    }
  }

  /// 5. DEV TOOL: Export for Production
  /// Call this when you are happy with your levels and want to ship them.
  void printDatabaseForExport() {
    print('\n📋 [Manager] --- COPY CONTENT BELOW TO assets/data/starloader_levels.json ---');
    print(jsonEncode(_database.toJson()));
    print('📋 [Manager] ----------------------------------------------------------------\n');
  }

  // --- Internal Helpers ---

  void _printDiagnostics() {
    int totalLevels = _database.levels.length;
    int ratedLevels = _database.levels.where((l) => l.ratingCount > 0).length;
    
    Map<String, int> levelsPerGrade = {};
    for (var l in _database.levels) {
      levelsPerGrade[l.difficulty] = (levelsPerGrade[l.difficulty] ?? 0) + 1;
    }

    print('\n📊 [Manager] --- LOCAL JSON DIAGNOSTICS ---');
    print('   File Path:      ${_localFile?.path ?? "Unknown"}');
    print('   Total Levels:   $totalLevels');
    print('   Rated Levels:   $ratedLevels');
    print('   History Size:   ${_playedLevelIds.length}');
    print('   Breakdown:');
    levelsPerGrade.forEach((key, count) {
      print('     - $key: $count');
    });
    print('------------------------------------------\n');
  }

  LevelEntry _generateRealTimeEntry(int grade, int level) {
    if (_useSokobanGenerator) {
      return _generateSokobanEntry(grade, level);
    }
    return _generateLegacyEntry(grade, level);
  }

  /// Map a Star Loader grade (1..4) + in-grade progression to a Sokoban
  /// generator difficulty (1..10). Tuned so BOX COUNTS match the legacy
  /// per-grade sizing (2,3,3,4) and push counts sit in the same envelope —
  /// the new generator's win is richer levels (more forced ordering / detours)
  /// at a comparable length, not a harder game.
  ///   g1→d2 (2 boxes) · g2→d3 (3) · g3→d4 (3) · g4→d5 (4)
  int _gradeToSokobanDifficulty(int grade, int level) {
    const base = {1: 2, 2: 3, 3: 4, 4: 5};
    final b = base[grade] ?? 5;
    // Nudge difficulty up as the player progresses within a grade.
    final bump = (level ~/ 4).clamp(0, 2);
    return (b + bump).clamp(1, 10);
  }

  /// PRIMARY generator: the difficulty-parametrized reverse-play + A* Sokoban
  /// generator (lib/features/games/services/sokoban_generator.dart). Falls back
  /// to the legacy generator on the rare occasion generation can't hit a level
  /// within its time budget (so a level is always returned).
  LevelEntry _generateSokobanEntry(int grade, int level) {
    final difficulty = _gradeToSokobanDifficulty(grade, level);
    try {
      // Bounded time so a hard grade can't hang the UI; best-effort otherwise.
      final entry = sokoban.generateStarLoaderEntry(
        difficulty: difficulty,
        timeBudget: 6.0,
      );
      return LevelEntry(
        id: 'sok_${DateTime.now().millisecondsSinceEpoch}',
        difficulty: 'grade_$grade',
        dimX: entry.dimX,
        dimY: entry.dimY,
        roomStructure: entry.roomStructure,
        roomState: entry.roomState,
        optimalMoves: entry.optimalMoves,
      );
    } catch (e) {
      print('⚠️ [Manager] Sokoban generation failed ($e); '
          'falling back to legacy generator.');
      return _generateLegacyEntry(grade, level);
    }
  }

  /// LEGACY generator (kept for A/B comparison via the debug toggle).
  LevelEntry _generateLegacyEntry(int grade, int level) {
    int dimX, dimY, numBoxes, minPushes;
    if (grade == 1) { dimX = 7; dimY = 7; numBoxes = 2; minPushes = 6; }
    else if (grade == 2) { dimX = 8; dimY = 8; numBoxes = 3; minPushes = 9; }
    else if (grade == 3) { dimX = 10; dimY = 10; numBoxes = 3; minPushes = 13; }
    else { dimX = 12; dimY = 11; numBoxes = 4; minPushes = 17; }
    // Scale box interaction with level progression (capped so generation stays
    // feasible). More boxes => more forced ordering => harder puzzles.
    numBoxes += (level ~/ 4).clamp(0, 2);

    final genResult = _realTimeGenerator.generateLevel(
      dimX: dimX, dimY: dimY, numBoxes: numBoxes,
      maxTries: 20,
      // Real difficulty gate: require a genuinely non-trivial push-optimal
      // solution rather than the old boxSwaps*displacement proxy.
      minOptimalPushes: minPushes,
    );

    return LevelEntry(
      id: 'gen_${DateTime.now().millisecondsSinceEpoch}',
      difficulty: 'grade_$grade',
      dimX: dimX, dimY: dimY,
      roomStructure: genResult.roomStructure,
      roomState: genResult.roomState,
      optimalMoves: genResult.optimalMoves,
    );
  }

  Future<void> _markAsPlayed(String id) async {
    _playedLevelIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('starloader_played_ids', _playedLevelIds.toList());
  }

  LevelData _convertToLevelData(LevelEntry entry) {
    List<String> layout = [];
    const int WALL = 0, PLAYER = 5, BOX = 4, TARGET = 2;
    for (int y = 0; y < entry.roomState.length; y++) {
      String line = '';
      for (int x = 0; x < entry.roomState[y].length; x++) {
        final state = entry.roomState[y][x];
        final structure = entry.roomStructure[y][x];
        if (state == WALL) {
          line += 'W';
        } else if (state == PLAYER) {
          line += 'P';
        } else if (state == BOX) {
          line += (structure == TARGET ? 'X' : 'B');
        } else if (structure == TARGET) {
          line += 'T';
        } else {
          line += ' ';
        }
      }
      layout.add(line);
    }
    return LevelData(
      id: entry.id,
      layout: layout, 
      optimalMoves: entry.optimalMoves
    );
  }
  
  // Reset method if you want to clear local data during dev
  Future<void> clearLocalDatabase() async {
    if (_localFile != null && await _localFile!.exists()) {
      await _localFile!.delete();
      _database = LevelDatabase.empty();
      _playedLevelIds.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('starloader_played_ids');
      print('🧹 [Manager] Local Database and History Cleared.');
    }
  }
}
