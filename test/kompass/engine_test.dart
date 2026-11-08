import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/kompass/models/kompass_attempt.dart';
import 'package:space_math_academy/features/kompass/models/kompass_content.dart';
import 'package:space_math_academy/features/kompass/services/kompass_planner.dart';
import 'package:space_math_academy/features/kompass/services/kompass_scorer.dart';

const _words = {'de': 'Aufgabe', 'en': 'Task'};
const _skillIds = {
  'numbers': 'M-Z04',
  'geometry': 'M-R06',
  'measurement': 'M-G05',
  'data': 'M-D01',
};

Map<String, dynamic> _numberPart(String id, num answer,
        {String skill = 'M-Z04', String unit = ''}) =>
    {
      'id': id,
      'kind': 'number',
      'prompt': _words,
      'competencyIds': [skill],
      'maxPoints': 1,
      'answer': {'type': 'number', 'value': answer},
      if (unit.isNotEmpty) 'unit': unit,
    };

KompassTask _task({
  String id = 'addition',
  String family = 'addition_family',
  String domain = 'numbers',
  String use = 'practice',
  List<Map<String, dynamic>>? parts,
}) =>
    KompassTask.fromJson({
      'id': id,
      'familyId': family,
      'domain': domain,
      'title': _words,
      'prompt': _words,
      'level': 1,
      'use': use,
      'parts': parts ?? [_numberPart('a', 12, skill: _skillIds[domain]!)],
      'hints': [
        {'de': 'Zerlege die Zahl.', 'en': 'Split the number.'},
      ],
      'solution': {'de': 'Die Lösung ist 12.', 'en': 'The answer is 12.'},
      'source': {'kind': 'original'},
    });

KompassPack _pack({int perDomain = 10}) => KompassPack.fromJson({
      'schemaVersion': 2,
      'id': 'fixture',
      'version': '2.0.0',
      'source': {'kind': 'original'},
      'competencies': [
        for (final entry in _skillIds.entries)
          {
            'id': entry.value,
            'domain': entry.key,
            'title': _words,
            'goal': _words,
            'evidence': 'curriculum',
            'curriculumUrl': 'https://www.bildungsplaene-bw.de/',
            'gameKeys': <String>[],
          },
      ],
      'tasks': [
        for (final use in ['practice', 'check', 'rehearsal'])
          for (final domain in kompassDomains)
            for (var index = 0; index < perDomain; index++)
              _task(
                id: '${use}_${domain}_$index',
                family: '${use}_${domain}_$index',
                domain: domain,
                use: use,
              ).toJson(),
      ],
    });

KompassAttempt _attempt(KompassTask task,
        {String id = 'first',
        KompassMode mode = KompassMode.check,
        Map<String, dynamic> responses = const {'a': '12'},
        Map<String, dynamic>? finalResponses,
        int hints = 0,
        DateTime? at}) =>
    KompassAttempt.forTask(
      id: id,
      sessionId: 'session_$id',
      task: task,
      packVersion: '2.0.0',
      mode: mode,
      firstResponses: responses,
      responses: finalResponses,
      hintsUsed: hints,
      at: at ?? DateTime.utc(2026, 11, 8),
    );

