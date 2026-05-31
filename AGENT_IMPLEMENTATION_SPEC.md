# Agent Implementation Specification

> STRICT PROTOCOL for implementing new games in Space Math Academy.
> Every agent MUST follow these rules exactly. Non-compliance breaks the app.

---

## FILES YOU MUST MODIFY (for EACH new game)

### 1. `lib/l10n/app_en.arb` -- Add EN strings
### 2. `lib/l10n/app_de.arb` -- Add DE strings  
### 3. `lib/core/models/skill_category.dart` -- Add to gameSkillMap
### 4. `lib/features/games/screens/game_menu_screen.dart`:
   - Add import at top (line ~35)
   - Add `_GameInfoData(...)` entry in `_getGamesList()` (after line 321)
   - Update `_gameCount` (line 82)
### 5. Create `lib/features/games/screens/{game}_game.dart` -- Game screen
### 6. Create `lib/features/games/services/{game}_logic.dart` -- Game logic (if needed)

---

## STRICT RULES

### Rule 1: _GameInfoData Registration

```dart
_GameInfoData(
  gameKey: 'your_game_key',           // snake_case, unique, used in gameSkillMap
  title: s.yourGameTitle,              // MUST reference i18n string
  description: s.yourGameDesc,         // MUST reference i18n string
  icon: Icons.material_icon,           // Material icon
  gradient: const LinearGradient(colors: [Color(0xFFXXXXXX), Color(0xFFYYYYYY)]),
  gameBuilder: (grade, level) => YourGameScreen(grade: grade, level: level),
),
```

### Rule 2: Skill Category Mapping

Add to `gameSkillMap` in `lib/core/models/skill_category.dart`:
```dart
'your_game_key': SkillCategory.logicDeduction,  // or arithmetic, spatial2d, spatial3d, patternRecognition
```

Choose the CORRECT category:
- `arithmetic` -- games where player solves math equations (uses SriService)
- `spatial3d` -- 3D reasoning, perspective puzzles
- `spatial2d` -- 2D grid/spatial puzzles
- `logicDeduction` -- pure logic, constraint solving, deduction
- `patternRecognition` -- patterns, sequences, combinatorics

### Rule 3: Game Screen Contract

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';

class YourGameScreen extends StatefulWidget {
  final int grade;
  final int level;
  const YourGameScreen({super.key, required this.grade, required this.level});
  @override
  State<YourGameScreen> createState() => _YourGameScreenState();
}

class _YourGameScreenState extends State<YourGameScreen> with TickerProviderStateMixin {
  // REQUIRED: animation controllers
  // REQUIRED: game state variables
  // REQUIRED: DifficultyConfig? currentDifficulty;

