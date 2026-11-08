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

KompassPack _pack({String use = 'practice', bool manual = false}) =>
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
        }
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
                'kind': 'number',
                'prompt': {'de': 'Ergebnis', 'en': 'Result'},
                'competencyIds': ['M-Z04'],
                'maxPoints': 1,
                'answer': {'type': 'number', 'value': 12}
              },
              if (manual)
                {
                  'id': 'why',
                  'kind': 'text',
                  'prompt': {'de': 'Begründe.', 'en': 'Explain.'},
                  'competencyIds': ['M-Z04'],
                  'maxPoints': 1,
                  'answer': {
                    'type': 'manual',
                    'criteria': {
                      'de': 'Beschreibe 7 + 3 + 2.',
                      'en': 'Describe 7 + 3 + 2.'
                    }
                  }
                },
            ],
            'hints': [
              {'de': 'Ergänze zuerst auf 10.', 'en': 'Make 10 first.'}
            ],
            'solution': {'de': '7 + 3 + 2 = 12.', 'en': '7 + 3 + 2 = 12.'},
            'source': {'kind': 'original'},
          }
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
        GlobalCupertinoLocalizations.delegate
      ],
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: child!),
      home: child,
    );

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 260,
      scrollable: find.byType(Scrollable).first);
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
    await tester.pumpWidget(_app(KompassCourseScreen(
        pack: pack,
        store: store,
        tasks: [pack.tasks.first],
        mode: KompassMode.practice)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('answer-task0-a')), '11');
    await _tap(tester, find.byKey(const ValueKey('kompass-check-answer')));
    expect(store.attempts.single.firstScore.fullyCorrect, isFalse);
    await _tap(tester, find.byKey(const ValueKey('kompass-hint')));
    expect(find.text('1. Make 10 first.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('answer-task0-a')));
    await tester.enterText(find.byKey(const ValueKey('answer-task0-a')), '12');
    await _tap(tester, find.byKey(const ValueKey('kompass-check-answer')));
    final attempt = store.attempts.single;
    expect(attempt.firstResponses['a'], '11');
    expect(attempt.responses['a'], '12');
    expect(attempt.firstScore.fullyCorrect, isFalse);
    expect(attempt.score.fullyCorrect, isTrue);
    expect(attempt.hintsUsed, 1);
    expect(attempt.verified, isFalse);
    await _close(tester, store);
  });

  testWidgets(
      'independent check hides hints and feedback, permits skip and return',
      (tester) async {
    final pack = _pack(use: 'check');
    final store = await KompassStore.open();
    await tester.pumpWidget(_app(KompassCourseScreen(
        pack: pack, store: store, tasks: pack.tasks, mode: KompassMode.check)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kompass-hint')), findsNothing);
    expect(find.byKey(const ValueKey('kompass-check-answer')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('answer-task0-a')), '11');
    await _tap(tester, find.byKey(const ValueKey('kompass-next-task')));
    expect(find.text('Task 1'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('kompass-task-nav-0')));
    expect(find.widgetWithText(TextFormField, '11'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('answer-task0-a')), '12');
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
  });

  testWidgets('unsubmitted answer and hint restore after leaving the course',
      (tester) async {
    final pack = _pack();
    final store = await KompassStore.open();
    await tester.pumpWidget(_app(KompassCourseScreen(
        pack: pack,
        store: store,
        tasks: pack.tasks,
        mode: KompassMode.practice)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('answer-task0-a')), '1234');
    await _tap(tester, find.byKey(const ValueKey('kompass-hint')));
    await _close(tester, store);
    final restored = await KompassStore.open();
    expect(restored.session!['responses']['task0']['a'], '1234');
    await tester.pumpWidget(_app(KompassCourseScreen.resume(
        pack: pack, store: restored, session: restored.session!)));
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
    await tester.pumpWidget(_app(KompassCourseScreen(
        pack: pack,
        store: store,
        tasks: pack.tasks,
        mode: KompassMode.rehearsal,
        rehearsalDuration: const Duration(minutes: 45),
        now: () => now)));
    await tester.pumpAndSettle();
    expect(find.text('45:00'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('answer-task0-a')), '12');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(DateTime.parse(store.session!['deadline'] as String),
        now.add(const Duration(minutes: 45)));
    now = now.add(const Duration(minutes: 46));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Working time has ended.'), findsOneWidget);
    expect(store.session, isNull);
    expect(store.attempts.first.activeSeconds, lessThan(30));
    await _close(tester, store);
  });

  testWidgets(
      'clearing a submitted answer can finish without erasing first evidence',
      (tester) async {
    final pack = _pack();
    final store = await KompassStore.open();
    await tester.pumpWidget(_app(KompassCourseScreen(
        pack: pack,
        store: store,
        tasks: [pack.tasks.first],
        mode: KompassMode.practice)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('answer-task0-a')), '12');
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
  });

  testWidgets(
      'manual rubric review persists separately from independent correctness',
      (tester) async {
    final pack = _pack(use: 'check', manual: true);
    final store = await KompassStore.open();
    final task = pack.tasks.first;
    await store.record(KompassAttempt.forTask(
        id: 'manual',
        sessionId: 's',
        task: task,
        packVersion: pack.version,
        mode: KompassMode.check,
        firstResponses: {'a': '12', 'why': '7 + 3 + 2'}));
    await tester.pumpWidget(_app(KompassReviewScreen(
        pack: pack, store: store, attemptIds: const ['manual'])));
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(ChoiceChip, '1.0 / 1.0'));
    expect(store.attempts.single.score.pendingReview, isFalse);
    expect(store.attempts.single.firstScore.pendingReview, isTrue);
    expect(store.attempts.single.score.parts.last.reviewed, isTrue);
    await _close(tester, store);
  });

  for (final locale in ['de', 'en']) {
    testWidgets('$locale course and hub fit a small phone with twice-size text',
        (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pack = _pack(manual: true);
      final store = await KompassStore.open();
      await tester.pumpWidget(_app(
          KompassCourseScreen(
              pack: pack,
              store: store,
              tasks: pack.tasks,
              mode: KompassMode.practice),
          locale: locale,
          scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _tap(tester, find.byKey(const ValueKey('kompass-hint')));
      expect(tester.takeException(), isNull);
      await _close(tester, store);
      await tester.pumpWidget(_app(KompassHubScreen(pack: pack, store: store),
          locale: locale, scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _close(tester, store);
    });
  }
}
