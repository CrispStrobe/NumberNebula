// ignore_for_file: avoid_print, constant_identifier_names
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart'; 
import 'starloader_level_generator.dart';
import '../models/starloader_level_model.dart';

// --- CONFIGURATION ---
const String MASTER_PATH = 'lib/features/games/data/starloader_master_db.json';

class GradeConfig {
  final int grade;
  final int dimX;
  final int dimY;
  final int numBoxes;
  GradeConfig(this.grade, this.dimX, this.dimY, this.numBoxes);
}

void main(List<String> args) async {
  // 1. SETUP
  int countToAdd = 5; 
  String? sandboxPath;

  if (args.isNotEmpty) countToAdd = int.tryParse(args[0]) ?? 5;
  if (args.length > 1) sandboxPath = args[1];

  if (sandboxPath == null) {
    print('❌ Error: You must provide the Sandbox Path.');
    return;
  }

  print('\n🔄 STARTING SYNC & GENERATION (VERBOSE MODE)');
  print('   Target:       +$countToAdd levels per grade');
  print('   Sandbox File: $sandboxPath');

  // 2. LOAD & DEDUPLICATE (The "Truth" Step)
  // We use a Map keyed by 'contentHash' to strictly prevent duplicates.
  Map<String, LevelEntry> uniqueLevels = {}; 
  
  // Load Master First
  await _mergeFromFile(File(MASTER_PATH), uniqueLevels, "Master");
  
  // Load Sandbox Second (Prioritize its ratings/IDs)
  await _mergeFromFile(File(sandboxPath), uniqueLevels, "Sandbox");
  
  print('📊 Starting Unique Pool: ${uniqueLevels.length} levels');

  // 3. GENERATE
  final configs = [
    GradeConfig(1, 7, 7, 2),
    GradeConfig(2, 8, 8, 2),
    GradeConfig(3, 10, 10, 3),
    GradeConfig(4, 12, 11, 4),
  ];

  // ENABLE VERBOSE LOGS HERE
  final generator = LevelGenerator(verbose: true); 
  const uuid = Uuid();
  int totalAdded = 0;

  for (final config in configs) {
    int needed = countToAdd;

    print('\n🔨 --- Grade ${config.grade}: Generating $needed new levels ---');

    // Aggressive Loop: Keep trying until we find 'needed' UNIQUE levels
    int attempts = 0;
    int maxAttempts = needed * 200; // Give it plenty of tries

    while (needed > 0 && attempts < maxAttempts) {
      attempts++;
      try {
        // Generate Level (Verbose logs will appear here)
        final levelData = generator.generateLevel(
          dimX: config.dimX,
          dimY: config.dimY,
          numBoxes: config.numBoxes,
          maxTries: 20, 
          minMoves: 8,
        );

        final tempEntry = LevelEntry(
          id: uuid.v4(),
          difficulty: 'grade_${config.grade}',
          dimX: config.dimX,
          dimY: config.dimY,
          roomStructure: levelData.roomStructure,
          roomState: levelData.roomState,
          optimalMoves: levelData.optimalMoves,
          avgRating: 0.0,
          ratingCount: 0,
        );

        // STRICT DEDUPLICATION
        // Check if this layout string already exists in our pool
        if (!uniqueLevels.containsKey(tempEntry.contentHash)) {
          uniqueLevels[tempEntry.contentHash] = tempEntry;
          needed--;
          totalAdded++;
          print('✅ New Unique Level Added! (Remaining: $needed)');
        } else {
          print('⚠️ Duplicate layout generated. Discarding.');
        }
      } catch (e) {
        // Generator failures are printed by the generator itself (verbose: true)
      }
    }
    
    if (needed > 0) {
      print('❌ Timed out finding unique levels for Grade ${config.grade}. (Short by $needed)');
    }
  }

  // 4. SAVE (WRITE DEDUPLICATED DATA TO BOTH)
  final sortedLevels = uniqueLevels.values.toList();
  // Optional: Sort for consistent file ordering (e.g. by Grade)
  sortedLevels.sort((a, b) => a.difficulty.compareTo(b.difficulty));

  final finalDb = LevelDatabase(levels: sortedLevels);
  final jsonString = const JsonEncoder.withIndent('  ').convert(finalDb.toJson());

  print('\n💾 Saving Clean DB to Sandbox...');
  await File(sandboxPath).writeAsString(jsonString);
  
  print('💾 Saving Clean DB to Master...');
  // Ensure lib directory exists (it should locally)
  final masterFile = File(MASTER_PATH);
  if (!masterFile.parent.existsSync()) {
    masterFile.parent.createSync(recursive: true);
  }
  await masterFile.writeAsString(jsonString);

  print('\n✅ SYNC & GENERATION COMPLETE.');
  print('   New Levels:   $totalAdded');
  print('   Total Unique: ${finalDb.levels.length}');
}

/// Merges a file into the unique map, preferring entries with ratings/play data.
Future<void> _mergeFromFile(File file, Map<String, LevelEntry> map, String label) async {
  if (!await file.exists()) {
    print('   $label: File not found.');
    return;
  }
  try {
    final content = await file.readAsString();
    if (content.trim().isEmpty) return;
    
    final db = LevelDatabase.fromJson(jsonDecode(content));
    int added = 0;
    int updated = 0;

    for (var entry in db.levels) {
      final hash = entry.contentHash; // REQUIRES your contentHash getter in LevelEntry

      if (!map.containsKey(hash)) {
        map[hash] = entry;
        added++;
      } else {
        // Conflict! Keep the "better" version (has ratings, or permanent ID)
        final existing = map[hash]!;
        
        bool replace = false;
        // Logic: Ratings trump everything
        if (entry.ratingCount > existing.ratingCount) {
          replace = true;
        } else if (!entry.id.startsWith('gen_') && existing.id.startsWith('gen_')) {
          replace = true;
        }

        if (replace) {
          map[hash] = entry;
          updated++;
        }
      }
    }
    print('   $label: Processed ${db.levels.length} entries. (+ $added unique, ^ $updated updated)');
  } catch (e) {
    print('⚠️ Error reading $label DB: $e');
  }
}