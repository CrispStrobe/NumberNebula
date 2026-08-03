// lib/features/games/providers/game_provider.dart
import 'package:flutter/foundation.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/skill_category.dart';
import '../../../core/services/sri_service.dart';
import '../../../core/services/cognitive_profile_service.dart';
import '../models/game_outcome.dart';
import '../models/math_problem.dart';
import '../models/performance.dart';
import '../tuning.dart';
import '../constants/app_constants.dart'; // For MathOperation and NumberRange

/// User-facing difficulty mode picked from the menu. Shifts the grade
/// passed into a game so kids can sample easier or harder content
/// without changing their official grade selection.
enum DifficultyMode {
  easy,
  normal,
  challenge,
}

extension DifficultyModeShift on DifficultyMode {
  int get gradeShift {
    switch (this) {
      case DifficultyMode.easy:
        return -1;
      case DifficultyMode.normal:
        return 0;
      case DifficultyMode.challenge:
        return 1;
    }
  }
}

// The Achievement data class. It should be at the top-level, NOT inside another class.
class Achievement {
  final String id;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    this.unlockedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'])
          : null,
    );
  }
}

// The GameProvider class. There should only be ONE declaration of this.
class GameProvider extends ChangeNotifier {
  final ProgressService _progressService;
  final SriService _sriService;
  final CognitiveProfileService _cognitiveProfileService;

  int _score = 0;
  int _level = 1;
  int _grade = 1;
  int _lives = 3;
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _puzzleTimerEnabled = true;
  bool _useAdaptiveDifficulty = false;
  DifficultyMode _difficultyMode = DifficultyMode.normal;
  Map<String, int> _gameProgress = {};
  List<Achievement> _achievements = [];
  bool _isFullVersionUnlocked = false;

  String _multiplicationSymbol = '×'; // Options: '×', '·', '*'
  String _divisionSymbol = '÷'; // Options: '÷', '/', ':', '%'

  bool _useCustomProblemSettings = false;
  Set<String> _customOperations = {'addition', 'subtraction'}; // Default to basic ops
  int _customRangeMin = 1;
  int _customRangeMax = 20;

  GameProvider({
    required ProgressService progressService,
    required SriService sriService,
    required CognitiveProfileService cognitiveProfileService,
  }) : _progressService = progressService,
       _sriService = sriService,
       _cognitiveProfileService = cognitiveProfileService {
    if (!AppConfig.inappsActive) {
      _isFullVersionUnlocked = true;
    }
  }

  Map<String, int> _currentLevelWins = {};

  /// Best star rating achieved per game (1-3). Persisted.
  Map<String, int> _bestStars = {};
  /// Star rating from the most recent reportOutcome call.
  int _lastStars = 0;

  /// The most recent outcome reported by any game, and a monotonic counter of
  /// how many have been reported this session. Callers that launch a game and
  /// want to know what happened (missions, in particular) snapshot
  /// [outcomeCount] before pushing the game screen and compare afterwards:
  /// an unchanged counter means the player quit without finishing a round.
  GameOutcome? _lastOutcome;
  int _outcomeCount = 0;

  int get lastStars => _lastStars;
  GameOutcome? get lastOutcome => _lastOutcome;
  int get outcomeCount => _outcomeCount;

  /// Normalized 0..1 quality of the most recent round (0 if none yet).
  double get lastPerformance => _lastOutcome?.effectivePerformance ?? 0.0;

  /// Grade bucket of [lastPerformance].
  PerfGrade get lastGrade => gradeForPerformance(lastPerformance);

  Map<String, int> get bestStars => Map.unmodifiable(_bestStars);

  // Getter
  bool get isFullVersionUnlocked => _isFullVersionUnlocked;

  // Setter - This will be called by your purchase service on success
  void unlockFullVersion() {
    _isFullVersionUnlocked = true;
    notifyListeners();
    _saveProgress();
    // alternatively: We don't save here directly; we let the app lifecycle handle it
    // to batch save operations.
  }

