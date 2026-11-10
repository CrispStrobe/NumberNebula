import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/kompass/models/kompass_content.dart';
import 'package:space_math_academy/features/kompass/services/kompass_planner.dart';
import 'package:space_math_academy/features/kompass/services/kompass_repository.dart';
import 'package:space_math_academy/features/kompass/services/kompass_scorer.dart';
import 'package:space_math_academy/features/kompass/widgets/kompass_figure_view.dart';
import 'package:space_math_academy/features/kompass/models/kompass_attempt.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

KompassPack _pack() => KompassRepository.fromJson(KompassRepository.merge(
    _read(KompassRepository.assetPath),
    _read(KompassRepository.originalAssetPath)));

/// A response that the answer contract accepts for each automatic part.
dynamic _correct(KompassPart part) => switch (part.answer['type']) {
      'number' => '${part.answer['value']}'.replaceAll('.', ','),
      'choice' => part.answer['value'],
      'set' || 'sequence' => List<String>.from(part.answer['values'] as List),
      'text' => (part.answer['values'] as List).first,
      _ => 'auf Papier',
    };

void main() {
  test('six original papers load beside the course without joining its sets',
      () {
    final pack = _pack();
    final main = KompassRepository.fromJson(_read(KompassRepository.assetPath));
    expect(pack.papers.map((p) => p.id),
        ['mathe1', 'mathe2', 'mathe3', 'mathe4', 'mathe5', 'mathe6']);
    final originals = pack.tasks.where((t) => t.use == 'original').toList();
    expect(originals, hasLength(120));
    expect(pack.tasks.length, main.tasks.length + 120);
    expect(pack.version, startsWith(main.version));
    for (final paper in pack.papers) {
      final tasks = paper.taskIds.map(pack.taskById).toList();
      expect(tasks, everyElement(isNotNull));
      expect(tasks.fold<double>(0, (sum, task) => sum + task!.maxPoints),
          paper.totalPoints,
          reason: paper.id);
      expect(paper.totalSeconds, 45 * 60);
      expect(paper.printUrl, contains('/raw/'));
    }
    for (final mode in [KompassMode.practice, KompassMode.check]) {
      final selected =
          KompassPlanner.selectSession(pack, const [], mode: mode, count: 40);
      expect(selected.where((t) => t.use == 'original'), isEmpty);
    }
  });

  test('every automatic part accepts its keyed answer; nothing is pre-filled',
      () {
    for (final task in _pack().tasks.where((t) => t.use == 'original')) {
      final responses = {
        for (final part in task.parts) part.id: _correct(part)
      };
      final score = KompassScorer.score(task, responses);
      for (final part in task.parts) {
        final result = score.partById(part.id)!;
        if (part.isManual) {
          expect(result.pendingReview, isTrue, reason: '${task.id}/${part.id}');
        } else {
          expect(result.correct, isTrue, reason: '${task.id}/${part.id}');
        }
      }
      final empty = KompassScorer.score(task, const {});
      expect(empty.awardedPoints, 0);
    }
  });

  test('a follow-on step after a wrong answer goes to review, not to zero', () {
    final task = _pack().taskById('k4_m4_14')!;
    final wrongThenWrong = KompassScorer.score(task, {'a': '13', 'b': '3'});
    expect(wrongThenWrong.partById('a')!.correct, isFalse);
    expect(wrongThenWrong.partById('b')!.pendingReview, isTrue);
    final reviewed = KompassScorer.score(task, {'a': '13', 'b': '3'},
        manualPoints: {'b': 1});
    expect(reviewed.partById('b')!.awardedPoints, 1);
    expect(reviewed.partById('b')!.reviewed, isTrue);
    final reviewedPart = KompassScorer.reviewPart(task, {'a': '13', 'b': '3'},
        previousScore: wrongThenWrong, partId: 'b', points: 1);
    expect(reviewedPart.partById('b')!.awardedPoints, 1);
    expect(reviewedPart.partById('b')!.reviewed, isTrue);
    final rightThenWrong = KompassScorer.score(task, {'a': '12', 'b': '3'});
    expect(rightThenWrong.partById('b')!.pendingReview, isFalse);
    expect(rightThenWrong.partById('b')!.awardedPoints, 0);
  });

  test('euro answers accept cents and count words are optional', () {
    expect(
        KompassScorer.parseNumber('200 ct', unit: '€', acceptCents: true), 2);
    expect(KompassScorer.parseNumber('2 € 5 ct', unit: '€', acceptCents: true),
        2.05);
    expect(KompassScorer.parseNumber('200 ct', unit: '€'), isNull);
    final euro = _pack().taskById('k4_m4_14')!;
    expect(KompassScorer.score(euro, {'a': '1200 ct', 'b': '2 €'}).fullyCorrect,
        isTrue);
    final labelled = _pack()
        .tasks
        .where((t) => t.use == 'original')
        .expand((t) => t.parts)
        .firstWhere((p) => p.unit == 'Kinder');
    expect(KompassScorer.parseNumber('9 Kinder', unit: labelled.unit), 9);
    expect(KompassScorer.parseNumber('9', unit: labelled.unit), 9);
  });

  test('original paper review accepts only the declared rubric steps', () {
    final pack = _pack();
    for (final (taskId, partId, allowed, disallowed) in [
      ('k4_m1_11', 'b', <double>[0, 1], <double>[.5]),
      ('k4_m3_09', 'a', <double>[0, 1, 2], <double>[.5, 1.5]),
    ]) {
      final task = pack.taskById(taskId)!;
      final part = task.parts.singleWhere((part) => part.id == partId);
      expect(part.reviewPointOptions, allowed);
      for (final points in allowed) {
        final score = KompassScorer.score(task, {partId: 'auf Papier'},
            manualPoints: {partId: points}).partById(partId)!;
        expect(score.awardedPoints, points);
        expect(score.reviewed, isTrue);
        expect(score.pendingReview, isFalse);
      }
      for (final points in [...disallowed, -1.0, part.maxPoints + 1]) {
        expect(
            () => KompassScorer.score(task, {partId: 'auf Papier'},
                manualPoints: {partId: points}),
            throwsArgumentError,
            reason: '$taskId/$partId must reject $points');
      }
    }
  });

  test('declared review steps are validated before displaying controls', () {
    final part = _pack()
        .taskById('k4_m1_11')!
        .parts
        .singleWhere((part) => part.id == 'b');
    Map<String, dynamic> withSteps(Object? steps) => {
          ...part.toJson(),
          'answer': {...part.answer, 'creditSteps': steps},
        };
    for (final invalid in [
      null,
      <num>[],
      [0, 1.5],
      [0, double.nan, 1],
      [0, 1, 1],
      [0, .5],
      [.5, 1],
      [0, '1'],
    ]) {
      expect(() => KompassPart.fromJson(withSteps(invalid)),
          throwsFormatException);
    }
    expect(KompassPart.fromJson(withSteps([1, 0])).reviewPointOptions,
        <double>[0, 1]);
  });

  test('course rubrics without declared steps retain the prior fallback', () {
    final task = _pack().taskById('mz06_write_sharing_story')!;
    final part = task.parts.singleWhere((part) => part.id == 'story');
    expect(part.answer.containsKey('creditSteps'), isFalse);
    expect(part.reviewPointOptions, <double>[0, .5, 1, 1.5, 2]);
    for (final points in [1.5, 1.25]) {
      final result = KompassScorer.score(task, {'story': 'on paper'},
          manualPoints: {'story': points}).partById('story')!;
      expect(result.awardedPoints, points);
      expect(result.reviewed, isTrue);
    }
    for (final invalid in [-1.0, 2.5, double.nan, double.infinity]) {
      expect(
          () => KompassScorer.score(task, {'story': 'on paper'},
              manualPoints: {'story': invalid}),
          throwsArgumentError);
    }
  });

  test('restoring an earlier review does not rewrite stored points or evidence',
      () {
    final pack = _pack();
    final task = pack.taskById('k4_m1_11')!;
    final attempt = KompassAttempt.forTask(
      id: 'historical-review',
      sessionId: 'historical-paper',
      task: task,
      packVersion: pack.version,
      mode: KompassMode.practice,
      firstResponses: {'a': '2', 'b': 'auf Papier'},
      manualPoints: {'b': 0},
    );
    final saved = _copyJson(attempt.toJson());
    final prior = ((saved['score'] as Map)['parts'] as List)
        .cast<Map>()
        .singleWhere((part) => part['partId'] == 'b');
    // This score could be saved before declared rubric steps were enforced.
    prior['awardedPoints'] = .5;
    final restored = KompassAttempt.fromJson(saved);
    expect(restored.score.partById('b')!.awardedPoints, .5);
    expect(restored.firstResponses, attempt.firstResponses);
    expect(restored.firstScore.toJson(), attempt.firstScore.toJson());
    expect(restored.toJson(), saved);
  });

  test('reviewing one part preserves another historical out-of-step score', () {
    final pack = _pack();
    final task = pack.taskById('k4_m2_11')!;
    final attempt = KompassAttempt.forTask(
      id: 'historical-two-part-review',
      sessionId: 'historical-paper',
      task: task,
      packVersion: pack.version,
      mode: KompassMode.practice,
      firstResponses: {'a': 'auf Papier', 'b': 'auf Papier'},
      manualPoints: {'a': 0, 'b': 0},
    );
    final saved = _copyJson(attempt.toJson());
    for (final part in (saved['score'] as Map)['parts'] as List) {
      (part as Map)['awardedPoints'] = .5;
    }
    final restored = KompassAttempt.fromJson(saved);
    final firstReview = restored.copyWith(
      score: KompassScorer.reviewPart(task, restored.responses,
          previousScore: restored.score, partId: 'a', points: 1),
    );
    expect(firstReview.score.partById('a')!.awardedPoints, 1);
    expect(firstReview.score.partById('b')!.toJson(),
        restored.score.partById('b')!.toJson());
    expect(firstReview.firstResponses, restored.firstResponses);
    expect(firstReview.firstScore.toJson(), restored.firstScore.toJson());
    expect(firstReview.revision, restored.revision + 1);
    expect(
        () => KompassScorer.reviewPart(task, firstReview.responses,
            previousScore: firstReview.score, partId: 'b', points: .5),
        throwsArgumentError);
    final secondReview = firstReview.copyWith(
      score: KompassScorer.reviewPart(task, firstReview.responses,
          previousScore: firstReview.score, partId: 'b', points: 1),
    );
    expect(secondReview.score.partById('b')!.awardedPoints, 1);
    expect(secondReview.score.partById('a')!.toJson(),
        firstReview.score.partById('a')!.toJson());
    expect(secondReview.firstResponses, restored.firstResponses);
    expect(secondReview.firstScore.toJson(), restored.firstScore.toJson());
    expect(secondReview.revision, restored.revision + 2);
    for (final oldPoints in [.5, 1.5]) {
      final changedScale = _copyJson(saved);
      final prior = ((changedScale['score'] as Map)['parts'] as List)
          .cast<Map>()
          .singleWhere((part) => part['partId'] == 'b');
      prior['maxPoints'] = 2;
      prior['awardedPoints'] = oldPoints;
      final different = KompassAttempt.fromJson(changedScale);
      expect(
          () => KompassScorer.reviewPart(task, different.responses,
              previousScore: different.score, partId: 'a', points: 1),
          throwsArgumentError,
          reason: 'A mismatched scale or out-of-range score cannot be carried');
    }
  });

  test('unit words, count-word aliases and answer spacing match kompass4', () {
    expect(KompassScorer.parseNumber('18 Minuten', unit: 'min'), 18);
    expect(KompassScorer.parseNumber('11 Euro', unit: '€'), 11);
    expect(KompassScorer.parseNumber('18 Stunden', unit: 'min'), isNull);
    final pack = _pack();
    final squares = pack.taskById('k4_m5_10')!.parts.first;
    expect(squares.unit, 'Quadraten');
    for (final written in ['9', '9 Quadraten', '9 Quadrate', '9  quadrate']) {
      expect(
          KompassScorer.score(pack.taskById('k4_m5_10')!, {squares.id: written})
              .partById(squares.id)!
              .correct,
          isTrue,
          reason: written);
    }
    expect(
        KompassScorer.score(pack.taskById('k4_m5_10')!, {squares.id: '9 cm'})
            .partById(squares.id)!
            .correct,
        isFalse);
    final tall = pack.taskById('k4_m4_12')!;
    final view = tall.parts.firstWhere((p) => p.id == 'b');
    for (final written in ['2 Würfel hoch', '2 Würfel', '2']) {
      expect(KompassScorer.score(tall, {view.id: written}).partById('b')!.correct,
          isTrue,
          reason: written);
    }
    final rope = pack.taskById('k4_m6_15')!;
    for (final written in ['1m50cm', '1 m 50 cm.', '1 M 50 CM']) {
      expect(KompassScorer.score(rope, {'a': '150', 'b': written})
          .partById('b')!
          .correct, isTrue, reason: written);
    }
  });

  test('every referenced diagram is bundled', () {
    final assets = <String>{};
    void collect(dynamic value) {
      if (value is Map) {
        if (value['asset'] is String) assets.add(value['asset'] as String);
        value.values.forEach(collect);
      } else if (value is List) {
        value.forEach(collect);
      }
    }

    collect(_read(KompassRepository.originalAssetPath));
    expect(assets, isNotEmpty);
    for (final asset in assets) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  testWidgets('an original task stem renders its text, table and diagram',
      (tester) async {
    Future<void> show(Map<String, dynamic> figure) => tester.pumpWidget(
        MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: KompassFigureView(
                        figure: figure, german: true, plain: true)))));
    // m4_14: the intro is the prompt, the price table is the figure, and
    // part b's question lives only in its part prompt (not twice).
    final prices = _pack().taskById('k4_m4_14')!;
    expect(prices.prompt['de'], startsWith('Sam braucht genau sechs Hefte.'));
    expect(prices.figure!['kind'], 'table');
    await show(prices.figure!);
    expect(find.text('Eine Packung mit 3 Heften'), findsOneWidget);
    final stacked = _pack()
        .tasks
        .firstWhere((t) => t.use == 'original' && t.figure?['kind'] == 'stack');
    await show(stacked.figure!);
    expect(find.byKey(const ValueKey('kompass_figure_stack')), findsOneWidget);
    final image = _pack()
        .tasks
        .firstWhere((t) => t.use == 'original' && t.figure?['kind'] == 'image');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: KompassFigureView(
                figure: image.figure!, german: true, plain: true))));
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _copyJson(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
