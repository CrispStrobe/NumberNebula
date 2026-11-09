import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/kompass/labs/extensions/chance_rounds.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_screen.dart';
import 'package:space_math_academy/features/kompass/models/kompass_attempt.dart';

const _lab = 'chance_detective';
const _storageKey = 'kompass_lab_v1_$_lab';

Widget _app(void Function(Map<String, dynamic>) onCompleted) => MaterialApp(
      home: KompassLabScreen(
          labId: _lab, german: false, onCompleted: onCompleted),
    );

Future<void> _tap(WidgetTester tester, String key) async {
  final control = find.byKey(ValueKey(key));
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _state(WidgetTester tester) => tester
    .state<KompassLabScreenState>(find.byType(KompassLabScreen))
    .exportState();

void main() {
  var profileNumber = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'lab-assistance-${profileNumber++}';
  });
  tearDown(() => ProfilePreferences.activeId = 'default');

  testWidgets(
    'later hints do not rewrite an unaided first response across reload',
    (tester) async {
      final events = <Map<String, dynamic>>[];
      final prefs = await ProfilePreferences.getInstance();
      final round = generateChanceDetectiveRound(1, 417);
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'schemaVersion': 1,
          'labId': _lab,
          'sessionId': 'assistance-fixture',
          'seed': 417,
          'index': 1,
          'response': createChanceDetectiveResponse(round),
          'firstResponse': <String, dynamic>{},
          'activeMillis': 0,
          'attempts': 0,
          'hintsUsed': 0,
          'completed': false,
          'reported': false,
        }),
      );
      await tester.pumpWidget(_app(events.add));
      await tester.pumpAndSettle();

      // This round claims that at least one draw must be a star. Star/circle
      // is legal, but supports the claim instead of disproving it.
      await _tap(tester, 'chance_first_star');
      await _tap(tester, 'chance_second_circle');
      await _tap(tester, 'chance_reason_exception');
      await _tap(tester, 'lab_check');
      const firstResponse = {
        'first': 'star',
        'second': 'circle',
        'reason': 'exception',
      };
      expect(events, isEmpty);
      expect(_state(tester)['firstCorrect'], isFalse);
      expect(_state(tester)['firstPoints'], 2);
      expect(_state(tester)['firstResponse'], firstResponse);
      expect(_state(tester)['hintsBeforeFirstResponse'], 0);

      await _tap(tester, 'lab_hint');
      final roundId = _state(tester)['roundId'];
      expect(_state(tester)['hintsUsed'], 1);
      expect(_state(tester)['hintsBeforeFirstResponse'], 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final saved = jsonDecode(prefs.getString(_storageKey)!) as Map;
      expect(saved['hintsUsed'], 1);
      expect(saved['hintsBeforeFirstResponse'], 0);

      await tester.pumpWidget(_app(events.add));
      await tester.pumpAndSettle();
      expect(_state(tester)['roundId'], roundId);
      expect(_state(tester)['attempts'], 1);
      expect(_state(tester)['firstResponse'], firstResponse);
      expect(_state(tester)['hintsUsed'], 1);
      expect(_state(tester)['hintsBeforeFirstResponse'], 0);

      // At least two circles are available in this recipe, so circle/circle
      // is a legal counterexample with either replacement policy.
      await _tap(tester, 'chance_first_circle');
      await _tap(tester, 'lab_check');
      expect(events, hasLength(1));
      final result = events.single;
      expect(result['firstCorrect'], isFalse);
      expect(result['awardedPoints'], 2);
      expect(result['completedCorrect'], isTrue);
      expect(result['hintsUsed'], 1);
      expect(result['hintsBeforeFirstResponse'], 0);
      expect(result['response'], firstResponse);
      expect((result['finalResponse'] as Map)['first'], 'circle');

      final attempt = KompassAttempt.forLab(
        id: 'assistance-attempt',
        result: result,
        packVersion: '2.1.0',
      );
      expect(attempt.hintsBeforeFirstResponse, 0);
      expect(attempt.hintsUsed, 1);
      expect(attempt.firstResponses['lab'], firstResponse);
      expect(attempt.firstScore.parts.single.correct, isFalse);
      expect(attempt.score.parts.single.correct, isTrue);
      expect(attempt.verified, isFalse);
      final restoredAttempt = KompassAttempt.fromJson(attempt.toJson());
      expect(restoredAttempt.hintsBeforeFirstResponse, 0);
      expect(restoredAttempt.hintsUsed, 1);

      // The first-response count belongs to one round, not the whole lab.
      await _tap(tester, 'lab_next');
      expect(_state(tester)['hintsUsed'], 0);
      expect(_state(tester)['attempts'], 0);
      await _tap(tester, 'lab_hint');
      await _tap(tester, 'lab_check');
      expect(_state(tester)['hintsBeforeFirstResponse'], 1);
      expect(_state(tester)['hintsUsed'], 1);
      expect(events, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  test(
    'legacy lab completions conservatively retain all hints as first support',
    () {
      final legacyResult = <String, dynamic>{
        'labId': _lab,
        'roundId': 'legacy-round',
        'skillIds': ['M-D04'],
        'firstCorrect': false,
        'completedCorrect': true,
        'maxPoints': 3,
        'awardedPoints': 2,
        'hintsUsed': 2,
        'response': {
          'first': 'star',
          'second': 'circle',
          'reason': 'exception',
        },
        'finalResponse': {
          'first': 'circle',
          'second': 'circle',
          'reason': 'exception',
        },
      };
      expect(legacyResult.containsKey('hintsBeforeFirstResponse'), isFalse);
      final attempt = KompassAttempt.forLab(
        id: 'legacy-assistance',
        result: legacyResult,
        packVersion: '2.0.1',
      );
      expect(attempt.hintsBeforeFirstResponse, 2);
      expect(attempt.hintsUsed, 2);
      expect(attempt.assisted, isTrue);
      expect(attempt.verified, isFalse);
    },
  );
}