  /// DEBUG: Forces specific game progress levels to a new level.
  void debugSetGameLevels(int newLevel, List<String> gameKeys) {
    if (gameKeys.isEmpty) return; // Do nothing if no keys are selected

    if (kDebugMode) debugPrint('[DEBUG] Forcing ${gameKeys.length} game(s) to level $newLevel');
    
    for (final gameKey in gameKeys) {
      // We check if the key is valid by looking in the official gameSkillMap
      if (gameSkillMap.containsKey(gameKey)) {
        _gameProgress[gameKey] = newLevel;
      } else {
        if (kDebugMode) debugPrint('[DEBUG] Unknown game key: $gameKey. Skipping.');
      }
    }
    
    // Clear the session win history for any affected games
    _currentLevelWins.removeWhere((key, value) => gameKeys.contains(key));
    
    notifyListeners();
    _saveProgress();
  }

  // Getters
  int get score => _score;
  int get level => _level;
  int get grade => _grade; // Internally, we'll still call this 'grade'
  DifficultyMode get difficultyMode => _difficultyMode;

  /// Grade with the current [difficultyMode] shift applied, clamped to 1-6.
  /// Use this when launching games so the player can sample easier/harder
  /// content without changing their official grade.
  int get effectiveGrade =>
      (_grade + _difficultyMode.gradeShift).clamp(1, 6);

  void setDifficultyMode(DifficultyMode mode) {
    if (_difficultyMode == mode) return;
    _difficultyMode = mode;
    notifyListeners();
    _saveProgress();
  }
  int get lives => _lives;
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get puzzleTimerEnabled => _puzzleTimerEnabled;
  
  bool get useAdaptiveDifficulty => _useAdaptiveDifficulty;

  Map<String, int> get gameProgress => _gameProgress;
  List<Achievement> get achievements => _achievements;

  String get multiplicationSymbol => _multiplicationSymbol;
  String get divisionSymbol => _divisionSymbol;

  bool get useCustomProblemSettings => _useCustomProblemSettings;
  Set<String> get customOperations => _customOperations;
  int get customRangeMin => _customRangeMin;
  int get customRangeMax => _customRangeMax;

  Future<void> _saveProgress() async {
    // This is a "fire and forget" call. We don't need to wait for it.
    _progressService.saveProgress(this);
  }

  /// Canonical end-of-level reporting entry point. Every game should
  /// funnel through here.
  ///
  /// Returns true iff the player advanced to the next level as a result
  /// of this outcome.
  bool reportOutcome(GameOutcome outcome) {
    if (kDebugMode) {
      debugPrint(
        '[GAME_PROVIDER] 🎯 Recording ${outcome.gameType} result: '
        '${outcome.wasSuccessful ? "WIN" : "LOSS"} at difficulty ${outcome.difficulty}');
    }

    if (outcome.wasSuccessful) addScore(outcome.score);

    _lastOutcome = outcome;
    _outcomeCount++;
    if (kDebugMode) {
      debugPrint('[GAME_PROVIDER] 📊 Performance: '
          '${performancePercent(outcome.effectivePerformance)}% '
          '(${outcome.grade.name}${outcome.performance == null ? ', estimated' : ''})');
    }

    // Compute normalized star rating. Games that measured how cleanly the
    // round was played grade on that; the rest fall back to raw score.
    _lastStars = !outcome.wasSuccessful
        ? 0
        : outcome.performance != null
            ? starsForPerformance(outcome.performance!)
            : scoreToStars(
                outcome.gameType, outcome.score, outcome.wasSuccessful);
    if (_lastStars > (_bestStars[outcome.gameType] ?? 0)) {
      _bestStars[outcome.gameType] = _lastStars;
    }
    if (kDebugMode) debugPrint('[GAME_PROVIDER] ⭐ Stars: $_lastStars (best: ${_bestStars[outcome.gameType]})');

    _currentLevelWins[outcome.gameType] =
        (_currentLevelWins[outcome.gameType] ?? 0) +
            (outcome.wasSuccessful ? 1 : 0);

    final skill = gameSkillMap[outcome.gameType];
    if (skill == null) {
      if (kDebugMode) debugPrint('[GAME_PROVIDER] ⚠️ Unknown game type: ${outcome.gameType}');
      return false;
    }

    if (skill == SkillCategory.arithmetic) {
      if (outcome.mathProblems.isNotEmpty) {
        for (final problem in outcome.mathProblems) {
          _sriService.recordResponse(problem, outcome.wasSuccessful);
        }
        if (kDebugMode) {
          debugPrint(
            '[GAME_PROVIDER] Recorded ${outcome.mathProblems.length} math problem(s) for ${outcome.gameType}');
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            '[GAME_PROVIDER] ⚠️ Arithmetic game ${outcome.gameType} missing MathProblem data');
        }
      }
    } else {
      _cognitiveProfileService.recordAttempt(
          skill, outcome.difficulty, outcome.wasSuccessful);
    }

