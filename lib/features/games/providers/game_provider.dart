import 'package:flutter/foundation.dart';

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
  int _score = 0;
  int _level = 1;
  int _grade = 3;
  int _lives = 3;
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _puzzleTimerEnabled = true;
  Map<String, int> _gameProgress = {};
  List<Achievement> _achievements = [];

  // Getters
  int get score => _score;
  int get level => _level;
  int get grade => _grade;
  int get lives => _lives;
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get puzzleTimerEnabled => _puzzleTimerEnabled;
  Map<String, int> get gameProgress => _gameProgress;
  List<Achievement> get achievements => _achievements;

  // Score management
  void addScore(int points) {
    _score += points;
    _checkAchievements();
    notifyListeners();
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
  }

  void setLevel(int level) {
    _level = level;
    notifyListeners();
  }

  void setDifficulty(int newGrade, int newLevel) {
    _grade = newGrade;
    _level = newLevel;
    notifyListeners();
  }

  // Grade management
  void setGrade(int grade) {
    _grade = grade;
    _level = 1; // Reset level when changing grade
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
    };
  }

  void fromJson(Map<String, dynamic> json) {
    _score = json['score'] ?? 0;
    _level = json['level'] ?? 1;
    _grade = json['grade'] ?? 3;
    _lives = json['lives'] ?? 3;
    _soundEnabled = json['soundEnabled'] ?? true;
    _musicEnabled = json['musicEnabled'] ?? true;
    _gameProgress = Map<String, int>.from(json['gameProgress'] ?? {});

    if (json['achievements'] != null) {
      _achievements = (json['achievements'] as List)
          .map((a) => Achievement.fromJson(a))
          .toList();
    }
    
    notifyListeners();
  }
}