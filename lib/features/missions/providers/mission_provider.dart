// lib/features/missions/providers/mission_provider.dart
//
// ChangeNotifier managing the active mission lifecycle.

import 'package:flutter/foundation.dart';

import '../models/mission.dart';
import '../services/mission_generator.dart';
import '../services/mission_persistence.dart';

class MissionProvider extends ChangeNotifier {
  final MissionPersistence _persistence = MissionPersistence();
  final MissionGenerator _generator = MissionGenerator();

  MissionState? _state;

  MissionState? get state => _state;
  bool get hasActiveMission => _state != null && !_state!.codewordSolved;

  /// Load a previously saved mission (call on app start).
  Future<void> loadSaved() async {
    _state = await _persistence.load();
    // Discard completed missions
    if (_state?.codewordSolved == true) {
      _state = null;
      await _persistence.clear();
    }
    notifyListeners();
  }

  /// Start a new mission for the given grade/level/locale.
  ///
  /// [gameProgress] lets each task run at the level the player has reached in
  /// that particular game.
  Future<void> startMission({
    required int grade,
    required int level,
    required String locale,
    Map<String, int>? gameProgress,
  }) async {
    final mission = _generator.generate(
      grade: grade,
      level: level,
      locale: locale,
      gameProgress: gameProgress,
    );
    _state = MissionState(mission: mission);
    await _persistence.save(_state!);
    notifyListeners();
  }

  /// Record the result of a played round on task [index].
  ///
  /// [cleared] marks the task done (letters earned); [performance] is the
  /// normalized 0..1 quality of the round, which the task tile grades. Best
  /// performance wins, so replaying a task can only improve the grade.
  Future<void> recordTaskAttempt(
    int index, {
    required bool cleared,
    required double performance,
  }) async {
    if (_state == null) return;
    if (index < 0 || index >= _state!.mission.tasks.length) return;
    _state!.mission.tasks[index]
        .recordAttempt(cleared: cleared, performance: performance);
    await _persistence.save(_state!);
    notifyListeners();
  }

  /// Mark the codeword as solved.
  Future<void> solveCodeword() async {
    if (_state == null) return;
    _state!.codewordSolved = true;
    await _persistence.save(_state!);
    notifyListeners();
  }

  /// Abandon the current mission.
  Future<void> abandonMission() async {
    _state = null;
    await _persistence.clear();
    notifyListeners();
  }
}
