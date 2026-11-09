import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/kompass/models/kompass_attempt.dart';
import 'package:space_math_academy/features/kompass/models/kompass_content.dart';
import 'package:space_math_academy/features/kompass/screens/kompass_course_screen.dart';
import 'package:space_math_academy/features/kompass/screens/kompass_hub_screen.dart';
import 'package:space_math_academy/features/kompass/screens/kompass_review_screen.dart';
import 'package:space_math_academy/features/kompass/services/kompass_store.dart';
import 'package:space_math_academy/generated/l10n.dart';

KompassPack _pack({
  String use = 'practice',
  bool manual = false,
  int manualParts = 1,
  bool choices = false,
}) =>
    KompassPack.fromJson({
      'schemaVersion': 2,
      'id': 'screen-fixture',
      'version': '2.0.0',
      'source': {'kind': 'original'},
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
        for (var i = 0; i < 2; i++)
          {
            'id': 'task$i',
            'familyId': 'family$i',
            'domain': 'numbers',
            'use': use,
            'level': 1,
            'title': {'de': 'Aufgabe $i', 'en': 'Task $i'},
            'prompt': {'de': 'Rechne 7 + 5.', 'en': 'Calculate 7 + 5.'},
            'parts': [
              {
                'id': 'a',
                'kind': choices ? 'multiChoice' : 'number',
                'prompt': {'de': 'Ergebnis', 'en': 'Result'},
                'competencyIds': ['M-Z04'],
                'maxPoints': 1,
                'answer': choices
                    ? {
                        'type': 'set',
                        'values': ['one'],
                      }
                    : {'type': 'number', 'value': 12},
                if (choices)
                  'options': [
                    {
                      'id': 'one',
                      'label': {'de': 'Eins', 'en': 'One'},
                    },
                    {
                      'id': 'two',
                      'label': {'de': 'Zwei', 'en': 'Two'},
                    },
                  ],
              },
              if (manual)
                for (var partIndex = 0; partIndex < manualParts; partIndex++)
                  {
                    'id': partIndex == 0 ? 'why' : 'why$partIndex',
                    'kind': 'text',
                    'prompt': {'de': 'Begründe.', 'en': 'Explain.'},
                    'competencyIds': ['M-Z04'],
                    'maxPoints': 1,
                    'answer': {
                      'type': 'manual',
                      'criteria': {
                        'de': 'Beschreibe 7 + 3 + 2.',
                        'en': 'Describe 7 + 3 + 2.',
                      },
                    },
                  },
            ],
            'hints': [
              {'de': 'Ergänze zuerst auf 10.', 'en': 'Make 10 first.'},
            ],
            'solution': {'de': '7 + 3 + 2 = 12.', 'en': '7 + 3 + 2 = 12.'},
            'source': {'kind': 'original'},
          },
      ],
    });

