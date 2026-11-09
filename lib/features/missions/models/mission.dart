// lib/features/missions/models/mission.dart
//
// Data models for the Mission Streak feature.

import '../../games/models/performance.dart';

/// A single task within a mission — play one mini-game to earn letters.
class MissionTask {
  final String gameType; // gameKey matching game_menu_screen
  final int grade;
  final int level;

  /// Letters revealed when this task is cleared. Long codewords hand out more
  /// than one letter per task so a mission stays a handful of games.
  final String letters;

  bool completed;

  /// Best 0..1 quality ratio the player has achieved on this task, or null if
  /// they have never finished a round. This is what the task tile grades:
  /// >=85% green, >70% yellow, >40% orange, below red.
  double? bestPerformance;

  /// Number of rounds played on this task, cleared or not.
  int attempts;

  MissionTask({
    required this.gameType,
    required this.grade,
    required this.level,
    required this.letters,
    this.completed = false,
    this.bestPerformance,
    this.attempts = 0,
  });

  /// Grade bucket of [bestPerformance], or null if never played.
  PerfGrade? get performanceGrade =>
      bestPerformance == null ? null : gradeForPerformance(bestPerformance!);

  /// Record the result of one round; keeps the best performance seen.
  void recordAttempt({required bool cleared, required double performance}) {
    attempts++;
    if (bestPerformance == null || performance > bestPerformance!) {
      bestPerformance = performance;
    }
    if (cleared) completed = true;
  }

  Map<String, dynamic> toJson() => {
        'gameType': gameType,
        'grade': grade,
        'level': level,
        'letters': letters,
        'completed': completed,
        'bestPerformance': bestPerformance,
        'attempts': attempts,
      };

  factory MissionTask.fromJson(Map<String, dynamic> json) => MissionTask(
        gameType: json['gameType'] as String,
        grade: json['grade'] as int,
        level: json['level'] as int,
        // 'letter' is the pre-multi-letter field name; keep reading it so a
        // mission saved by an older build survives the upgrade.
        letters: (json['letters'] ?? json['letter'] ?? '') as String,
        completed: json['completed'] as bool? ?? false,
        bestPerformance: (json['bestPerformance'] as num?)?.toDouble(),
        attempts: json['attempts'] as int? ?? 0,
      );
}

/// A complete mission: a sequence of tasks whose letters form a codeword.
class Mission {
  final String id;
  final List<MissionTask> tasks;
  final String codeword; // target word
  final int grade;
  final int level;

  const Mission({
    required this.id,
    required this.tasks,
    required this.codeword,
    required this.grade,
    required this.level,
  });

  int get completedCount => tasks.where((t) => t.completed).length;
  bool get allTasksDone => tasks.every((t) => t.completed);

  /// Average quality across cleared tasks, or null before the first clear.
  /// This is the mission's own grade — the number shown on the summary.
  double? get averagePerformance {
    final scored = tasks
        .where((t) => t.completed && t.bestPerformance != null)
        .map((t) => t.bestPerformance!)
        .toList();
    if (scored.isEmpty) return null;
    return scored.reduce((a, b) => a + b) / scored.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'codeword': codeword,
        'grade': grade,
        'level': level,
      };

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
        id: json['id'] as String,
        tasks: (json['tasks'] as List)
            .map((t) => MissionTask.fromJson(t as Map<String, dynamic>))
            .toList(),
        codeword: json['codeword'] as String,
        grade: json['grade'] as int,
        level: json['level'] as int,
      );
}

/// Runtime state of an active mission.
class MissionState {
  final Mission mission;
  bool codewordSolved;

  MissionState({
    required this.mission,
    this.codewordSolved = false,
  });

  /// Letters earned so far (in task order).
  List<String> get earnedLetters => mission.tasks
      .where((t) => t.completed)
      .expand((t) => t.letters.split(''))
      .toList();

  /// Index of the next uncompleted task, or -1 if all done.
  int get nextTaskIndex {
    for (int i = 0; i < mission.tasks.length; i++) {
      if (!mission.tasks[i].completed) return i;
    }
    return -1;
  }

  Map<String, dynamic> toJson() => {
        'mission': mission.toJson(),
        'codewordSolved': codewordSolved,
      };

  factory MissionState.fromJson(Map<String, dynamic> json) => MissionState(
        mission:
            Mission.fromJson(json['mission'] as Map<String, dynamic>),
        codewordSolved: json['codewordSolved'] as bool? ?? false,
      );
}