void main() {
  group('Explicit scoring', () {
    test('keeps mixed answers separate instead of inheriting round success',
        () {
      final task = _task(parts: [
        _numberPart('first', 57),
        _numberPart('second', 19),
      ]);
      final score = KompassScorer.score(task, {'first': '57', 'second': '18'});
      expect(score.awardedPoints, 1);
      expect(score.maxPoints, 2);
      expect(score.partById('first')!.correct, isTrue);
      expect(score.partById('second')!.correct, isFalse);
      expect(score.fullyCorrect, isFalse);
    });

    test('accepts decimal comma and requested unit, rejects a different unit',
        () {
      final task = _task(parts: [_numberPart('price', 2.4, unit: '€')]);
      for (final answer in ['2,40', '2.4', '2,40 €', '2.4 EUR']) {
        expect(
            KompassScorer.score(task, {'price': answer}).fullyCorrect, isTrue,
            reason: answer);
      }
      for (final answer in [
        '240 ct',
        '2.4m',
        '2,4.0',
        '2e0',
        'NaN',
        'Infinity'
      ]) {
        expect(
            KompassScorer.score(task, {'price': answer}).fullyCorrect, isFalse,
            reason: answer);
      }
    });

    test('normalizes Unicode minus but does not silently parse grouping', () {
      expect(KompassScorer.parseNumber('−12'), -12);
      expect(KompassScorer.parseNumber('1 000'), isNull);
      expect(KompassScorer.parseNumber('1.000,5'), isNull);
      expect(KompassScorer.parseNumber(double.nan), isNull);
      expect(KompassScorer.parseNumber('4.0 cm', unit: 'cm'), 4);
      expect(KompassScorer.parseNumber('12 cm²', unit: 'cm²'), 12);
      expect(KompassScorer.parseNumber('12 cm2', unit: 'cm²'), 12);
      expect(KompassScorer.parseNumber('4.0 m', unit: 'cm'), isNull);
    });

    test('reports authored misconception feedback only for matching answers',
        () {
      final part = _numberPart('additional', 2)
        ..['errors'] = [
          {
            'value': '3',
            'code': 'total_instead_of_added',
            'feedback': {
              'de': 'Wie viele kommen dazu?',
              'en': 'How many must be added?',
            },
          },
        ];
      final task = _task(parts: [part]);
      final wrong = KompassScorer.score(task, {'additional': 3}).parts.single;
      expect(wrong.errorCode, 'total_instead_of_added');
      expect(kompassText(wrong.feedback, false), 'How many must be added?');
      expect(
          KompassScorer.score(task, {'additional': 7}).parts.single.errorCode,
          'incorrect');
    });

    test('carried-error credit preserves the difference from a correct answer',
        () {
      final second = _numberPart('bottom', 260)
        ..['carryFrom'] = 'middle'
        ..['carryOffset'] = -180;
      final task = _task(parts: [_numberPart('middle', 440), second]);
      final score = KompassScorer.score(task, {'middle': 430, 'bottom': 250});
      expect(score.awardedPoints, 1);
      expect(score.partById('bottom')!.carriedError, isTrue);
      expect(score.partById('bottom')!.correct, isFalse);
      expect(score.fullyCorrect, isFalse);
      expect(
          KompassScorer.score(task, {'middle': 100, 'bottom': -80})
              .awardedPoints,
          0);
      expect(KompassScorer.score(task, {'bottom': 250}).awardedPoints, 0);
    });

    test(
        'sets accept any ordering and explicit alternatives, not duplicate taps',
        () {
      final task = _task(parts: [
        {
          'id': 'net',
          'kind': 'cells',
          'prompt': _words,
          'competencyIds': ['M-Z04'],
          'maxPoints': 2,
          'answer': {
            'type': 'set',
            'values': ['0,1', '1,1'],
            'alternatives': [
              ['1,2', '2,2'],
            ],
          },
        },
      ]);
      expect(
          KompassScorer.score(task, {
            'net': ['1,1', '0,1']
          }).fullyCorrect,
          isTrue);
      expect(
          KompassScorer.score(task, {
            'net': ['2,2', '1,2']
          }).fullyCorrect,
          isTrue);
      expect(
          KompassScorer.score(task, {
            'net': ['0,1', '1,1', '1,1']
          }).fullyCorrect,
          isFalse);
      expect(
          KompassScorer.score(task, {
            'net': ['0,1']
          }).awardedPoints,
          0);
    });

    test('money follow-through keeps valid cents despite a whole-euro answer',
        () {
      final remaining = _numberPart('game', 8, unit: '€')
        ..['carryFrom'] = 'spent'
        ..['carryOffset'] = -4.5;
      final task =
          _task(parts: [_numberPart('spent', 12.5, unit: '€'), remaining]);
      final score =
          KompassScorer.score(task, {'spent': '12,00 €', 'game': '7,50 €'});
      expect(score.partById('spent')!.correct, isFalse);
      expect(score.partById('game')!.carriedError, isTrue);
      expect(score.awardedPoints, 1);
      expect(
          KompassScorer.score(task, {'spent': '12,001', 'game': '7,501'})
              .awardedPoints,
          0);
    });

    test('partial set credit penalizes extra wrong selections', () {
      final task = _task(parts: [
        {
          'id': 'axes',
          'kind': 'cells',
          'prompt': _words,
          'competencyIds': ['M-Z04'],
          'maxPoints': 2,
          'answer': {
            'type': 'set',
            'values': ['a', 'b'],
            'partialCredit': true
          },
        },
      ]);
      expect(
          KompassScorer.score(task, {
            'axes': ['a']
          }).awardedPoints,
          1);
      expect(
          KompassScorer.score(task, {
            'axes': ['a', 'b', 'x', 'y']
          }).awardedPoints,
          0);
    });

    test('an explicitly empty set differs from an unanswered item', () {
      final task = _task(parts: [
        {
          'id': 'axes',
          'kind': 'cells',
          'prompt': _words,
          'competencyIds': ['M-Z04'],
          'maxPoints': 1,
          'answer': {'type': 'set', 'values': <String>[]},
        },
      ]);
      expect(
          KompassScorer.score(task, {'axes': <String>[]}).fullyCorrect, isTrue);
      expect(KompassScorer.score(task, {}).parts.single.attempted, isFalse);
    });

    test('ordered answers must match the order, not only the members', () {
      final task = _task(parts: [
        {
          'id': 'steps',
          'kind': 'order',
          'prompt': _words,
          'competencyIds': ['M-Z04'],
          'maxPoints': 1,
          'answer': {
            'type': 'sequence',
            'values': ['read', 'model', 'solve', 'check']
          },
        },
      ]);
      expect(
          KompassScorer.score(task, {
            'steps': ['read', 'model', 'solve', 'check'],
          }).fullyCorrect,
          isTrue);
      expect(
          KompassScorer.score(task, {
            'steps': ['read', 'solve', 'model', 'check'],
          }).fullyCorrect,
          isFalse);
    });

    test('explanations wait for rubric review rather than string matching', () {
      final task = _task(parts: [
        {
          'id': 'why',
          'kind': 'text',
          'prompt': _words,
          'competencyIds': ['M-Z04'],
          'maxPoints': 2,
          'answer': {'type': 'manual', 'criteria': _words},
        },
      ]);
      final raw = KompassScorer.score(
          task, {'why': 'The middle value is counted twice.'});
      expect(raw.pendingReview, isTrue);
      expect(raw.pendingPoints, 2);
      expect(raw.parts.single.correct, isFalse);
      final reviewed = KompassScorer.score(task, {'why': 'My explanation'},
          manualPoints: {'why': 1});
      expect(reviewed.pendingReview, isFalse);
      expect(reviewed.awardedPoints, 1);
      expect(reviewed.parts.single.manual, isTrue);
      expect(reviewed.parts.single.reviewed, isTrue);
      expect(
          () => KompassScorer.score(task, {'why': 'Explanation'},
              manualPoints: {'why': 3}),
          throwsArgumentError);
      expect(KompassScorer.score(task, {}).parts.single.attempted, isFalse);
    });
  });

  group('Immutable evidence and honest progress', () {
    test('first responses and their nested selections are deep snapshots', () {
      final task = _task();
      final selection = <String>['first'];
      final answers = <String, dynamic>{'a': '12', 'extra': selection};
      final attempt = _attempt(task, responses: answers);
      answers['a'] = '999';
      selection.add('second');
      expect(attempt.firstResponses['a'], '12');
      expect(attempt.firstResponses['extra'], ['first']);
      expect(() => attempt.firstResponses['a'] = '0', throwsUnsupportedError);
    });

    test('a correction preserves the original incorrect score', () {
      final task = _task();
      final initial = _attempt(task, responses: const {'a': '11'});
      final corrected = initial.reviseTask(
          task: task, responses: {'a': '12'}, hintsUsed: 1, activeSeconds: 90);
      expect(corrected.firstScore.fullyCorrect, isFalse);
      expect(corrected.score.fullyCorrect, isTrue);
      expect(corrected.firstResponses['a'], '11');
      expect(corrected.responses['a'], '12');
      expect(
          KompassAttempt.fromJson(jsonDecode(jsonEncode(corrected.toJson())))
              .firstScore
              .fullyCorrect,
          isFalse);
      expect(
          () => initial.copyWith(responses: {'a': '12'}), throwsArgumentError);
    });

    test('practice content cannot become independent through its screen mode',
        () {
      final misplaced = _attempt(_task(use: 'practice'));
      expect(misplaced.score.fullyCorrect, isTrue);
      expect(misplaced.contentUse, 'practice');
      expect(misplaced.verified, isFalse);
      expect(
          KompassAttempt.fromJson(jsonDecode(jsonEncode(misplaced.toJson())))
              .verified,
          isFalse);
    });

    test('later hints are retained without replacing first-submission evidence',
        () {
      final task = _task(use: 'check');
      final first = _attempt(task);
      final revised =
          first.reviseTask(task: task, responses: {'a': '12'}, hintsUsed: 1);
      expect(revised.verified, isTrue);
      expect(revised.assisted, isTrue);
      expect(revised.hintsBeforeFirstResponse, 0);
    });

    test(
        'assisted checks and all lab outcomes cannot become independent evidence',
        () {
      final task = _task();
      expect(_attempt(task, hints: 1).verified, isFalse);
      expect(_attempt(task, mode: KompassMode.practice).verified, isFalse);
      final lab = KompassAttempt.forLab(id: 'lab1', packVersion: '2', result: {
        'labId': 'number_dock',
        'roundId': 'r1',
        'skillIds': ['M-Z04'],
        'firstCorrect': true,
        'hintsUsed': 0,
        'activeSeconds': 20,
        'response': '12',
        'maxPoints': 1,
        'awardedPoints': 1,
      });
      expect(lab.score.fullyCorrect, isTrue);
      expect(lab.mode, KompassMode.lab);
      expect(lab.verified, isFalse);
    });

    test('labs retain partial first work separately from eventual completion',
        () {
      final first = <String, dynamic>{'a': 12, 'b': 10};
      final last = <String, dynamic>{'a': 12, 'b': 11};
      final lab =
          KompassAttempt.forLab(id: 'lab:partial', packVersion: '2', result: {
        'labId': 'number_dock',
        'roundId': 'partial',
        'skillIds': ['M-Z04'],
        'firstCorrect': false,
        'hintsUsed': 1,
        'activeSeconds': 35,
        'response': first,
        'finalResponse': last,
        'completedCorrect': true,
        'maxPoints': 2,
        'awardedPoints': 1,
      });
      first['a'] = 0;
      last['b'] = 0;
      expect(lab.firstScore.awardedPoints, 1);
      expect(lab.firstScore.fullyCorrect, isFalse);
      expect(lab.score.awardedPoints, 2);
      expect(lab.score.fullyCorrect, isTrue);
      expect(lab.firstResponses['lab'], {'a': 12, 'b': 10});
      expect(lab.responses['lab'], {'a': 12, 'b': 11});
      expect(lab.verified, isFalse);
    });

    test('manual work cannot promote a skill through another automated part',
        () {
      final pack = _pack();
      final attempts = <KompassAttempt>[];
      for (var index = 0; index < 2; index++) {
        final task = _task(
            id: 'mixed_$index',
            family: 'mixed_$index',
            use: 'check',
            parts: [
              _numberPart('sum', 12),
              {
                'id': 'explanation',
                'kind': 'text',
                'prompt': _words,
                'competencyIds': ['M-Z04'],
                'maxPoints': 1,
                'answer': {'type': 'manual', 'criteria': _words},
              },
              _numberPart('shape', 4, skill: 'M-R06'),
            ]);
        final answers = {'sum': '12', 'explanation': 'My method', 'shape': '4'};
        attempts.add(_attempt(task, id: 'mixed_$index', responses: answers)
            .reviseTask(
                task: task,
                responses: answers,
                manualPoints: {'explanation': 1}));
      }
      final statuses = KompassPlanner.progress(pack, attempts,
          now: DateTime.utc(2026, 11, 9));
      expect(statuses['M-Z04']!.manualReviews, 2);
      expect(statuses['M-Z04']!.independentCorrect, 0);
      expect(statuses['M-Z04']!.state, KompassProgressState.practising);
      expect(statuses['M-R06']!.independentCorrect, 2);
      expect(statuses['M-R06']!.state, KompassProgressState.independent);
    });

    test('two distinct independent families support a dated observation', () {
      final pack = _pack();
      final first = _attempt(pack.taskById('check_numbers_0')!);
      final second = _attempt(pack.taskById('rehearsal_numbers_0')!,
          id: 'second',
          mode: KompassMode.rehearsal,
          at: DateTime.utc(2026, 11, 9));
      final one = KompassPlanner.progress(pack, [first],
          now: DateTime.utc(2026, 11, 9))['M-Z04']!;
      expect(one.state, KompassProgressState.practising);
      final two = KompassPlanner.progress(pack, [first, second],
          now: DateTime.utc(2026, 11, 10))['M-Z04']!;
      expect(two.state, KompassProgressState.independent);
      expect(two.independentCorrect, 2);
      final later = KompassPlanner.progress(pack, [first, second],
          now: DateTime.utc(2026, 11, 17))['M-Z04']!;
      expect(later.state, KompassProgressState.reviewDue);
    });

    test('repeated source families and duplicate IDs do not inflate evidence',
        () {
      final pack = _pack();
      final task = pack.taskById('check_numbers_0')!;
      final first = _attempt(task);
      final repeated =
          _attempt(task, id: 'repeat', at: DateTime.utc(2026, 11, 9));
      final result = KompassPlanner.progress(pack, [first, first, repeated],
          now: DateTime.utc(2026, 11, 10))['M-Z04']!;
      expect(result.attempts, 2);
      expect(result.independentAttempts, 1);
      expect(result.state, KompassProgressState.practising);
    });

    test('a later independent error returns the skill to practice', () {
      final pack = _pack();
      final attempts = [
        _attempt(pack.taskById('check_numbers_0')!, id: 'a'),
        _attempt(pack.taskById('check_numbers_1')!,
            id: 'b', at: DateTime.utc(2026, 11, 9)),
        _attempt(pack.taskById('check_numbers_2')!,
            id: 'c', responses: {'a': '13'}, at: DateTime.utc(2026, 11, 10)),
      ];
      final result = KompassPlanner.progress(pack, attempts,
          now: DateTime.utc(2026, 11, 11))['M-Z04']!;
      expect(result.independentCorrect, 2);
      expect(result.state, KompassProgressState.practising);
    });

    test('planner holds out seen families and balances a 20-item session', () {
      final pack = _pack();
      final session = KompassPlanner.selectSession(pack, [],
          mode: KompassMode.check, exposedFamilies: {'check_numbers_0'});
      expect(session, hasLength(20));
      expect(session.map((t) => t.familyId).toSet(), hasLength(20));
      expect(session.any((t) => t.familyId == 'check_numbers_0'), isFalse);
      expect(session.where((t) => t.domain == 'numbers'), hasLength(8));
      expect(session.where((t) => t.domain == 'geometry'), hasLength(5));
      expect(session.where((t) => t.domain == 'measurement'), hasLength(4));
      expect(session.where((t) => t.domain == 'data'), hasLength(3));
      expect(session.every((t) => t.use == 'check'), isTrue);
    });

    test(
        'exhausted check families produce an empty result, not recycled questions',
        () {
      final pack = _pack(perDomain: 1);
      final seen = pack.tasks
          .where((t) => t.use == 'check')
          .map((t) => t.familyId)
          .toSet();
      expect(
          KompassPlanner.selectSession(pack, [],
              mode: KompassMode.check, exposedFamilies: seen),
          isEmpty);
      expect(
          KompassPlanner.nextPractice(pack, [], domain: 'measurement')!.domain,
          'measurement');
    });
  });

  group('Bundled content contract', () {
    test(
        'loads all competencies and keeps practice separate from held-out families',
        () {
      final pack = KompassPack.fromJson(
          jsonDecode(File('assets/kompass/math_v2.json').readAsStringSync()));
      expect(pack.competencies, hasLength(32));
      expect(pack.tasks.length, greaterThanOrEqualTo(128));
      for (final skill in pack.competencies) {
        for (final use in ['practice', 'check', 'rehearsal']) {
          expect(
              pack.tasks.any((task) =>
                  task.use == use && task.competencyIds.contains(skill.id)),
              isTrue,
              reason: '${skill.id} needs $use content');
        }
      }
      final families = <String, Set<String>>{};
      for (final task in pack.tasks) {
        families.putIfAbsent(task.familyId, () => {}).add(task.use);
      }
      expect(families.values.every((uses) => uses.length == 1), isTrue);
    });
  });
}
