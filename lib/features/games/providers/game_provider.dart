// lib/features/games/providers/game_provider.dart
import 'package:flutter/foundation.dart';
import '../../../core/services/progress_service.dart';

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
  int _score = 0;
  int _level = 1;
  int _grade = 1;
  int _lives = 3;
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _puzzleTimerEnabled = true;
  bool _useAdaptiveDifficulty = false;
  Map<String, int> _gameProgress = {};
  List<Achievement> _achievements = [];
  bool _isFullVersionUnlocked = false;

  bool _useCustomProblemSettings = false;
  Set<String> _customOperations = {'addition', 'subtraction'}; // Default to basic ops
  int _customRangeMin = 1;
  int _customRangeMax = 20;

  GameProvider({required ProgressService progressService})
      : _progressService = progressService;

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

  // Getters
  int get score => _score;
  int get level => _level;
  int get grade => _grade; // Internally, we'll still call this 'grade'
  int get lives => _lives;
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get puzzleTimerEnabled => _puzzleTimerEnabled;
  
  bool get useAdaptiveDifficulty => _useAdaptiveDifficulty;

  Map<String, int> get gameProgress => _gameProgress;
  List<Achievement> get achievements => _achievements;

  bool get useCustomProblemSettings => _useCustomProblemSettings;
  Set<String> get customOperations => _customOperations;
  int get customRangeMin => _customRangeMin;
  int get customRangeMax => _customRangeMax;

  Future<void> _saveProgress() async {
    // This is a "fire and forget" call. We don't need to wait for it.
    _progressService.saveProgress(this);
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
    if (getGameProgress('bubble_math') >= 3 && !hasAchievement('bubble_popper')) { newAchievements.add(Achievement(id: 'bubble_popper')); }
    if (getGameProgress('puzzle_math') >= 3 && !hasAchievement('puzzle_solver')) { newAchievements.add(Achievement(id: 'puzzle_solver')); }
    if (getGameProgress('number_walls') >= 3 && !hasAchievement('number_walls_pro')) { newAchievements.add(Achievement(id: 'number_walls_pro')); }
    if (getGameProgress('codebreaker') >= 3 && !hasAchievement('codebreaker_pro')) { newAchievements.add(Achievement(id: 'codebreaker_pro')); }

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
      'achievements': _achievements.map((a) => a.toJson()).toList(),
      'useAdaptiveDifficulty': _useAdaptiveDifficulty,
      'isFullVersionUnlocked': _isFullVersionUnlocked,
      
      'useCustomProblemSettings': _useCustomProblemSettings,
      'customOperations': _customOperations.toList(), // Convert set to list for JSON
      'customRangeMin': _customRangeMin,
      'customRangeMax': _customRangeMax,
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
    _useAdaptiveDifficulty = json['useAdaptiveDifficulty'] ?? false;
    _isFullVersionUnlocked = json['isFullVersionUnlocked'] ?? false;

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
    
    notifyListeners();
  }
}