Widget _app(Widget child, {String locale = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: child,
    );

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    260,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _close(WidgetTester tester, KompassStore store) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await store.flush();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var profileNumber = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'course-${profileNumber++}';
  });

  testWidgets(
    'practice preserves wrong first response and support across correction',
    (tester) async {
      final pack = _pack();
      final store = await KompassStore.open();
      await tester.pumpWidget(
        _app(
          KompassCourseScreen(
            pack: pack,
            store: store,
            tasks: [pack.tasks.first],
            mode: KompassMode.practice,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('answer-task0-a')),
        '11',
      );
      await _tap(tester, find.byKey(const ValueKey('kompass-check-answer')));
      expect(store.attempts.single.firstScore.fullyCorrect, isFalse);
      await _tap(tester, find.byKey(const ValueKey('kompass-hint')));
      expect(find.text('1. Make 10 first.'), findsOneWidget);
      expect(store.attempts.single.hintsUsed, 1);
      expect(store.attempts.single.hintsBeforeFirstResponse, 0);
      expect(store.attempts.single.responses['a'], '11');
      await tester.ensureVisible(find.byKey(const ValueKey('answer-task0-a')));
      await tester.enterText(
        find.byKey(const ValueKey('answer-task0-a')),
        '12',
      );
      await _tap(tester, find.byKey(const ValueKey('kompass-check-answer')));
      final attempt = store.attempts.single;
      expect(attempt.firstResponses['a'], '11');
      expect(attempt.responses['a'], '12');
      expect(attempt.firstScore.fullyCorrect, isFalse);
      expect(attempt.score.fullyCorrect, isTrue);
      expect(attempt.hintsUsed, 1);
      expect(attempt.verified, isFalse);
      await _close(tester, store);
    },
  );

  testWidgets(
    'opening a worked solution records support before any correction and survives reopening',
    (tester) async {
      final pack = _pack();
      final store = await KompassStore.open();
      await tester.pumpWidget(
        _app(
          KompassCourseScreen(
            pack: pack,
            store: store,
            tasks: [pack.tasks.first],
            mode: KompassMode.practice,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('answer-task0-a')),
        '11',
      );
      await _tap(tester, find.byKey(const ValueKey('kompass-check-answer')));
      expect(store.attempts.single.solutionSeen, isFalse);
      await _tap(tester, find.text('View the worked solution'));
      await tester.pumpAndSettle();
      expect(store.attempts.single.solutionSeen, isTrue);
      expect(store.attempts.single.assisted, isTrue);
      expect(store.attempts.single.solutionSeenBeforeFirstResponse, isFalse);
      expect(store.attempts.single.firstResponses['a'], '11');
      expect(store.attempts.single.responses['a'], '11');
      await _close(tester, store);

      final restored = await KompassStore.open();
      expect(restored.session!['solutionsSeen'], ['task0']);
      await tester.pumpWidget(
        _app(
          KompassCourseScreen.resume(
            pack: pack,
            store: restored,
            session: restored.session!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('answer-task0-a')),
        '12',
      );
      await _tap(tester, find.byKey(const ValueKey('kompass-check-answer')));
      expect(restored.attempts.single.solutionSeen, isTrue);
      expect(restored.attempts.single.hintsUsed, 0);
      expect(restored.attempts.single.firstScore.fullyCorrect, isFalse);
      expect(restored.attempts.single.score.fullyCorrect, isTrue);
      expect(restored.attempts.single.firstResponses['a'], '11');
      expect(restored.attempts.single.responses['a'], '12');
      await _tap(tester, find.byKey(const ValueKey('kompass-finish')));
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Worked solution viewed during practice.'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Worked solution viewed during practice.'),
        findsOneWidget,
      );
      await _close(tester, restored);
    },
  );

  testWidgets(
    'independent check hides hints and feedback, permits skip and return',
    (tester) async {
      final pack = _pack(use: 'check');
      final store = await KompassStore.open();
      await tester.pumpWidget(
        _app(
          KompassCourseScreen(
            pack: pack,
            store: store,
            tasks: pack.tasks,
            mode: KompassMode.check,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kompass-hint')), findsNothing);
      expect(find.byKey(const ValueKey('kompass-check-answer')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('answer-task0-a')),
        '11',
      );
      await _tap(tester, find.byKey(const ValueKey('kompass-next-task')));
      expect(find.text('Task 1'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('kompass-task-nav-0')));
      expect(find.widgetWithText(TextFormField, '11'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('answer-task0-a')),
        '12',
      );
      expect(store.attempts, isEmpty);
      await _tap(tester, find.byKey(const ValueKey('kompass-finish')));
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();
      expect(find.byType(KompassReviewScreen), findsOneWidget);
      expect(store.session, isNull);
      expect(store.attempts, hasLength(2));
      expect(store.attempts.first.firstResponses['a'], '12');
      expect(store.attempts.first.verified, isTrue);
      expect(store.attempts.last.completed, isFalse);
      expect(store.attempts.last.verified, isFalse);
      await _close(tester, store);
    },
  );

  testWidgets('a held answer from one task cannot answer the next task', (
    tester,
  ) async {
    final pack = _pack(use: 'check', choices: true);
    final store = await KompassStore.open();
    await tester.pumpWidget(
      _app(
        KompassCourseScreen(
          pack: pack,
          store: store,
          tasks: pack.tasks,
          mode: KompassMode.check,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final held = await tester.startGesture(
      tester.getCenter(find.widgetWithText(FilterChip, 'One')),
      pointer: 91,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('kompass-task-nav-1')),
      pointer: 92,
    );
    await tester.pumpAndSettle();
    expect(find.text('Task 1'), findsOneWidget);
    await held.up();
    await tester.pump(const Duration(milliseconds: 350));
    expect((store.session!['responses']['task1'] as Map)['a'], isNull);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'One'))
          .selected,
      isFalse,
    );
    await _close(tester, store);
  });

  testWidgets(
    'restoration reconciles durable assistance when the session snapshot lags',
    (tester) async {
      final pack = _pack();
      final store = await KompassStore.open();
      await store.saveSession({
        'schemaVersion': 1,
        'id': 'interrupted',
        'revision': 1,
        'packVersion': pack.version,
        'mode': 'practice',
        'taskIds': [pack.tasks.first.id],
        'index': 0,
        'responses': {
          'task0': {'a': '11'},
        },
        'hints': {'task0': 0},
        'activeMillis': {'task0': 1000},
        'feedback': ['task0'],
        'solutionsSeen': <String>[],
      });
      await store.record(KompassAttempt.forTask(
        id: 'interrupted:task0',
        sessionId: 'interrupted',
        task: pack.tasks.first,
        packVersion: pack.version,
        mode: KompassMode.practice,
        firstResponses: {'a': '11'},
        hintsUsed: 1,
        hintsBeforeFirstResponse: 0,
        activeSeconds: 30,
        solutionSeen: true,
      ));
      await tester.pumpWidget(_app(KompassCourseScreen.resume(
        pack: pack,
        store: store,
        session: store.session!,
      )));
      await tester.pumpAndSettle();
      expect(store.session!['hints']['task0'], 1);
      expect(store.session!['solutionsSeen'], ['task0']);
      expect(
          store.session!['activeMillis']['task0'], greaterThanOrEqualTo(30000));
      await tester.scrollUntilVisible(find.text('1. Make 10 first.'), 250,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('1. Make 10 first.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('answer-task0-a')));
      await tester.enterText(
          find.byKey(const ValueKey('answer-task0-a')), '12');
      await _tap(tester, find.byKey(const ValueKey('kompass-check-answer')));
      expect(store.attempts.single.responses['a'], '12');
      expect(store.attempts.single.firstResponses['a'], '11');
      expect(store.attempts.single.hintsUsed, 1);
      expect(store.attempts.single.hintsBeforeFirstResponse, 0);
      expect(store.attempts.single.solutionSeen, isTrue);
      expect(store.attempts.single.activeSeconds, greaterThanOrEqualTo(30));
      await _close(tester, store);
    },
  );

  testWidgets('unsubmitted answer and hint restore after leaving the course', (
    tester,
  ) async {
    final pack = _pack();
    final store = await KompassStore.open();
    await tester.pumpWidget(
      _app(
        KompassCourseScreen(
          pack: pack,
          store: store,
          tasks: pack.tasks,
          mode: KompassMode.practice,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('answer-task0-a')),
      '1234',
    );
    await _tap(tester, find.byKey(const ValueKey('kompass-hint')));
    await _close(tester, store);
    final restored = await KompassStore.open();
    expect(restored.session!['responses']['task0']['a'], '1234');
    await tester.pumpWidget(
      _app(
        KompassCourseScreen.resume(
          pack: pack,
          store: restored,
          session: restored.session!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '1234'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('kompass-check-answer')));
    expect(restored.attempts.single.hintsBeforeFirstResponse, 1);
    expect(restored.attempts.single.firstResponses['a'], '1234');
    await _close(tester, restored);
  });

  testWidgets(
    'rehearsal expires at persisted wall-clock deadline including background',
    (tester) async {
      final pack = _pack(use: 'rehearsal');
      final store = await KompassStore.open();
      var now = DateTime.utc(2026, 11, 8, 10);
      await tester.pumpWidget(
        _app(
          KompassCourseScreen(
            pack: pack,
            store: store,
            tasks: pack.tasks,
            mode: KompassMode.rehearsal,
            rehearsalDuration: const Duration(minutes: 45),
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('45:00'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('answer-task0-a')),
        '12',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(
        DateTime.parse(store.session!['deadline'] as String),
        now.add(const Duration(minutes: 45)),
      );
      now = now.add(const Duration(minutes: 46));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Working time has ended.'), findsOneWidget);
      expect(store.session, isNull);
      expect(store.attempts.first.activeSeconds, lessThan(30));
      await _close(tester, store);
    },
  );

  testWidgets(
    'clearing a submitted answer can finish without erasing first evidence',
    (tester) async {
      final pack = _pack();
      final store = await KompassStore.open();
      await tester.pumpWidget(
        _app(
          KompassCourseScreen(
            pack: pack,
            store: store,
            tasks: [pack.tasks.first],
            mode: KompassMode.practice,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('answer-task0-a')),
        '12',
      );
      await _tap(tester, find.byKey(const ValueKey('kompass-check-answer')));
      await tester.ensureVisible(find.byKey(const ValueKey('answer-task0-a')));
      await tester.enterText(find.byKey(const ValueKey('answer-task0-a')), '');
      await _tap(tester, find.byKey(const ValueKey('kompass-finish')));
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();
      expect(find.byType(KompassReviewScreen), findsOneWidget);
      expect(store.attempts.single.firstResponses['a'], '12');
      expect(store.attempts.single.responses['a'], '');
      await _close(tester, store);
    },
  );

  testWidgets(
    'expiry closes the finish prompt and finalizes the session only once',
    (tester) async {
      final pack = _pack(use: 'rehearsal');
      final store = await KompassStore.open();
      var now = DateTime.utc(2026, 11, 8, 12);
      await tester.pumpWidget(
        _app(
          KompassCourseScreen(
            pack: pack,
            store: store,
            tasks: pack.tasks,
            mode: KompassMode.rehearsal,
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('kompass-finish')));
      expect(find.byType(AlertDialog), findsOneWidget);
      now = now.add(const Duration(minutes: 46));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Working time has ended.'), findsOneWidget);
      expect(store.attempts, hasLength(2));
      expect(store.session, isNull);
      await tester.pump(const Duration(seconds: 12));
      expect(store.attempts, hasLength(2));
      expect(store.session, isNull);
      await _close(tester, store);
    },
  );

  testWidgets(
    'manual rubric review persists separately from independent correctness',
    (tester) async {
      final pack = _pack(use: 'check', manual: true);
      final store = await KompassStore.open();
      final task = pack.tasks.first;
      await store.record(
        KompassAttempt.forTask(
          id: 'manual',
          sessionId: 's',
          task: task,
          packVersion: pack.version,
          mode: KompassMode.check,
          firstResponses: {'a': '12', 'why': '7 + 3 + 2'},
        ),
      );
      await tester.pumpWidget(
        _app(
          KompassReviewScreen(
            pack: pack,
            store: store,
            attemptIds: const ['manual'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(ChoiceChip, '1.0 / 1.0'));
      expect(store.attempts.single.score.pendingReview, isFalse);
      expect(store.attempts.single.firstScore.pendingReview, isTrue);
      expect(store.attempts.single.score.parts.last.reviewed, isTrue);
      await _close(tester, store);
    },
  );

  testWidgets(
    'retained rubric controls revise the latest attempt and preserve other reviewed parts',
    (tester) async {
      final pack = _pack(use: 'check', manual: true, manualParts: 2);
      final store = await KompassStore.open();
      await store.record(KompassAttempt.forTask(
        id: 'manual-latest',
        sessionId: 'manual-session',
        task: pack.tasks.first,
        packVersion: pack.version,
        mode: KompassMode.check,
        firstResponses: {'a': '12', 'why': '7 + 3 + 2', 'why1': 'Make ten'},
      ));
      await tester.pumpWidget(_app(KompassReviewScreen(
        pack: pack,
        store: store,
        attemptIds: const ['manual-latest'],
      )));
      await tester.pumpAndSettle();
      final retainedReview = tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '0.5 / 1.0').last)
          .onSelected!;
      await _tap(tester, find.widgetWithText(ChoiceChip, '1.0 / 1.0').first);
      expect(store.attempts.single.score.partById('why')!.awardedPoints, 1);
      final firstReviewRevision = store.attempts.single.revision;
      retainedReview(true);
      await tester.pumpAndSettle();
      expect(store.attempts.single.revision, firstReviewRevision + 1);
      expect(store.attempts.single.score.partById('why')!.awardedPoints, 1);
      expect(store.attempts.single.score.partById('why1')!.awardedPoints, .5);
      expect(store.attempts.single.score.pendingReview, isFalse);
      expect(store.attempts.single.firstScore.pendingReview, isTrue);
      await _close(tester, store);
    },
  );

  testWidgets(
    'historical scores are not paired with a changed solution or rubric',
    (tester) async {
      final pack = _pack(use: 'check', manual: true);
      final store = await KompassStore.open();
      await store.record(
        KompassAttempt.forTask(
          id: 'old',
          sessionId: 'old-session',
          task: pack.tasks.first,
          packVersion: '1.0.0',
          mode: KompassMode.check,
          firstResponses: {'a': '12', 'why': 'my original explanation'},
        ),
      );
      await tester.pumpWidget(
        _app(
          KompassReviewScreen(
            pack: pack,
            store: store,
            attemptIds: const ['old'],
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
      expect(find.text('my original explanation'), findsOneWidget);
      expect(find.text('7 + 3 + 2 = 12.'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(store.attempts.single.score.pendingReview, isTrue);
      await _close(tester, store);
    },
  );

  for (final locale in ['de', 'en']) {
    testWidgets(
      '$locale course and hub fit a small phone with twice-size text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pack = _pack(manual: true);
        final store = await KompassStore.open();
        await tester.pumpWidget(
          _app(
            KompassCourseScreen(
              pack: pack,
              store: store,
              tasks: pack.tasks,
              mode: KompassMode.practice,
            ),
            locale: locale,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _tap(tester, find.byKey(const ValueKey('kompass-hint')));
        expect(tester.takeException(), isNull);
        await _close(tester, store);
        await tester.pumpWidget(
          _app(
            KompassHubScreen(pack: pack, store: store),
            locale: locale,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _close(tester, store);
      },
    );
  }
}
