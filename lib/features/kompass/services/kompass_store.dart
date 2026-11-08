import 'dart:async';
import 'dart:convert';

import '../../../core/services/profile_preferences.dart';
import '../models/kompass_attempt.dart';
import '../models/kompass_content.dart';

class _StoredProgress {
  final List<KompassAttempt> attempts;
  Map<String, dynamic>? session;
  final Map<String, String> exposures;
  final Set<String> closedSessions;

  _StoredProgress(
      this.attempts, this.session, this.exposures, this.closedSessions);
  factory _StoredProgress.empty() => _StoredProgress([], null, {}, {});

  factory _StoredProgress.decode(String? raw) {
    if (raw == null) return _StoredProgress.empty();
    final json = kompassMap(jsonDecode(raw));
    if (json['schemaVersion'] != 1 || json['attempts'] is! List) {
      throw const FormatException('Unsupported saved progress format.');
    }
    final attempts = [
      for (final attempt in json['attempts'] as List)
        KompassAttempt.fromJson(kompassMap(attempt)),
    ];
    if (attempts.map((a) => a.id).toSet().length != attempts.length) {
      throw const FormatException('Saved attempts have duplicate identities.');
    }
    final session = json['session'] == null
        ? null
        : kompassFreezeJson(kompassMap(json['session']))
            as Map<String, dynamic>;
    if (session != null) KompassStore._sessionId(session);
    return _StoredProgress(
      attempts,
      session,
      Map<String, String>.from(json['exposures'] as Map? ?? const {}),
      (json['closedSessions'] as List? ?? const []).cast<String>().toSet(),
    );
  }

  String encode() => jsonEncode({
        'schemaVersion': 1,
        'attempts': attempts.map((attempt) => attempt.toJson()).toList(),
        'session': session,
        'exposures': exposures,
        'closedSessions': closedSessions.toList(),
      });
}

/// One captured player's durable records. No account, network or analytics.
/// Writes are serialized across instances, then merged with the latest state.
class KompassStore {
  static const storageKey = 'kompass_learning_v1';
  static final Map<String, Future<void>> _writes = {};
  final ProfilePreferences _prefs;
  _StoredProgress _state = _StoredProgress.empty();
  String? _corruptionError;

  KompassStore._(this._prefs);

  String get profileId => _prefs.profileId;
  List<KompassAttempt> get attempts => List.unmodifiable(_state.attempts);
  Map<String, dynamic>? get session => _state.session;
  Set<String> get exposedFamilies => Set.unmodifiable(_state.exposures.keys);
  String? get corruptionError => _corruptionError;

  /// ProfilePreferences captures the current player before its first await.
  static Future<KompassStore> open() async {
    final pendingPreferences = ProfilePreferences.getInstance();
    final preferences = await pendingPreferences;
    await (_writes[preferences.profileId] ?? Future<void>.value());
    final store = KompassStore._(preferences);
    store._read();
    return store;
  }

  void _read() {
    try {
      _state = _StoredProgress.decode(_prefs.getString(storageKey));
      _corruptionError = null;
    } catch (_) {
      // Keep the original bytes intact. Only explicit recovery can replace them.
      _corruptionError = 'Saved learning data could not be read.';
      _state = _StoredProgress.empty();
    }
  }

