import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/kompass/models/kompass_attempt.dart';
import 'package:space_math_academy/features/kompass/models/kompass_content.dart';
import 'package:space_math_academy/features/kompass/services/kompass_store.dart';

KompassTask _task() => KompassTask.fromJson({
      'id': 'add',
      'familyId': 'add_family',
      'domain': 'numbers',
      'title': {'de': 'Rechnen', 'en': 'Calculate'},
      'prompt': {'de': 'Rechne 7 + 5.', 'en': 'Calculate 7 + 5.'},
      'level': 1,
      'use': 'check',
      'parts': [
        {
          'id': 'a',
          'kind': 'number',
          'prompt': {'de': 'Ergebnis', 'en': 'Result'},
          'competencyIds': ['M-Z04'],
          'maxPoints': 1,
          'answer': {'type': 'number', 'value': 12},
        },
      ],
      'hints': <Map<String, String>>[],
      'solution': {'de': '12', 'en': '12'},
      'source': {'kind': 'original'},
    });

KompassAttempt _attempt(String id,
        {String answer = '12', String session = 's1'}) =>
    KompassAttempt.forTask(
      id: id,
      sessionId: session,
      task: _task(),
      packVersion: '2.0.0',
      mode: KompassMode.check,
      firstResponses: {'a': answer},
      at: DateTime.utc(2026, 11, 8),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'default';
  });
  tearDown(() async {
    ProfilePreferences.activeId = 'default';
    await (await KompassStore.open()).flush();
  });

  test(
      'records each completion once and persists a deep first-response snapshot',
      () async {
    final store = await KompassStore.open();
    final item = _attempt('one');
    expect(await store.record(item), isTrue);
    expect(await store.record(item), isFalse);
    final restored = await KompassStore.open();
    expect(restored.attempts, hasLength(1));
    expect(restored.attempts.single.firstResponses['a'], '12');
    expect(restored.attempts.single.verified, isTrue);
  });

  test('captures the player before asynchronous initialization and writes',
      () async {
    ProfilePreferences.activeId = 'alpha';
    final openingAlpha = KompassStore.open();
    ProfilePreferences.activeId = 'beta';
    final alpha = await openingAlpha;
    final beta = await KompassStore.open();
    expect(alpha.profileId, 'alpha');
    expect(beta.profileId, 'beta');
    await Future.wait([
      alpha.record(_attempt('alpha-answer')),
      beta.record(_attempt('beta-answer', answer: '11')),
    ]);
    ProfilePreferences.activeId = 'alpha';
    final restoredAlpha = await KompassStore.open();
    expect(restoredAlpha.attempts.single.id, 'alpha-answer');
    expect(restoredAlpha.attempts.single.score.fullyCorrect, isTrue);
    ProfilePreferences.activeId = 'beta';
    final restoredBeta = await KompassStore.open();
    expect(restoredBeta.attempts.single.id, 'beta-answer');
    expect(restoredBeta.attempts.single.score.fullyCorrect, isFalse);
    await Future.wait([alpha.flush(), beta.flush()]);
  });

  test(
      'two stores for one player merge serialized writes instead of losing one',
      () async {
    final first = await KompassStore.open();
    final second = await KompassStore.open();
    await Future.wait([
      first.record(_attempt('a')),
      second.record(_attempt('b')),
    ]);
    expect((await KompassStore.open()).attempts.map((a) => a.id), ['a', 'b']);
  });

  test(
      'same-session exposure stays novel, abandoned exposure never becomes unseen',
      () async {
    final store = await KompassStore.open();
    await store.markExposed('add_family', sessionId: 's1');
    await store.record(_attempt('first', session: 's1'));
    expect(store.attempts.single.verified, isTrue);
    await store.record(_attempt('repeat', session: 's2'));
    expect(store.attempts.last.isNovel, isFalse);
    expect(store.attempts.last.verified, isFalse);

    ProfilePreferences.activeId = 'new-player';
    final other = await KompassStore.open();
    await other.markExposed('add_family', sessionId: 'abandoned');
    await other.record(_attempt('later', session: 'new-session'));
    expect(other.attempts.single.verified, isFalse);
    expect((await KompassStore.open()).exposedFamilies, contains('add_family'));
  });

  test(
      'revising answers preserves first evidence and never adds a second attempt',
      () async {
    final store = await KompassStore.open();
    final initial = _attempt('one', answer: '11');
    await store.record(initial);
    final corrected = initial.reviseTask(
        task: _task(), responses: {'a': '12'}, hintsUsed: 1, activeSeconds: 12);
    await store.revise(corrected);
    expect(store.attempts, hasLength(1));
    expect(store.attempts.single.firstScore.fullyCorrect, isFalse);
    expect(store.attempts.single.score.fullyCorrect, isTrue);
    await expectLater(store.revise(_attempt('one')), throwsArgumentError);
    expect(store.attempts.single.firstResponses['a'], '11');
  });

  test('session snapshots are frozen and survive reopening', () async {
    final store = await KompassStore.open();
    final responses = <String, dynamic>{'a': '11'};
    final pending = store.saveSession({
      'id': 's1',
      'taskIds': ['add'],
      'responses': responses,
      'mode': 'rehearsal',
      'deadline': '2026-11-08T12:45:00Z',
      'revision': 1,
    });
    responses['a'] = '999';
    await pending;
    final restored = await KompassStore.open();
    expect(restored.session!['responses']['a'], '11');
    expect(restored.session!['deadline'], '2026-11-08T12:45:00Z');
    await store.saveSession({
      'id': 's1',
      'revision': 3,
      'responses': {'a': '12'}
    });
    expect(
        await store.saveSession({
          'id': 's1',
          'revision': 2,
          'responses': {'a': '0'}
        }),
        isFalse);
    expect(store.session!['responses']['a'], '12');
  });

  test('worked-solution exposure survives reload and cannot be erased',
      () async {
    final store = await KompassStore.open();
    final initial = _attempt('solution', answer: '11');
    await store.record(initial);
    final supported = initial.reviseTask(
        task: _task(), responses: {'a': '12'}, solutionSeen: true);
    await store.revise(supported);
    final restored = await KompassStore.open();
    expect(restored.attempts.single.solutionSeen, isTrue);
    expect(restored.attempts.single.assisted, isTrue);
    expect(restored.attempts.single.firstResponses['a'], '11');
    await expectLater(
        restored.revise(supported.copyWith(solutionSeen: false)),
        throwsArgumentError);
    expect((await KompassStore.open()).attempts.single.solutionSeen, isTrue);
  });

  test(
      'late callbacks cannot restore completed sessions or erase a newer session',
      () async {
    final store = await KompassStore.open();
    await store.saveSession({'id': 'old'});
    await store.clearSession(sessionId: 'old');
    expect(await store.saveSession({'id': 'old'}), isFalse);
    await store.saveSession({'id': 'new'});
    await store.clearSession(sessionId: 'old');
    expect(store.session!['id'], 'new');
    await expectLater(store.saveSession({'id': 'other'}), throwsStateError);
    await store.saveSession({'id': 'other'}, replace: true);
    expect(store.session!['id'], 'other');
    expect(await store.saveSession({'id': 'new'}), isFalse);
  });

  test(
      'unreadable data is not silently replaced and explicit recovery keeps it',
      () async {
    SharedPreferences.setMockInitialValues(
        {KompassStore.storageKey: '{broken'});
    final store = await KompassStore.open();
    expect(store.corruptionError, isNotNull);
    await expectLater(store.record(_attempt('one')), throwsStateError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(KompassStore.storageKey), '{broken');
    await store.resetAfterCorruption();
    final backups = prefs
        .getKeys()
        .where((key) => key.startsWith('${KompassStore.storageKey}_recovery_'));
    expect(backups, hasLength(1));
    expect(prefs.getString(backups.single), '{broken');
    expect(store.corruptionError, isNull);
    await store.record(_attempt('one'));
    final saved = jsonDecode(prefs.getString(KompassStore.storageKey)!) as Map;
    expect(saved['attempts'], hasLength(1));
  });

  test('a stale recovery screen cannot erase progress repaired elsewhere',
      () async {
    SharedPreferences.setMockInitialValues(
        {KompassStore.storageKey: '{broken'});
    final first = await KompassStore.open();
    final stale = await KompassStore.open();
    await first.resetAfterCorruption();
    await first.record(_attempt('recovered'));
    await expectLater(stale.resetAfterCorruption(), throwsStateError);
    expect(stale.corruptionError, isNull);
    expect(stale.attempts.single.id, 'recovered');
    expect((await KompassStore.open()).attempts.single.id, 'recovered');
  });
}
