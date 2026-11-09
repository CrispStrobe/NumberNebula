import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/kompass/models/kompass_attempt.dart';
import 'package:space_math_academy/features/kompass/models/kompass_content.dart';
import 'package:space_math_academy/features/kompass/screens/kompass_course_screen.dart';
import 'package:space_math_academy/features/kompass/screens/kompass_review_screen.dart';
import 'package:space_math_academy/features/kompass/services/kompass_store.dart';
import 'package:space_math_academy/generated/l10n.dart';

Map<String, dynamic> _fixtureJson() => {
      'schemaVersion': 2,
      'id': 'compatibility-fixture',
      'version': '3.0.0',
      'source': {'kind': 'original'},
      'compatibleTaskIds': {
        '2.0.1': ['stable'],
      },
      'competencies': [
        {
          'id': 'M-Z04',
          'domain': 'numbers',
          'title': {'de': 'Rechnen', 'en': 'Calculate'},
          'goal': {'de': 'Rechne und erkläre.', 'en': 'Calculate and explain.'},
          'evidence': 'curriculum',
          'curriculumUrl': 'https://www.bildungsplaene-bw.de/',
          'gameKeys': <String>[],
        },
      ],
      'tasks': [
        for (final id in ['stable', 'changed'])
          {
            'id': id,
            'familyId': 'family-$id',
            'domain': 'numbers',
            'use': 'practice',
            'level': 1,
            'title': {'de': 'Aufgabe $id', 'en': 'Task $id'},
            'prompt': {
              'de': id == 'stable' ? 'Rechne 7 + 5.' : 'Rechne 7 + 8.',
              'en': id == 'stable' ? 'Calculate 7 + 5.' : 'Calculate 7 + 8.',
            },
            'parts': [
              {
                'id': 'number',
                'kind': 'number',
                'prompt': {'de': 'Ergebnis', 'en': 'Result'},
                'competencyIds': ['M-Z04'],
                'maxPoints': 1,
                'answer': {'type': 'number', 'value': id == 'stable' ? 12 : 15},
              },
              {
                'id': 'why',
                'kind': 'text',
                'prompt': {'de': 'Begründe.', 'en': 'Explain.'},
                'competencyIds': ['M-Z04'],
                'maxPoints': 1,
                'answer': {
                  'type': 'manual',
                  'criteria': {
                    'de': 'Erkläre die Zerlegung für diese Aufgabe.',
                    'en': 'Explain the decomposition for this task.',
                  },
                },
              },
            ],
            'hints': [
              {'de': 'Ergänze auf 10.', 'en': 'Make 10 first.'},
            ],
            'solution': {
              'de': 'Aktuelle Lösung $id.',
              'en': 'Current solution for $id.',
            },
            'source': {'kind': 'original'},
          },
      ],
    };

KompassPack _pack() => KompassPack.fromJson(_fixtureJson());

