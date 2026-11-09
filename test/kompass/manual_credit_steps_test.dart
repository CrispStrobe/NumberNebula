import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/kompass/models/kompass_attempt.dart';
import 'package:space_math_academy/features/kompass/models/kompass_content.dart';
import 'package:space_math_academy/features/kompass/screens/kompass_review_screen.dart';
import 'package:space_math_academy/features/kompass/services/kompass_repository.dart';
import 'package:space_math_academy/features/kompass/services/kompass_store.dart';
import 'package:space_math_academy/generated/l10n.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

KompassPack _pack() => KompassRepository.fromJson(
      KompassRepository.merge(
        _read(KompassRepository.assetPath),
        _read(KompassRepository.originalAssetPath),
      ),
    );

Widget _app(KompassPack pack, KompassStore store, String attemptId) =>
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: KompassReviewScreen(
        pack: pack,
        store: store,
        attemptIds: [attemptId],
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var profileNumber = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Store write queues survive between tests; never reuse a FakeAsync profile.
    ProfilePreferences.activeId = 'manual-credit-${profileNumber++}';
  });
  tearDown(() => ProfilePreferences.activeId = 'default');

  for (final review in const [
    (
      name: 'one-point original rubric excludes half credit',
      taskId: 'k4_m1_11',
      partId: 'b',
      use: 'original',
      creditSteps: <int>[0, 1],
      labels: <String>['0.0 / 1.0', '1.0 / 1.0'],
      points: 1.0,
    ),
    (
      name: 'two-point original rubric permits only declared whole points',
      taskId: 'k4_m3_09',
      partId: 'a',
      use: 'original',
      creditSteps: <int>[0, 1, 2],
      labels: <String>['0.0 / 2.0', '1.0 / 2.0', '2.0 / 2.0'],
      points: 1.0,
    ),
    (
      name: 'legacy course rubric retains half-point review choices',
      taskId: 'mz06_write_sharing_story',
      partId: 'story',
      use: 'practice',
      creditSteps: null,
      labels: <String>[
        '0.0 / 2.0',
        '0.5 / 2.0',
        '1.0 / 2.0',
        '1.5 / 2.0',
        '2.0 / 2.0',
      ],
      points: 1.5,
    ),
  ]) {
    testWidgets(review.name, (tester) async {
      final pack = _pack();
      final task = pack.taskById(review.taskId)!;
      final part = task.parts.singleWhere((part) => part.id == review.partId);
      // Keep the expected controls independent of the production getter.
      expect(task.use, review.use);
      expect(task.parts.where((part) => part.isManual), hasLength(1));
      expect(part.answer['creditSteps'], review.creditSteps);

      final profileId = ProfilePreferences.activeId;
      final capturedPreferences = await ProfilePreferences.getInstance();
      final store = await KompassStore.open();
      final attemptId = 'manual-review:${task.id}';
      final firstResponses = <String, dynamic>{
        part.id: 'My first response is kept on paper.',
      };
      final latestResponses = <String, dynamic>{
        part.id: 'My revised response is kept on paper.',
      };
      await store.record(
        KompassAttempt.forTask(
          id: attemptId,
          sessionId: 'manual-review-session',
          task: task,
          packVersion: pack.version,
          mode: KompassMode.practice,
          firstResponses: firstResponses,
          responses: latestResponses,
          at: DateTime.utc(2026, 11, 9, 9),
        ),
      );
      final firstScoreJson = jsonDecode(
        jsonEncode(store.attempts.single.firstScore.toJson()),
      );
      expect(store.attempts.single.score.partById(part.id)!.pendingReview,
          isTrue);
      expect(store.attempts.single.revision, 0);

      await tester.pumpWidget(_app(pack, store, attemptId));
      await tester.pumpAndSettle();
      // Review belongs to the profile captured by the screen's store, even if
      // the active profile changes while the review is still open.
      ProfilePreferences.activeId = '$profileId-other';
      final otherPreferences = await ProfilePreferences.getInstance();
      final card = find.byKey(ValueKey('review-$attemptId'));
      final selectedLabel = '${review.points} / ${part.maxPoints}';
      final selectedChip = find.descendant(
        of: card,
        matching: find.widgetWithText(ChoiceChip, selectedLabel),
      );
      await tester.scrollUntilVisible(
        selectedChip,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(selectedChip);
      await tester.pumpAndSettle();
      final chips = find.descendant(
        of: card,
        matching: find.byType(ChoiceChip),
      );
      expect(
        tester
            .widgetList<ChoiceChip>(chips)
            .map((chip) => (chip.label as Text).data),
        review.labels,
      );
      expect(
        tester.widgetList<ChoiceChip>(chips).every((chip) => !chip.selected),
        isTrue,
      );
      expect(
        find.text('First submission: ${firstResponses[part.id]}'),
        findsOneWidget,
      );
      expect(
        find.text('Your response: ${latestResponses[part.id]}'),
        findsOneWidget,
      );

      await tester.tap(selectedChip);
      await tester.pumpAndSettle();
      await store.flush();
      await tester.pump();
      final reviewed = store.attempts.single;
      final score = reviewed.score.partById(part.id)!;
      expect(score.awardedPoints, review.points);
      expect(score.manual, isTrue);
      expect(score.reviewed, isTrue);
      expect(score.pendingReview, isFalse);
      expect(score.correct, review.points == part.maxPoints);
      expect(reviewed.revision, 1);
      expect(reviewed.firstResponses, firstResponses);
      expect(reviewed.responses, latestResponses);
      expect(reviewed.firstScore.toJson(), firstScoreJson);
      expect(tester.widget<ChoiceChip>(selectedChip).selected, isTrue);
      expect(find.text('The review could not be saved.'), findsNothing);
      expect(otherPreferences.getString(KompassStore.storageKey), isNull);
      final saved = jsonDecode(
        capturedPreferences.getString(KompassStore.storageKey)!,
      ) as Map<String, dynamic>;
      final savedAttempt = (saved['attempts'] as List).single as Map;
      expect(savedAttempt['firstResponses'], firstResponses);
      expect(savedAttempt['firstScore'], firstScoreJson);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      ProfilePreferences.activeId = profileId;
      final reopened = await KompassStore.open();
      final restored = reopened.attempts.single;
      expect(restored.score.partById(part.id)!.awardedPoints, review.points);
      expect(restored.score.partById(part.id)!.reviewed, isTrue);
      expect(restored.firstResponses, firstResponses);
      expect(restored.responses, latestResponses);
      expect(restored.firstScore.toJson(), firstScoreJson);
      await tester.pumpWidget(_app(pack, reopened, attemptId));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        selectedChip,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<ChoiceChip>(selectedChip).selected, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await reopened.flush();
    });
  }

  testWidgets(
    'correcting one old rubric score preserves other historical scores',
    (tester) async {
      final pack = _pack();
      final task = pack.taskById('k4_m2_11')!;
      expect(task.parts.map((part) => part.id), ['a', 'b']);
      for (final part in task.parts) {
        expect(part.isManual, isTrue);
        expect(part.answer['creditSteps'], [0, 1]);
      }
      const attemptId = 'legacy-manual-review';
      const firstResponses = {
        'a': 'First mirror point A on paper.',
        'b': 'First mirror point B on paper.',
      };
      const latestResponses = {
        'a': 'Revised mirror point A on paper.',
        'b': 'Revised mirror point B on paper.',
      };
      final original = KompassAttempt.forTask(
        id: attemptId,
        sessionId: 'legacy-review-session',
        task: task,
        packVersion: pack.version,
        mode: KompassMode.practice,
        firstResponses: firstResponses,
        responses: latestResponses,
        at: DateTime.utc(2026, 11, 9, 8),
      );
      final firstScoreJson = jsonDecode(
        jsonEncode(original.firstScore.toJson()),
      );
      // Persist the older application's actual score shape. New submissions
      // must not recreate these undeclared values through the current scorer.
      final historical = original.toJson()
        ..['revision'] = 2
        ..['score'] = {
          'parts': [
            for (final score in original.score.parts)
              {
                ...score.toJson(),
                'awardedPoints': 0.5,
                'correct': false,
                'pendingReview': false,
                'reviewed': true,
              },
          ],
        };
      final preferences = await ProfilePreferences.getInstance();
      await preferences.setString(
        KompassStore.storageKey,
        jsonEncode({
          'schemaVersion': 1,
          'attempts': [historical],
          'session': null,
          'exposures': {task.familyId: original.sessionId},
          'closedSessions': <String>[],
        }),
      );
      final store = await KompassStore.open();
      expect(store.corruptionError, isNull);
      expect(store.attempts.single.score.pendingReview, isFalse);
      expect(
        store.attempts.single.score.parts.map((score) => score.awardedPoints),
        [0.5, 0.5],
      );
      final oldBScoreJson = store.attempts.single.score.partById('b')!.toJson();
      await tester.pumpWidget(_app(pack, store, attemptId));
      await tester.pumpAndSettle();
      final aControls = find.byKey(
        const ValueKey('manual-review-$attemptId-a'),
      );
      final bControls = find.byKey(
        const ValueKey('manual-review-$attemptId-b'),
      );
      final aNotice = find.byKey(
        const ValueKey('review-legacy-points-$attemptId-a'),
      );
      final bNotice = find.byKey(
        const ValueKey('review-legacy-points-$attemptId-b'),
      );
      await tester.scrollUntilVisible(
        aControls,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(aNotice, findsOneWidget);
      expect(bNotice, findsOneWidget);
      expect(
        tester.widget<Text>(aNotice).data,
        'Earlier review: 0.5 points. Choose an allowed value to update.',
      );
      for (final controls in [aControls, bControls]) {
        final chips = find.descendant(
          of: controls,
          matching: find.byType(ChoiceChip),
        );
        expect(
          tester
              .widgetList<ChoiceChip>(chips)
              .map((chip) => (chip.label as Text).data),
          ['0.0 / 1.0', '1.0 / 1.0'],
        );
        expect(
          tester.widgetList<ChoiceChip>(chips).every((chip) => !chip.selected),
          isTrue,
        );
      }
      final aFullCredit = find.descendant(
        of: aControls,
        matching: find.widgetWithText(ChoiceChip, '1.0 / 1.0'),
      );
      await tester.ensureVisible(aFullCredit);
      await tester.pump();
      await tester.tap(aFullCredit);
      await tester.pumpAndSettle();
      await store.flush();
      await tester.pump();
      final afterA = store.attempts.single;
      expect(afterA.score.partById('a')!.awardedPoints, 1);
      expect(afterA.score.partById('a')!.reviewed, isTrue);
      expect(afterA.score.partById('b')!.toJson(), oldBScoreJson);
      expect(afterA.revision, 3);
      expect(afterA.firstResponses, firstResponses);
      expect(afterA.responses, latestResponses);
      expect(afterA.firstScore.toJson(), firstScoreJson);
      expect(aNotice, findsNothing);
      expect(bNotice, findsOneWidget);
      expect(tester.widget<ChoiceChip>(aFullCredit).selected, isTrue);
      expect(find.text('The review could not be saved.'), findsNothing);

      final bFullCredit = find.descendant(
        of: bControls,
        matching: find.widgetWithText(ChoiceChip, '1.0 / 1.0'),
      );
      await tester.scrollUntilVisible(
        bFullCredit,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(bFullCredit);
      await tester.pump();
      await tester.tap(bFullCredit);
      await tester.pumpAndSettle();
      await store.flush();
      await tester.pump();
      final afterB = store.attempts.single;
      expect(
        afterB.score.partById('a')!.toJson(),
        afterA.score.partById('a')!.toJson(),
      );
      expect(afterB.score.partById('b')!.awardedPoints, 1);
      expect(afterB.score.partById('b')!.reviewed, isTrue);
      expect(afterB.score.fullyCorrect, isTrue);
      expect(afterB.revision, 4);
      expect(afterB.firstResponses, firstResponses);
      expect(afterB.responses, latestResponses);
      expect(afterB.firstScore.toJson(), firstScoreJson);
      expect(aNotice, findsNothing);
      expect(bNotice, findsNothing);
      expect(tester.widget<ChoiceChip>(bFullCredit).selected, isTrue);
      expect(find.text('The review could not be saved.'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final reopened = await KompassStore.open();
      final restored = reopened.attempts.single;
      expect(restored.score.toJson(), afterB.score.toJson());
      expect(restored.firstResponses, firstResponses);
      expect(restored.responses, latestResponses);
      expect(restored.firstScore.toJson(), firstScoreJson);
      expect(restored.revision, 4);
      await reopened.flush();
    },
  );
}
