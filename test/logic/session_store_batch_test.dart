import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'default';
    PuzzleSessionStore.resetForTesting();
  });
  test('a burst writes the latest board once and resolves every caller',
      () async {
    final store = PuzzleSessionStore.instance;
    final writes = [
      for (int i = 0; i < 50; i++) store.save('star_forge', 1, 2, {'moves': i})
    ];
    await store.flush();
    await Future.wait(writes);
    expect(await store.load('star_forge', 1, 2), {'moves': 49});
    expect(store.recordWriteCount, 1);
  });
  test('saving one game does not rewrite another game or legacy records',
      () async {
    final store = PuzzleSessionStore.instance;
    final legacy = jsonEncode({
      'kenken': {
        'schema': 1,
        'game': 'kenken',
        'grade': 1,
        'level': 1,
        'state': {'moves': 3},
        'updatedAt': '2026-01-01'
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('puzzle_sessions_v1', legacy);
    final saved = store.save('star_forge', 1, 2, {'moves': 1});
    await store.flush();
    await saved;
    expect(prefs.getString('puzzle_sessions_v1'), legacy);
    expect(await store.load('kenken', 1, 1), {'moves': 3});
    expect((await store.list()).map((e) => e['game']),
        containsAll(['star_forge', 'kenken']));
  });
  test('clear discards a pending save and removes both record versions',
      () async {
    final store = PuzzleSessionStore.instance;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'puzzle_sessions_v1',
        jsonEncode({
          'kenken': {
            'schema': 1,
            'game': 'kenken',
            'grade': 1,
            'level': 1,
            'state': {'moves': 3}
          }
        }));
    final saved = store.save('kenken', 1, 1, {'moves': 4});
    await store.clear('kenken');
    await saved;
    await store.flush();
    expect(await store.load('kenken', 1, 1), isNull);
    expect(store.recordWriteCount, 0);
  });
  test('an in-flight batch stays with the initiating player', () async {
    final store = PuzzleSessionStore.instance;
    final first = store.save('kenken', 1, 1, {'player': 'original'});
    ProfilePreferences.activeId = 'sibling';
    final second = store.save('kenken', 1, 1, {'player': 'sibling'});
    await store.flush();
    await Future.wait([first, second]);
    expect(await store.load('kenken', 1, 1), {'player': 'sibling'});
    ProfilePreferences.activeId = 'default';
    expect(await store.load('kenken', 1, 1), {'player': 'original'});
  });
  test('read flushes a pending board and grade mismatch never resumes it',
      () async {
    final store = PuzzleSessionStore.instance;
    final save = store.save('kenken', 2, 5, {'moves': 4});
    expect(await store.load('kenken', 2, 5), {'moves': 4});
    await save;
    expect(await store.load('kenken', 1, 5), isNull);
  });
  test('clear is ordered before a later new round save', () async {
    final store = PuzzleSessionStore.instance;
    final old = store.save('kenken', 1, 1, {'round': 'old'});
    final clear = store.clear('kenken');
    final next = store.save('kenken', 1, 1, {'round': 'new'});
    await store.flush();
    await Future.wait([old, clear, next]);
    expect(await store.load('kenken', 1, 1), {'round': 'new'});
  });
}