Map<String, dynamic> _session({
  String version = '2.0.1',
  String taskId = 'stable',
}) =>
    {
      'schemaVersion': 1,
      'id': 'old-session',
      'revision': 2,
      'packVersion': version,
      'mode': 'practice',
      'taskIds': [taskId],
      'index': 0,
      'responses': {
        taskId: {'number': '11', 'why': 'My saved explanation'},
      },
      'hints': <String, int>{},
      'activeMillis': <String, int>{},
      'feedback': <String>[],
      'solutionsSeen': <String>[],
    };

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _close(WidgetTester tester, KompassStore store) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await store.flush();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var profileNumber = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'compatibility-${profileNumber++}';
  });
  tearDown(() => ProfilePreferences.activeId = 'default');

  test(
    'compatibility is explicit by both previous version and task identity',
    () {
      final pack = _pack();
      expect(pack.isTaskCompatible('stable', '2.0.1'), isTrue);
      expect(pack.isTaskCompatible('changed', '2.0.1'), isFalse);
      expect(pack.isTaskCompatible('stable', '1.0.0'), isFalse);
      expect(pack.isTaskCompatible('stable', null), isFalse);
      expect(pack.isTaskCompatible('missing', pack.version), isFalse);
      expect(pack.isTaskCompatible('changed', pack.version), isTrue);
      expect(pack.isSessionCompatible('2.0.1', ['stable']), isTrue);
      expect(pack.isSessionCompatible('2.0.1', ['stable', 'changed']), isFalse);
      expect(pack.isSessionCompatible('2.0.1', ['stable', 'stable']), isFalse);
      expect(pack.isSessionCompatible('2.0.1', []), isFalse);
      expect(
        pack.isSessionCompatible(pack.version, ['stable', 'changed']),
        isTrue,
      );
    },
  );

  test(
    'unknown, duplicate and current-version compatibility declarations are rejected',
    () {
      for (final compatibility in [
        {
          '2.0.1': ['missing'],
        },
        {
          '2.0.1': ['stable', 'stable'],
        },
        {
          '3.0.0': ['stable'],
        },
        {
          '': ['stable'],
        },
      ]) {
        expect(
          () => KompassPack.fromJson({
            ..._fixtureJson(),
            'compatibleTaskIds': compatibility,
          }),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'the extended bundled pack only reuses unchanged historical task objects',
    () {
      final previous = jsonDecode(
        File(
          'tool/kompass/baselines/math_v2_0_1.json',
        ).readAsStringSync(),
      ) as Map<String, dynamic>;
      final current = KompassPack.fromJson(
        jsonDecode(File('assets/kompass/math_v2.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      final previousVersion = previous['version'] as String;
      expect(current.version, isNot(previousVersion));
      final oldIds = <String>{};
      for (final value in previous['tasks'] as List) {
        final task = value as Map<String, dynamic>;
        final id = task['id'] as String;
        oldIds.add(id);
        expect(
          current.isTaskCompatible(id, previousVersion),
          isTrue,
          reason: id,
        );
        expect(
          current.taskById(id)!.toJson(),
          task,
          reason: 'Whole task must remain unchanged: $id',
        );
      }
      final added =
          current.tasks.where((task) => !oldIds.contains(task.id)).toList();
      expect(added, isNotEmpty);
      for (final task in added) {
        expect(current.isTaskCompatible(task.id, previousVersion), isFalse);
      }
      expect(current.isSessionCompatible(previousVersion, oldIds), isTrue);
      expect(
        current.isSessionCompatible('unknown-old-version', oldIds),
        isFalse,
      );
    },
  );

  testWidgets(
    'a verified old session resumes and corrects answers without replacing first evidence',
    (tester) async {
      final pack = _pack();
      final store = await KompassStore.open();
      final task = pack.taskById('stable')!;
      await store.record(
        KompassAttempt.forTask(
          id: 'old-session:stable',
          sessionId: 'old-session',
          task: task,
          packVersion: '2.0.1',
          mode: KompassMode.practice,
          firstResponses: {'number': '11', 'why': 'My saved explanation'},
          hintsUsed: 1,
          solutionSeen: true,
          activeSeconds: 5,
        ),
      );
      await store.saveSession(_session());
      await tester.pumpWidget(
        _app(
          KompassCourseScreen.resume(
            pack: pack,
            store: store,
            session: store.session!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final answer = find.byKey(const ValueKey('answer-stable-number'));
      expect(answer, findsOneWidget);
      // The restored hint sits below the fold of the lazily built task list.
      await tester.scrollUntilVisible(
        find.textContaining('Make 10 first.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Make 10 first.'), findsOneWidget);
      await tester.ensureVisible(answer);
      await tester.enterText(answer, '12');
      await tester.pump();
      await _tap(tester, find.byKey(const ValueKey('kompass-check-answer')));
      final attempt = store.attempts.single;
      expect(attempt.packVersion, '2.0.1');
      expect(attempt.firstResponses['number'], '11');
      expect(attempt.responses['number'], '12');
      expect(attempt.firstScore.partById('number')!.correct, isFalse);
      expect(attempt.score.partById('number')!.correct, isTrue);
      expect(attempt.solutionSeen, isTrue);
      expect(attempt.hintsUsed, 1);
      expect(store.session!['id'], 'old-session');
      expect(store.session!['packVersion'], pack.version);
      expect(
        find.textContaining('Saving is currently unavailable'),
        findsNothing,
      );
      await _close(tester, store);
    },
  );

  testWidgets(
    'the verified old manual response can use the unchanged current rubric',
    (tester) async {
      final pack = _pack();
      final store = await KompassStore.open();
      await store.record(
        KompassAttempt.forTask(
          id: 'old-manual',
          sessionId: 'old-session',
          task: pack.taskById('stable')!,
          packVersion: '2.0.1',
          mode: KompassMode.practice,
          firstResponses: {'number': '12', 'why': 'My saved explanation'},
        ),
      );
      await tester.pumpWidget(
        _app(
          KompassReviewScreen(
            pack: pack,
            store: store,
            attemptIds: const ['old-manual'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Earlier record'), findsNothing);
      await _tap(tester, find.widgetWithText(ChoiceChip, '1.0 / 1.0'));
      final attempt = store.attempts.single;
      expect(attempt.packVersion, '2.0.1');
      expect(attempt.firstScore.pendingReview, isTrue);
      expect(attempt.score.pendingReview, isFalse);
      expect(attempt.score.partById('why')!.awardedPoints, 1);
      expect(attempt.responses['why'], 'My saved explanation');
      await _close(tester, store);
    },
  );

  for (final historical in [
    ('changed', '2.0.1'),
    ('stable', 'unknown-version'),
  ]) {
    testWidgets(
      'unverified session ${historical.$1}/${historical.$2} remains blocked and intact',
      (tester) async {
        final pack = _pack();
        final store = await KompassStore.open();
        await store.saveSession(
          _session(taskId: historical.$1, version: historical.$2),
        );
        await tester.pumpWidget(
          _app(
            KompassCourseScreen.resume(
              pack: pack,
              store: store,
              session: store.session!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            'This saved session uses a different content version',
          ),
          findsOneWidget,
        );
        expect(find.byType(TextFormField), findsNothing);
        expect(store.session!['packVersion'], historical.$2);
        expect(store.session!['responses'][historical.$1]['number'], '11');
        expect(store.attempts, isEmpty);
        await _close(tester, store);
      },
    );

    testWidgets(
      'unverified manual record ${historical.$1}/${historical.$2} cannot receive a current rubric',
      (tester) async {
        final pack = _pack();
        final store = await KompassStore.open();
        await store.record(
          KompassAttempt.forTask(
            id: 'unverified',
            sessionId: 'unverified-session',
            task: pack.taskById(historical.$1)!,
            packVersion: historical.$2,
            mode: KompassMode.practice,
            firstResponses: {'number': '11', 'why': 'My original explanation'},
          ),
        );
        await tester.pumpWidget(
          _app(
            KompassReviewScreen(
              pack: pack,
              store: store,
              attemptIds: const ['unverified'],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Earlier record'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Earlier record'), findsOneWidget);
        expect(find.text('My original explanation'), findsOneWidget);
        expect(find.byType(ChoiceChip), findsNothing);
        expect(
          find.text('Current solution for ${historical.$1}.'),
          findsNothing,
        );
        expect(store.attempts.single.score.pendingReview, isTrue);
        expect(store.attempts.single.revision, 0);
        await _close(tester, store);
      },
    );
  }
}
