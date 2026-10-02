import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'profile_preferences.dart';

/// One record per game. Burst writes are coalesced, while reads, clears and
/// lifecycle flushes retain transaction order and the initiating player.
class PuzzleSessionStore {
  static PuzzleSessionStore _instance = PuzzleSessionStore();
  static PuzzleSessionStore get instance => _instance;
  @visibleForTesting
  static void resetForTesting() => _instance = PuzzleSessionStore();
  static const _legacyKey = 'puzzle_sessions_v1';
  static const _prefix = 'puzzle_session_v2_';
  @visibleForTesting
  int recordWriteCount = 0;
  Future<void>? _pending;
  Timer? _batchTimer;
  final _batch = <String, _SessionWrite>{};

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _pending?.then((_) => action()) ?? Future<T>.sync(action);
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Map<String, dynamic> _legacy(ProfilePreferences prefs) {
    try {
      return Map<String, dynamic>.from(
          jsonDecode(prefs.getString(_legacyKey) ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic>? _decode(String? value) {
    try {
      final record = Map<String, dynamic>.from(jsonDecode(value ?? '') as Map);
      return record['schema'] == 1 &&
              record['game'] is String &&
              record['grade'] is int &&
              record['level'] is int &&
              record['state'] is Map
          ? record
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(
          String game, int grade, int level, Map<String, dynamic> state) =>
      saveEncoded(game, grade, level, jsonEncode(state));

  /// The caller already encoded the board for change detection. Reuse it.
  Future<void> saveEncoded(String game, int grade, int level, String state) {
    final player = ProfilePreferences.activeId;
    final preferences = ProfilePreferences.getInstance();
    final header = jsonEncode({
      'schema': 1,
      'game': game,
      'grade': grade,
      'level': level,
      'updatedAt': DateTime.now().toIso8601String()
    });
    final record = '${header.substring(0, header.length - 1)},"state":$state}';
    final completion = Completer<void>();
    final key = '$player/$game';
    final previous = _batch[key];
    _batch[key] = _SessionWrite(
        preferences, game, record, [...?previous?.completions, completion]);
    _batchTimer ??= Timer(const Duration(milliseconds: 100), flush);
    return completion.future;
  }

  /// Enqueues the pending batch immediately, before a subsequent read/clear.
  Future<void> flush() {
    _batchTimer?.cancel();
    _batchTimer = null;
    if (_batch.isEmpty) return _pending ?? Future<void>.value();
    final writes = _batch.values.toList();
    _batch.clear();
    return _enqueue(() async {
      for (final write in writes) {
        try {
          final prefs = await write.preferences;
          if (!await prefs.setString('$_prefix${write.game}', write.record)) {
            throw StateError('Puzzle save failed');
          }
          recordWriteCount++;
          for (final completion in write.completions) {
            completion.complete();
          }
        } catch (error, stack) {
          for (final completion in write.completions) {
            completion.completeError(error, stack);
          }
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> list() {
    final preferences = ProfilePreferences.getInstance();
    unawaited(flush());
    return _enqueue(() async {
      final prefs = await preferences;
      final sessions = _legacy(prefs);
      for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
        final record = _decode(prefs.getString(key));
        if (record != null) sessions[record['game'] as String] = record;
      }
      return sessions.values
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .where((s) => _decode(jsonEncode(s)) != null)
          .toList()
        ..sort((a, b) => (b['updatedAt'] as String? ?? '')
            .compareTo(a['updatedAt'] as String? ?? ''));
    });
  }

  Future<Map<String, dynamic>?> load(String game, int grade, int level) {
    final preferences = ProfilePreferences.getInstance();
    unawaited(flush());
    return _enqueue(() async {
      final prefs = await preferences;
      final record = _decode(prefs.getString('$_prefix$game')) ??
          _decode(jsonEncode(_legacy(prefs)[game]));
      if (record == null ||
          record['grade'] != grade ||
          record['level'] != level) {
        return null;
      }
      return Map<String, dynamic>.from(record['state'] as Map);
    });
  }

  Future<void> clear(String game) {
    final player = ProfilePreferences.activeId;
    final preferences = ProfilePreferences.getInstance();
    final discarded = _batch.remove('$player/$game');
    for (final completion in discarded?.completions ?? <Completer<void>>[]) {
      completion.complete();
    }
    unawaited(flush());
    return _enqueue(() async {
      final prefs = await preferences;
      await prefs.remove('$_prefix$game');
      final legacy = _legacy(prefs);
      if (legacy.remove(game) != null) {
        await prefs.setString(_legacyKey, jsonEncode(legacy));
      }
    });
  }
}

class _SessionWrite {
  final Future<ProfilePreferences> preferences;
  final String game;
  final String record;
  final List<Completer<void>> completions;
  const _SessionWrite(
      this.preferences, this.game, this.record, this.completions);
}
