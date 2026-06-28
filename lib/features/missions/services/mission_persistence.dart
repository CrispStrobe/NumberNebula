// lib/features/missions/services/mission_persistence.dart
//
// Persists the active mission state to SharedPreferences.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mission.dart';

class MissionPersistence {
  static const _key = 'mission_active_v1';

  Future<MissionState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return null;
    try {
      return MissionState.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(MissionState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