  Future<void> reload() async {
    await (_writes[profileId] ?? Future<void>.value());
    _read();
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final previous = _writes[profileId] ?? Future<void>.value();
    final operation = previous.then((_) => action());
    _writes[profileId] =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<bool> _mutate(bool Function(_StoredProgress) operation) =>
      _enqueue(() async {
        _StoredProgress current;
        try {
          current = _StoredProgress.decode(_prefs.getString(storageKey));
        } catch (_) {
          _corruptionError = 'Saved learning data could not be read.';
          throw StateError(
              'Restore or explicitly reset unreadable learning data before saving.');
        }
        final changed = operation(current);
        if (changed && !await _prefs.setString(storageKey, current.encode())) {
          throw StateError('Learning progress could not be saved.');
        }
        _state = current;
        _corruptionError = null;
        return changed;
      });

  /// Returns false for an already recorded completion; never awards it twice.
  Future<bool> record(KompassAttempt attempt) => _mutate((state) {
        for (final saved in state.attempts) {
          if (saved.id != attempt.id) continue;
          if (saved.taskId != attempt.taskId ||
              saved.familyId != attempt.familyId) {
            throw ArgumentError('Attempt ID already belongs to another task.');
          }
          return false;
        }
        final exposedBy = state.exposures[attempt.familyId];
        final novel = attempt.isNovel &&
            !state.attempts.any((a) => a.familyId == attempt.familyId) &&
            (exposedBy == null || exposedBy == attempt.sessionId);
        state.attempts.add(
            attempt.copyWith(isNovel: novel, updatedAt: attempt.updatedAt));
        state.exposures.putIfAbsent(attempt.familyId, () => attempt.sessionId);
        return true;
      });

  /// Only final responses/review/support/time may change. First evidence is fixed.
  Future<bool> revise(KompassAttempt revised) => _mutate((state) {
        final index = state.attempts.indexWhere((a) => a.id == revised.id);
        if (index < 0) {
          throw ArgumentError('Record an attempt before revising it.');
        }
        final saved = state.attempts[index];
        final immutable = <String>[
          'id',
          'sessionId',
          'taskId',
          'taskVersion',
          'packVersion',
          'familyId',
          'domain',
          'mode',
          'contentUse',
          'firstResponses',
          'firstScore',
          'hintsBeforeFirstResponse',
          'solutionSeenBeforeFirstResponse',
          'at',
        ];
        final oldJson = saved.toJson();
        final newJson = revised.toJson();
        if (immutable.any((key) => !_deepEqual(oldJson[key], newJson[key]))) {
          throw ArgumentError(
              'A revision cannot replace first-attempt evidence.');
        }
        if (revised.hintsUsed < saved.hintsUsed ||
            revised.activeSeconds < saved.activeSeconds ||
            (saved.completed && !revised.completed)) {
          throw ArgumentError(
              'A revision cannot erase support, elapsed work or completion.');
        }
        state.attempts[index] = revised.copyWith(isNovel: saved.isNovel);
        return true;
      });

  /// An abandoned check is still exposed. Reopening the same saved session is OK.
  Future<bool> markExposed(String familyId, {required String sessionId}) {
    if (familyId.isEmpty || sessionId.isEmpty) {
      throw ArgumentError('Exposure needs a family and session identity.');
    }
    return _mutate((state) {
      if (state.exposures.containsKey(familyId)) return false;
      state.exposures[familyId] = sessionId;
      return true;
    });
  }

  /// Snapshots immediately. Old callbacks cannot resurrect a completed session.
  Future<bool> saveSession(Map<String, dynamic> session,
      {bool replace = false}) {
    final snapshot = kompassFreezeJson(session) as Map<String, dynamic>;
    final id = _sessionId(snapshot);
    return _mutate((state) {
      if (state.closedSessions.contains(id)) return false;
      final old = state.session;
      if (old != null && _sessionId(old) != id) {
        if (!replace) {
          throw StateError('Another learning session is already saved.');
        }
        state.closedSessions.add(_sessionId(old));
      }
      // A caller can persist a revision counter to ignore older async snapshots.
      if (old != null &&
          _sessionId(old) == id &&
          (old['revision'] is int) &&
          (snapshot['revision'] is int) &&
          (old['revision'] as int) > (snapshot['revision'] as int)) {
        return false;
      }
      state.session = snapshot;
      return true;
    });
  }

  /// Supplying an ID protects a newer session from an old completion callback.
  Future<bool> clearSession({String? sessionId}) => _mutate((state) {
        final current = state.session;
        if (sessionId != null) {
          final added = state.closedSessions.add(sessionId);
          if (current != null && _sessionId(current) == sessionId) {
            state.session = null;
            return true;
          }
          return added;
        }
        if (current == null) return false;
        state.closedSessions.add(_sessionId(current));
        state.session = null;
        return true;
      });

  /// User-initiated recovery preserves the unreadable bytes before starting over.
  Future<void> resetAfterCorruption() => _enqueue(() async {
        final raw = _prefs.getString(storageKey);
        if (_corruptionError == null) {
          throw StateError('There is no unreadable progress to reset.');
        }
        // A second instance may have repaired the data while this UI was open.
        // Never replace that newer, valid progress with an empty snapshot.
        _StoredProgress? repaired;
        try {
          repaired = _StoredProgress.decode(raw);
        } catch (_) {
          // The current bytes are still unreadable; preserve them below.
        }
        if (repaired != null) {
          _state = repaired;
          _corruptionError = null;
          throw StateError('Progress has already been restored. Reload it.');
        }
        if (raw != null) {
          final key =
              '${storageKey}_recovery_${DateTime.now().microsecondsSinceEpoch}';
          if (!await _prefs.setString(key, raw)) {
            throw StateError('Original data could not be preserved.');
          }
        }
        final empty = _StoredProgress.empty();
        if (!await _prefs.setString(storageKey, empty.encode())) {
          throw StateError('Learning progress could not be reset.');
        }
        _state = empty;
        _corruptionError = null;
      });

  Future<void> flush() => _writes[profileId] ?? Future<void>.value();

  static String _sessionId(Map<String, dynamic> session) {
    final id = session['id'] ?? session['sessionId'];
    if (id is! String || id.isEmpty) {
      throw ArgumentError('A saved session needs a nonempty id.');
    }
    return id;
  }

  static bool _deepEqual(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys
              .every((key) => b.containsKey(key) && _deepEqual(a[key], b[key]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(a.length, (i) => _deepEqual(a[i], b[i]))
              .every((v) => v);
    }
    return a == b;
  }
}
