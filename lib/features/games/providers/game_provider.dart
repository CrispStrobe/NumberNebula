import 'package:flutter/foundation.dart';

class GameProvider extends ChangeNotifier {
  int _score = 0;
  int _level = 1;
  int _grade = 3;
  int _lives = 3;
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  Map<String, int> _gameProgress = {};
  List<Achievement> _achievements = [];
  
  // Getters
  int get score => _score;
  int get level => _level;
  int get grade => _grade;
  int get lives => _lives;
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  Map<String, int> get gameProgress => _gameProgress;
  List<Achievement> get achievements => _achievements;
  
  // Score management
  void addScore(int points) {
    _score += points;
    _checkAchievements();
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
    
    // Score-based achievements
    if (_score >= 100 && !hasAchievement('first_century')) {
      newAchievements.add(Achievement(
        id: 'first_century',
        title: 'First Century!',
        description: 'Scored 100 points',
        icon: '💯',
        isUnlocked: true,
      ));
    }
    
    if (_score >= 500 && !hasAchievement('score_master')) {
      newAchievements.add(Achievement(
        id: 'score_master',
        title: 'Score Master',
        description: 'Scored 500 points',
        icon: '⭐',
        isUnlocked: true,
      ));
    }
    
    if (_score >= 1000 && !hasAchievement('thousand_club')) {
      newAchievements.add(Achievement(
        id: 'thousand_club',
        title: 'Thousand Club',
        description: 'Scored 1000 points',
        icon: '🚀',
        isUnlocked: true,
      ));
    }
    
    // Level-based achievements
    if (_level >= 5 && !hasAchievement('level_explorer')) {
      newAchievements.add(Achievement(
        id: 'level_explorer',
        title: 'Level Explorer',
        description: 'Reached level 5',
        icon: '🌟',
        isUnlocked: true,
      ));
    }
    
    if (_level >= 10 && !hasAchievement('space_commander')) {
      newAchievements.add(Achievement(
        id: 'space_commander',
        title: 'Space Commander',
        description: 'Reached level 10',
        icon: '👨‍🚀',
        isUnlocked: true,
      ));
    }
    
    // Game-specific achievements
    if (getGameProgress('magic_triangles') >= 3 && !hasAchievement('triangle_wizard')) {
      newAchievements.add(Achievement(
        id: 'triangle_wizard',
        title: 'Triangle Wizard',
        description: 'Completed 3 Magic Triangle levels',
        icon: '🔺',
        isUnlocked: true,
      ));
    }
    
    if (getGameProgress('bubble_math') >= 3 && !hasAchievement('bubble_popper')) {
      newAchievements.add(Achievement(
        id: 'bubble_popper',
        title: 'Bubble Popper',
        description: 'Completed 3 Bubble Math levels',
        icon: '🫧',
        isUnlocked: true,
      ));
    }
    
    if (getGameProgress('puzzle_math') >= 3 && !hasAchievement('puzzle_solver')) {
      newAchievements.add(Achievement(
        id: 'puzzle_solver',
        title: 'Puzzle Solver',
        description: 'Completed 3 Puzzle Math levels',
        icon: '🧩',
        isUnlocked: true,
      ));
    }
    
    // Multi-game achievements
    final gamesCompleted = _gameProgress.values.where((level) => level >= 1).length;
    if (gamesCompleted >= 3 && !hasAchievement('all_rounder')) {
      newAchievements.add(Achievement(
        id: 'all_rounder',
        title: 'All-Rounder',
        description: 'Played all game types',
        icon: '🎯',
        isUnlocked: true,
      ));
    }
    
    // Add new achievements
    for (final achievement in newAchievements) {
      _achievements.add(achievement);
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
    notifyListeners();
  }
  
  void startNewGame(String gameType) {
    _score = 0;
    _lives = 3;
    notifyListeners();
  }
  
  // Statistics
  int get totalGamesPlayed {
    return _gameProgress.values.fold(0, (sum, level) => sum + level);
  }
  
  int get totalAchievements => _achievements.length;
  
  double get averageLevel {
    if (_gameProgress.isEmpty) return 0.0;
    final totalLevels = _gameProgress.values.fold(0, (sum, level) => sum + level);
    return totalLevels / _gameProgress.length;
  }
  
  // Grade progression
  bool canProgressToNextGrade() {
    // Check if player has completed enough levels in current grade
    final totalLevelsInGrade = _gameProgress.values.fold(0, (sum, level) => sum + level);
    final requiredLevels = _grade * 3; // 3 levels per game type per grade
    return totalLevelsInGrade >= requiredLevels;
  }
  
  void progressToNextGrade() {
    if (canProgressToNextGrade() && _grade < 6) {
      _grade++;
      _level = 1;
      // Reset game progress for new grade
      _gameProgress.clear();
      
      // Add grade progression achievement
      if (!hasAchievement('grade_${_grade}')) {
        _achievements.add(Achievement(
          id: 'grade_${_grade}',
          title: 'Grade ${_grade} Graduate!',
          description: 'Advanced to grade ${_grade}',
          icon: '🎓',
          isUnlocked: true,
        ));
      }
      
      notifyListeners();
    }
  }
  
  // Save/Load functionality (for persistence)
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

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  
  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    this.unlockedAt,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.toIso8601String(),
    };
  }
  
  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      icon: json['icon'],
      isUnlocked: json['isUnlocked'],
      unlockedAt: json['unlockedAt'] != null 
          ? DateTime.parse(json['unlockedAt'])
          : null,
    );
  }
}

// Service classes for audio and progress
class AudioService {
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }
  
  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
  }
  
  void playSound(String soundFile) {
    if (_soundEnabled) {
      // Implement sound playing using audioplayers package
      // AudioPlayer().play(AssetSource('sounds/$soundFile'));
    }
  }
  
  void playBackgroundMusic() {
    if (_musicEnabled) {
      // Implement background music
    }
  }
  
  void stopBackgroundMusic() {
    // Implement stop background music
  }
}

class ProgressService {
  Future<void> init() async {
    // Initialize shared preferences for data persistence
  }
  
  Future<void> saveProgress(GameProvider gameProvider) async {
    // Save game progress to shared preferences
    final data = gameProvider.toJson();
    // Implementation with shared_preferences
  }
  
  Future<void> loadProgress(GameProvider gameProvider) async {
    // Load game progress from shared preferences
    // Implementation with shared_preferences
  }
}