    bool didAdvance = false;
    if (outcome.wasSuccessful &&
        canAdvanceToNextLevel(
            outcome.gameType, _gameProgress[outcome.gameType] ?? 1)) {
      advanceLevel(outcome.gameType);
      didAdvance = true;
    }

    _saveProgress();
    return didAdvance;
  }

  /// Legacy shim. Prefer [reportOutcome] with a [GameOutcome] factory.
  @Deprecated('Use reportOutcome(GameOutcome.win/.loss/.fromRatio(...))')
  bool recordLevelWin({
    required String gameType,
    required int scoreGained,
    required int difficulty,
    required bool wasSuccessful,
    MathProblem? mathProblem,
    List<MathProblem>? mathProblems,
  }) {
    final problems = <MathProblem>[
      if (mathProblem != null) mathProblem,
      ...?mathProblems,
    ];
    return reportOutcome(GameOutcome(
      gameType: gameType,
      difficulty: difficulty,
      score: scoreGained,
      wasSuccessful: wasSuccessful,
      mathProblems: problems,
    ));
  }

  bool canAdvanceToNextLevel(String gameType, int currentLevel) {
    if ((_currentLevelWins[gameType] ?? 0) < kWinsRequiredForLevelUp) {
      if (kDebugMode) {
        debugPrint('[GAME_PROVIDER] ❌ $gameType: '
          'Only ${_currentLevelWins[gameType] ?? 0}/$kWinsRequiredForLevelUp wins');
      }
      return false;
    }

    final skill = gameSkillMap[gameType];
    if (skill == null) return false;

    if (skill == SkillCategory.arithmetic) {
      return _checkArithmeticMastery(currentLevel);
    } else {
      return _cognitiveProfileService.hasMastery(skill, currentLevel);
    }
  }

  void advanceLevel(String gameType) {
    if (kDebugMode) debugPrint('[GAME_PROVIDER] 📈 $gameType advancing to level ${(_gameProgress[gameType] ?? 1) + 1}');
    updateGameProgress(gameType, (_gameProgress[gameType] ?? 1) + 1);
    _currentLevelWins[gameType] = 0;
  }

  bool _checkArithmeticMastery(int difficulty) {
    final breakdown = _sriService.getDetailedBreakdown();
    
    List<MathOperation> relevantOps;
    if (difficulty <= 5) {
      relevantOps = [MathOperation.addition, MathOperation.subtraction];
    } else if (difficulty <= 10) {
      relevantOps = [MathOperation.addition, MathOperation.subtraction, MathOperation.multiplication];
    } else {
      relevantOps = MathOperation.values.toList();
    }

    int totalTracked = 0;
    int totalMastered = 0;
    
    for (var op in relevantOps) {
      for (var range in NumberRange.values) {
        final stat = breakdown[op]?[range];
        if (stat != null && stat.tracked > 0) {
          totalTracked += stat.tracked;
          totalMastered += stat.mastered;
        }
      }
    }
    
    final hasMastery = totalTracked >= kMinTrackedProblemsForMastery &&
        (totalMastered / totalTracked) >= kDefaultPassThreshold;
    if (kDebugMode) debugPrint('[GAME_PROVIDER] Arithmetic mastery @ $difficulty: $totalMastered/$totalTracked ${hasMastery ? "✓" : "✗"}');
    return hasMastery;
  }

  // --- Setters for Custom Settings ---
  void setUseCustomSettings(bool value) {
    _useCustomProblemSettings = value;
    notifyListeners();
  }

  void setCustomOperations(Set<String> operations) {
    _customOperations = operations;
    notifyListeners();
  }

  void setCustomRange({required int min, required int max}) {
    if (min <= max) {
      _customRangeMin = min;
      _customRangeMax = max;
      notifyListeners();
    }
  }

  void setMultiplicationSymbol(String symbol) {
    _multiplicationSymbol = symbol;
    notifyListeners();
    _saveProgress();
  }

  void setDivisionSymbol(String symbol) {
    _divisionSymbol = symbol;
    notifyListeners();
    _saveProgress();
  }

  // Score management
  void addScore(int points) {
    _score += points;
    _checkAchievements();
    notifyListeners();
    _saveProgress();
  }

  void setPuzzleTimer(bool enabled) {
    _puzzleTimerEnabled = enabled;
    notifyListeners();
  }

  void resetScore() {
    _score = 0;
    notifyListeners();
  }

  // Level management
  void nextLevel() {
    _level++;
    notifyListeners();
    _saveProgress();
  }

  void setLevel(int level) {
    _level = level;
    notifyListeners();
  }

  void setDifficulty(int newGrade, int newLevel) {
    _grade = newGrade;
    _level = newLevel;
    notifyListeners();
    _saveProgress();
  }

  // Grade/Skill Level management
  void setGrade(int grade) {
    _grade = grade.clamp(1, 4); // UPDATED: Clamp to 1-4
    _level = 1; // Reset level when changing grade
    notifyListeners();
    _saveProgress();
  }

  // Setter for adaptive difficulty
  void setUseAdaptiveDifficulty(bool value) {
    _useAdaptiveDifficulty = value;
    notifyListeners();
  }

  // Lives management
  void loseLife() {
    if (_lives > 0) {
      _lives--;
      notifyListeners();
    }
  }

  void resetLives() {
    _lives = 3;
    notifyListeners();
  }

  void addLife() {
    _lives++;
    notifyListeners();
  }

  // Settings
  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    notifyListeners();
  }

  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    notifyListeners();
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    notifyListeners();
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    notifyListeners();
  }

  // Game progress tracking
  void updateGameProgress(String gameType, int level) {
    _gameProgress[gameType] = level;
    _checkAchievements();
    notifyListeners();
    _saveProgress();
  }

  int getGameProgress(String gameType) {
    return _gameProgress[gameType] ?? 0;
  }

  // Achievement system
  void _checkAchievements() {
    final newAchievements = <Achievement>[];
    
    if (_score >= 100 && !hasAchievement('first_century')) { newAchievements.add(Achievement(id: 'first_century')); }
    if (_score >= 500 && !hasAchievement('score_master')) { newAchievements.add(Achievement(id: 'score_master')); }
    if (_score >= 1000 && !hasAchievement('thousand_club')) { newAchievements.add(Achievement(id: 'thousand_club')); }
    if (_level >= 5 && !hasAchievement('level_explorer')) { newAchievements.add(Achievement(id: 'level_explorer')); }
    if (_level >= 10 && !hasAchievement('space_commander')) { newAchievements.add(Achievement(id: 'space_commander')); }
    if (getGameProgress('magic_triangles') >= 3 && !hasAchievement('triangle_wizard')) { newAchievements.add(Achievement(id: 'triangle_wizard')); }
    if (getGameProgress('asteroid_math') >= 3 && !hasAchievement('bubble_popper')) { newAchievements.add(Achievement(id: 'bubble_popper')); }
    if (getGameProgress('puzzle_math') >= 3 && !hasAchievement('puzzle_solver')) { newAchievements.add(Achievement(id: 'puzzle_solver')); }
    if (getGameProgress('number_walls') >= 3 && !hasAchievement('number_walls_pro')) { newAchievements.add(Achievement(id: 'number_walls_pro')); }
    if (getGameProgress('codebreaker') >= 3 && !hasAchievement('codebreaker_pro')) { newAchievements.add(Achievement(id: 'codebreaker_pro')); }

    // Arithmetic Ace (Level 5 in both Arithmetic Square and Crosswords)
    if (getGameProgress('arithmatic_square') >= 5 && // Assuming 'arithmatic_square' is the key
        getGameProgress('arithmancer_crosswords') >= 5 &&
        !hasAchievement('arithmetic_ace')) { 
        newAchievements.add(Achievement(id: 'arithmetic_ace')); 
    }

    // Logic Grid Master (Level 5 in Kenken, indicating larger grid complexity)
    if (getGameProgress('kenken') >= 5 && 
        !hasAchievement('logic_grid_master')) { 
        newAchievements.add(Achievement(id: 'logic_grid_master')); 
    }

    final gamesCompleted = _gameProgress.values.where((level) => level >= 1).length;
    if (gamesCompleted >= 3 && !hasAchievement('all_rounder')) {
      newAchievements.add(Achievement(id: 'all_rounder'));
    }

    if (newAchievements.isNotEmpty) {
      _achievements.addAll(newAchievements);
    }
  }

  bool hasAchievement(String achievementId) {
    return _achievements.any((achievement) => achievement.id == achievementId);
  }

  // Game state management
  void resetGame() {
    _score = 0;
    _level = 1;
    _lives = 3;
    _achievements.clear(); // Also clear achievements for a full reset
    _gameProgress.clear();
    _bestStars.clear();
    notifyListeners();
    _saveProgress();
  }

  void startNewGame(String gameType) {
    _score = 0;
    _lives = 3;
    notifyListeners();
  }

  // Statistics
  int get totalGamesPlayed {
    if (_gameProgress.isEmpty) return 0;
    return _gameProgress.values.reduce((a, b) => a + b);
  }
  
  int get totalAchievements => _achievements.length;

  double get averageLevel {
    if (_gameProgress.isEmpty) return 0.0;
    final totalLevels = _gameProgress.values.fold(0, (sum, level) => sum + level);
    return totalLevels / _gameProgress.length;
  }

  // Grade progression
  bool canProgressToNextGrade() {
    final totalLevelsInGrade = _gameProgress.values.fold(0, (sum, level) => sum + level);
    final requiredLevels = _grade * 3;
    return totalLevelsInGrade >= requiredLevels;
  }

  void progressToNextGrade() {
    if (canProgressToNextGrade() && _grade < 6) {
      _grade++;
      _level = 1;
      _gameProgress.clear();

      if (!hasAchievement('grade_$_grade')) {
        _achievements.add(Achievement(id: 'grade_$_grade'));
      }

      notifyListeners();
    }
  }

  // Save/Load functionality
  Map<String, dynamic> toJson() {
    return {
      'score': _score,
      'level': _level,
      'grade': _grade,
      'lives': _lives,
      'soundEnabled': _soundEnabled,
      'musicEnabled': _musicEnabled,
      'gameProgress': _gameProgress,
      'bestStars': _bestStars,
      'achievements': _achievements.map((a) => a.toJson()).toList(),
      'useAdaptiveDifficulty': _useAdaptiveDifficulty,
      'difficultyMode': _difficultyMode.index,
      'isFullVersionUnlocked': _isFullVersionUnlocked,
      'multiplicationSymbol': _multiplicationSymbol,
      'divisionSymbol': _divisionSymbol,
      
      'useCustomProblemSettings': _useCustomProblemSettings,
      'customOperations': _customOperations.toList(), // Convert set to list for JSON
      'customRangeMin': _customRangeMin,
      'customRangeMax': _customRangeMax,
      'currentLevelWins': _currentLevelWins,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    _score = json['score'] ?? 0;
    _level = json['level'] ?? 1;
    _grade = json['grade'] ?? 1; // Default is 1
    _lives = json['lives'] ?? 3;
    _soundEnabled = json['soundEnabled'] ?? true;
    _musicEnabled = json['musicEnabled'] ?? true;
    _gameProgress = Map<String, int>.from(json['gameProgress'] ?? {});
    _bestStars = Map<String, int>.from(json['bestStars'] ?? {});
    _useAdaptiveDifficulty = json['useAdaptiveDifficulty'] ?? false;
    final modeIndex = json['difficultyMode'] as int? ??
        DifficultyMode.normal.index;
    _difficultyMode = DifficultyMode.values[
        modeIndex.clamp(0, DifficultyMode.values.length - 1)];
    _isFullVersionUnlocked = json['isFullVersionUnlocked'] ?? false;

    // overridhere to handle loading a saved state where the user hadn't purchased the app yet.
    if (!AppConfig.inappsActive) {
      _isFullVersionUnlocked = true;
    }

    _multiplicationSymbol = json['multiplicationSymbol'] ?? '×';
    _divisionSymbol = json['divisionSymbol'] ?? '÷';

    // --- Load custom settings ---
    _useCustomProblemSettings = json['useCustomProblemSettings'] ?? false;
    _customOperations = Set<String>.from(json['customOperations'] ?? {'addition', 'subtraction'});
    _customRangeMin = json['customRangeMin'] ?? 1;
    _customRangeMax = json['customRangeMax'] ?? 20;

    if (json['achievements'] != null) {
      _achievements = (json['achievements'] as List)
          .map((a) => Achievement.fromJson(a))
          .toList();
    }

    _currentLevelWins = Map<String, int>.from(json['currentLevelWins'] ?? {});
    
    notifyListeners();
  }
}