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
    final rightThenWrong = KompassScorer.score(task, {'a': '12', 'b': '3'});
    expect(rightThenWrong.partById('b')!.pendingReview, isFalse);
    expect(rightThenWrong.partById('b')!.awardedPoints, 0);
  });

  test('euro answers accept cents and count words are optional', () {
    expect(KompassScorer.parseNumber('200 ct', unit: '€'), 2);
    expect(KompassScorer.parseNumber('2 € 5 ct', unit: '€'), 2.05);
    expect(KompassScorer.parseNumber('2 cm', unit: '€'), isNull);
    final labelled = _pack()
        .tasks
        .where((t) => t.use == 'original')
        .expand((t) => t.parts)
        .firstWhere((p) => p.unit == 'Kinder');
    expect(KompassScorer.parseNumber('9 Kinder', unit: labelled.unit), 9);
    expect(KompassScorer.parseNumber('9', unit: labelled.unit), 9);
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
    final task = _pack().taskById('k4_m4_14')!;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: KompassFigureView(
                    figure: task.figure!, german: true, plain: true)))));
    expect(find.byKey(const ValueKey('kompass_figure_stack')), findsOneWidget);
    expect(find.text('Eine Packung mit 3 Heften'), findsOneWidget);
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