  @override
  void initState() {
    super.initState();
    // Init animation controllers HERE
    // Init game AFTER first frame:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level);
        _generatePuzzle();
      }
    });
  }

  @override
  void dispose() {
    // Dispose ALL animation controllers
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(
                title: s.yourGameTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(child: _buildGameArea()),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Rule 4: Win/Loss Reporting (MANDATORY)

On win:
```dart
void _handleWin(int score) {
  HapticFeedback.lightImpact();
  context.read<GameProvider>().reportOutcome(GameOutcome.win(
    gameType: 'your_game_key',  // MUST match gameSkillMap key
    difficulty: widget.level,
    score: score,
  ));
  _showWinDialog();
}
```

On loss:
```dart
void _handleLoss() {
  HapticFeedback.heavyImpact();
  context.read<GameProvider>().reportOutcome(GameOutcome.loss(
    gameType: 'your_game_key',
    difficulty: widget.level,
  ));
  _showLoseDialog();
}
```

### Rule 5: i18n String Format

In `app_en.arb`, add these keys (minimum):
```json
"yourGameTitle": "Game Title",
"yourGameDesc": "Description with space narrative...",
"yourGameInstructions": "How to play...",
"yourGameWinTitle": "Victory Title!",
"yourGameWinDesc": "Victory message with {bonusScore} placeholder.",
"yourGameLoseTitle": "Failure Title!",
"yourGameLoseDesc": "Failure message, Commander."
```

For placeholders, add `@` annotation:
```json
"@yourGameWinDesc": {
  "placeholders": {
    "bonusScore": {"type": "int", "example": "150"}
  }
}
```

Same keys in `app_de.arb` with German translations.

### Rule 6: Difficulty Scaling

Use `currentDifficulty` to scale the game:
- `currentDifficulty!.grade` (1-4) -- base difficulty tier
- `currentDifficulty!.level` (1-20) -- fine-grained level
- `currentDifficulty!.objectCount` -- how many game objects
- `currentDifficulty!.timeLimit` -- seconds allowed
- `currentDifficulty!.showHints` -- whether to show hints (true for levels 1-3)
- `currentDifficulty!.difficultyMultiplier` -- general scaling factor (1.0 to ~3.5)

Map these to your game's parameters (grid size, number range, clue count, etc.).

### Rule 7: Score Calculation

```dart
int baseScore = 100 * widget.grade;
int levelBonus = widget.level * 25;
int totalScore = baseScore + levelBonus; // Add puzzle-specific bonuses
```

### Rule 8: DO NOT

- Do NOT hardcode user-facing strings. ALL text goes through `S.of(context)!`
- Do NOT use `Navigator.pushNamed`. Use `Navigator.push(MaterialPageRoute(...))`
- Do NOT create new shared widgets. Use existing: `SpaceBackground`, `GameUI`, `SpaceTheme`
- Do NOT modify `tuning.dart`, `game_provider.dart`, or `difficulty_manager.dart`
- Do NOT add new dependencies to `pubspec.yaml`
- Do NOT create new folders -- put screens in `screens/`, logic in `services/`
- Do NOT use emoji in code comments or strings unless the existing code does

### Rule 9: dart_csp Usage (for CSP-based games)

```dart
import 'package:dart_csp/dart_csp.dart';

Future<Map<String, int>?> generatePuzzle() async {
  final problem = Problem();
  
  // Add variables with domains
  problem.addVariable('cell_0_0', List.generate(n, (i) => i + 1));
  
  // Add constraints
  problem.addConstraint(
    ['cell_0_0', 'cell_0_1'],
    (assignment) => assignment['cell_0_0'] != assignment['cell_0_1'],
  );
  
  // Add allDifferent for rows/columns
  problem.addAllDifferent(['cell_0_0', 'cell_0_1', 'cell_0_2']);
  
  // Solve with timeout
  final solution = await problem.getSolution().timeout(
    const Duration(seconds: 5),
    onTimeout: () => 'FAILURE',
  );
  
  if (solution == 'FAILURE') return null;
  return solution as Map<String, int>;
}
```

### Rule 10: File Naming Convention

- Screen: `{game_name}_game.dart` (e.g., `star_forge_game.dart`)
- Logic: `{game_name}_logic.dart` (e.g., `star_forge_logic.dart`)
- Game key: `snake_case` matching filename minus `_game` (e.g., `star_forge`)

---

## GAME ASSIGNMENTS

### Batch A: Pure CSP Grid Games (use dart_csp heavily)
| Game | Key | File | SkillCategory | Gradient |
|------|-----|------|---------------|----------|
| Star Forge (Magic Star) | `star_forge` | `star_forge_game.dart` | `logicDeduction` | `[0xFFFFD700, 0xFFFF6B35]` |
| Nebula Matrix (Number Grid) | `nebula_matrix` | `nebula_matrix_game.dart` | `logicDeduction` | `[0xFF6B48FF, 0xFFFF6B9D]` |
| Orbital Towers (Skyscrapers) | `orbital_towers` | `orbital_towers_game.dart` | `logicDeduction` | `[0xFFE63946, 0xFFFFD700]` |
| Hive Station (Honeycomb) | `hive_station` | `hive_station_game.dart` | `logicDeduction` | `[0xFFFFD700, 0xFFFF6B35]` |
| Relic Assembly (Edge Match) | `relic_assembly` | `relic_assembly_game.dart` | `spatial2d` | `[0xFFFF6B35, 0xFFFFD700]` |

### Batch B: Logic Deduction Games (CSP for generation)
| Game | Key | File | SkillCategory | Gradient |
|------|-----|------|---------------|----------|
| Vault Cracker (Mastermind) | `vault_cracker` | `vault_cracker_game.dart` | `logicDeduction` | `[0xFF6B48FF, 0xFFE63946]` |
| Crew Manifest (Logic Grid) | `crew_manifest` | `crew_manifest_game.dart` | `logicDeduction` | `[0xFF00C9DB, 0xFF06FFA5]` |
| Alien Tribunal (Liar's Table) | `alien_tribunal` | `alien_tribunal_game.dart` | `logicDeduction` | `[0xFF6B48FF, 0xFFE63946]` |
| Gravity Well (Balance) | `gravity_well` | `gravity_well_game.dart` | `arithmetic` | `[0xFF06FFA5, 0xFF00C9DB]` |

### Batch C: Interactive/Spatial Games
| Game | Key | File | SkillCategory | Gradient |
|------|-----|------|---------------|----------|
| Dark Matter Grid (Lights Out) | `dark_matter_grid` | `dark_matter_grid_game.dart` | `logicDeduction` | `[0xFF1A1A2E, 0xFF6B48FF]` |
| Dock Clearance (Rush Hour) | `dock_clearance` | `dock_clearance_game.dart` | `spatial2d` | `[0xFFE63946, 0xFF00C9DB]` |
| Ion Chain (Sequence) | `ion_chain` | `ion_chain_game.dart` | `logicDeduction` | `[0xFF06FFA5, 0xFF00C9DB]` |
| Launch Sequence (Sort) | `launch_sequence` | `launch_sequence_game.dart` | `logicDeduction` | `[0xFFE63946, 0xFFFFD700]` |

### Batch D: Pattern/Visual Games
| Game | Key | File | SkillCategory | Gradient |
|------|-----|------|---------------|----------|
| Sector Painter (Graph Color) | `sector_painter` | `sector_painter_game.dart` | `logicDeduction` | `[0xFFFF6B35, 0xFFFFD700]` |
| Warp Fold (Paper Fold) | `warp_fold` | `warp_fold_game.dart` | `spatial2d` | `[0xFFFF69B4, 0xFF6B48FF]` |
| Cube Scanner (Dice) | `cube_scanner` | `cube_scanner_game.dart` | `spatial3d` | `[0xFF6B48FF, 0xFFFF69B4]` |
| Circuit Repair (7-seg) | `circuit_repair` | `circuit_repair_game.dart` | `logicDeduction` | `[0xFFFFD700, 0xFFE63946]` |

### Batch E: Math/Counting Games
| Game | Key | File | SkillCategory | Gradient |
|------|-----|------|---------------|----------|
| Xenobiology Lab (Monster Math) | `xenobiology_lab` | `xenobiology_lab_game.dart` | `arithmetic` | `[0xFF06FFA5, 0xFFFFD700]` |
| Galactic Market (Coin Change) | `galactic_market` | `galactic_market_game.dart` | `arithmetic` | `[0xFFFFD700, 0xFF06FFA5]` |
| Creature Forge (Combinatorics) | `creature_forge` | `creature_forge_game.dart` | `patternRecognition` | `[0xFF06FFA5, 0xFFFF69B4]` |
| Asteroid Duel (Nim) | `asteroid_duel` | `asteroid_duel_game.dart` | `logicDeduction` | `[0xFFE63946, 0xFFFF6B35]` |
| Chrono Repair (Clock) | `chrono_repair` | `chrono_repair_game.dart` | `arithmetic` | `[0xFFFFD700, 0xFF6B48FF]` |

### Batch F: Word/Cipher Games  
| Game | Key | File | SkillCategory | Gradient |
|------|-----|------|---------------|----------|
| Star Chart Scan (Word Search) | `star_chart_scan` | `star_chart_scan_game.dart` | `patternRecognition` | `[0xFF00C9DB, 0xFFFFD700]` |
| Comm Relay (Cipher) | `comm_relay` | `comm_relay_game.dart` | `logicDeduction` | `[0xFF00C9DB, 0xFF6B48FF]` |
| Hull Plating (Domino Tile) | `hull_plating` | `hull_plating_game.dart` | `spatial2d` | `[0xFF8B8B8B, 0xFF00C9DB]` |
