// lib/features/missions/models/mission.dart
//
// Data models for the Mission Streak feature.

/// A single task within a mission — play one mini-game to earn a letter.
class MissionTask {
  final String gameType; // gameKey matching game_menu_screen
  final int grade;
  final int level;
  final String letter; // letter earned on completion
  bool completed;

  MissionTask({
    required this.gameType,
    required this.grade,
    required this.level,
    required this.letter,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
        'gameType': gameType,
        'grade': grade,
        'level': level,
        'letter': letter,
        'completed': completed,
      };

  factory MissionTask.fromJson(Map<String, dynamic> json) => MissionTask(
        gameType: json['gameType'] as String,
        grade: json['grade'] as int,
        level: json['level'] as int,
        letter: json['letter'] as String,
        completed: json['completed'] as bool? ?? false,
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
      .map((t) => t.letter)
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
