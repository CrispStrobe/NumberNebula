import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_preferences.dart';

class PlayerProfile {
  final String id;
  final String name;
  const PlayerProfile(this.id, this.name);
}

class PlayerProfileService extends ChangeNotifier {
  static const _key = 'players_v1';
  static const _activeKey = 'active_player_v1';
  List<PlayerProfile> _players = [const PlayerProfile('default', '')];
  bool _busy = false;
  Future<void> Function(String id)? onSwitch;
  List<PlayerProfile> get players => List.unmodifiable(_players);
  PlayerProfile get active =>
      _players.firstWhere((p) => p.id == ProfilePreferences.activeId);
  bool get busy => _busy;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_key);
      if (raw != null) {
        final entries = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        final ids = <String>{};
        final players = entries
            .map((e) => PlayerProfile(e['id'] as String, e['name'] as String))
            .where((p) =>
                RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(p.id) && ids.add(p.id))
            .toList();
        if (players.any((p) => p.id == 'default')) _players = players;
      }
    } catch (_) {/* Retain the legacy player if metadata is damaged. */}
    final saved = prefs.getString(_activeKey);
    ProfilePreferences.activeId =
        _players.any((p) => p.id == saved) ? saved! : 'default';
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key,
        jsonEncode(_players.map((p) => {'id': p.id, 'name': p.name}).toList()));
    await prefs.setString(_activeKey, ProfilePreferences.activeId);
  }

  Future<void> rename(String id, String name) async {
    if (_busy || name.trim().isEmpty) return;
    _players = _players
        .map((p) => p.id == id ? PlayerProfile(id, name.trim()) : p)
        .toList();
    await _save();
    notifyListeners();
  }

  Future<void> add(String name) async {
    if (_busy || name.trim().isEmpty) return;
    var id = DateTime.now().microsecondsSinceEpoch.toString();
    while (_players.any((p) => p.id == id)) {
      id = '${id}_1';
    }
    _players.add(PlayerProfile(id, name.trim()));
    await _save();
    notifyListeners();
  }

  Future<void> activate(String id) async {
    if (_busy || id == active.id || !_players.any((p) => p.id == id)) return;
    final switchPlayer = onSwitch;
    if (switchPlayer == null) return;
    _busy = true;
    notifyListeners();
    try {
      await switchPlayer(id);
      await _save();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
