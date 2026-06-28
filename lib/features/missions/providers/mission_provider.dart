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
  Future<void> startMission({
    required int grade,
    required int level,
    required String locale,
  }) async {
    final mission = _generator.generate(
      grade: grade,
      level: level,
      locale: locale,
    );
    _state = MissionState(mission: mission);
    await _persistence.save(_state!);
    notifyListeners();
  }

  /// Mark the current task as completed after a game win.
  Future<void> completeTask(int index) async {
    if (_state == null) return;
    if (index < 0 || index >= _state!.mission.tasks.length) return;
    _state!.mission.tasks[index].completed = true;
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
