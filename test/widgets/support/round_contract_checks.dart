import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';

import 'round_dialog_finder.dart';

typedef RoundApp = ({GameProvider gp, ValueNotifier<bool> motion});

/// Behavioral checks shared by the four grid audits. Solutions come from the
/// rule model (or an independently validated fixture), never tray order.
void registerGridRoundChecks({
  required Future<RoundApp> Function(WidgetTester, bool) mount,
  required dynamic Function(WidgetTester) state,
  required Map<String, dynamic> Function(WidgetTester) snapshot,
  required Map<Object, int> Function(dynamic) solution,
  required bool Function(dynamic, Map<Object, int>) valid,
  required void Function(dynamic, Object, int) place,
  required String answersKey,
  required String movesKey,
  required String poolKey,
  required String maxMovesKey,
  required String optimalKey,
  required String shape,
  bool reusable = false,
  bool boardDrop = false,
}) {
  var lastDragDescription = '';

  Future<void> restore(WidgetTester t, Map<String, dynamic> board) async {
    final dynamic s = state(t);
    s.beginPuzzleSession();
    s.applyPuzzleSession(jsonDecode(jsonEncode(board)) as Map<String, dynamic>);
    s.rebuildForTesting();
    await t.pump();
    await t.pump();
  }

  Map<String, dynamic> prepared(WidgetTester t, int missing, int moves) {
    final board = snapshot(t);
    final all = solution(state(t));
    expect(all.length, greaterThanOrEqualTo(missing));
    final keys = all.keys.toList();
    final filled =
        Map<Object, int>.fromEntries(all.entries.take(all.length - missing));
    board[answersKey] = switch (shape) {
      'map' => {for (final e in filled.entries) e.key.toString(): e.value},
      'entries' => [
          for (final e in filled.entries) [e.key, e.value]
        ],
      _ => [for (final key in keys) filled[key]],
    };
    board[movesKey] = moves;
    board[maxMovesKey] = all.length;
    board[optimalKey] = all.length;
    return board;
  }

  Finder filled() {
    final semantics = find.byWidgetPredicate((w) =>
        w is Semantics &&
        (w.properties.label ?? '').toLowerCase().contains('tap to remove'));
    return find.descendant(
        of: semantics, matching: find.byType(GestureDetector));
  }

  List<ScaleTransition> dropScales(WidgetTester t) => [
        ...t.widgetList<ScaleTransition>(find.ancestor(
            of: filled().first, matching: find.byType(ScaleTransition))),
        ...t.widgetList<ScaleTransition>(find.descendant(
            of: filled().first, matching: find.byType(ScaleTransition))),
      ];

  Future<void> dragLast(WidgetTester t, Object cell, int value) async {
    final source = find
        .byWidgetPredicate((w) =>
            w is Draggable &&
            w.data != null &&
            (w.data as dynamic).number == value)
        .first;
    final target = boardDrop
        ? find
            .byWidgetPredicate((w) =>
                w is Semantics &&
                (w.properties.label ?? '').startsWith('Empty '))
            .first
        : find
            .byWidgetPredicate((w) =>
                w is DragTarget &&
                w.key is ValueKey &&
                ((w.key as ValueKey).value as dynamic).$3 == cell)
            .first;
    await t.ensureVisible(source);
    await t.ensureVisible(target);
    await t.pump();
    lastDragDescription = 'cell:$cell tile:$value source:${t.getRect(source)} '
        'target:${t.getRect(target)} before:${jsonEncode(state(t).capturePuzzleSession())}';
    expect(source.hitTestable(), findsOneWidget, reason: lastDragDescription);
    expect(target.hitTestable(), findsOneWidget, reason: lastDragDescription);
    await t.drag(
        source,
        t.getCenter(target) -
            (boardDrop ? t.getTopLeft(source) : t.getCenter(source)));
    await t.pump();
    lastDragDescription +=
        ' after:${jsonEncode(state(t).capturePuzzleSession())}';
  }

  testWidgets('adversarial: last legal real drop wins with exact accounting',
      (t) async {
    final app = await mount(t, true);
    final all = solution(state(t));
    final last = all.entries.last;
    expect(valid(state(t), all), isTrue);
    await restore(t, prepared(t, 1, 1));
    await dragLast(t, last.key, last.value);
    await t.pump(const Duration(milliseconds: 1700));
    // Warp completion may enqueue the dialog after this frame. Build it, then
    // let its separate entrance animation finish before real retry input.
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    expect(app.gp.outcomeCount, 1, reason: lastDragDescription);
    expect(app.gp.lastOutcome!.wasSuccessful, isTrue);
    expect(app.gp.lastOutcome!.movesUsed, all.length);
    expect(app.gp.lastOutcome!.optimalMoves, all.length);
    expect(state(t).capturePuzzleSession(), isNull);
    expect(roundDialogs, findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'adversarial: full incorrect last move loses once and stays terminal',
      (t) async {
    final app = await mount(t, true);
    final all = solution(state(t));
    final last = all.entries.last;
    expect(valid(state(t), all), isTrue);
    await restore(t, prepared(t, 1, 1));
    final pool = List<int>.from(snapshot(t)[poolKey] as List);
    final wrong = pool.firstWhere(
        (n) => n != last.value && !valid(state(t), {...all, last.key: n}));
    await dragLast(t, last.key, wrong);
    await t.pump(const Duration(milliseconds: 1700));
    // Warp completion may enqueue the dialog after this frame. Build it, then
    // let its separate entrance animation finish before real retry input.
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    expect(app.gp.outcomeCount, 1, reason: lastDragDescription);
    expect(app.gp.lastOutcome!.wasSuccessful, isFalse);
    expect(state(t).capturePuzzleSession(), isNull);
    expect(roundDialogs, findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(app.gp.outcomeCount, 1, reason: lastDragDescription);
    expect(roundDialogs, findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final reduced in [false, true]) {
    for (final win in [false, true]) {
      testWidgets(
          'adversarial: real ${win ? "win" : "loss"} retry generates a playable round (reduced:$reduced)',
          (t) async {
        final app = await mount(t, reduced);
        final all = solution(state(t));
        final last = all.entries.last;
        expect(valid(state(t), all), isTrue);
        await restore(t, prepared(t, 1, 1));
        final pool = List<int>.from(snapshot(t)[poolKey] as List);
        final value = win
            ? last.value
            : pool.firstWhere((n) =>
                n != last.value && !valid(state(t), {...all, last.key: n}));
        await dragLast(t, last.key, value);
        await t.pump(const Duration(milliseconds: 1700));
        // Warp completion may enqueue the dialog after this frame. Build it, then
        // let its separate entrance animation finish before real retry input.
        await t.pump();
        await t.pump(const Duration(milliseconds: 700));
        expect(app.gp.outcomeCount, 1, reason: lastDragDescription);
        expect(app.gp.lastOutcome!.wasSuccessful, win);
        final retry = find
            .descendant(of: roundDialogs, matching: find.byType(ElevatedButton))
            .first;
        await t.ensureVisible(retry);
        await t.pump();
        await t.tap(retry);
        for (var i = 0; i < 200; i++) {
          await t.pump(const Duration(milliseconds: 20));
          await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)));
          if (state(t).capturePuzzleSession() != null) {
            break;
          }
        }
        await t.pump(const Duration(milliseconds: 400));
        expect(roundDialogs, findsNothing);
        expect(state(t).capturePuzzleSession(), isNotNull);
        final fresh = snapshot(t);
        expect(fresh[movesKey], fresh[maxMovesKey]);
        expect(
            find.descendant(
                of: find.byWidgetPredicate((w) => w is DragTarget),
                matching: find.byType(ScaleTransition)),
            findsNothing,
            reason: 'A new board cannot retain the previous drop marker');
        final first = solution(state(t)).keys.first;
        final nextValue = (fresh[poolKey] as List).first as int;
        await dragLast(t, first, nextValue);
        expect(snapshot(t)[movesKey], (fresh[movesKey] as int) - 1,
            reason:
                'Real pointer input must reach new cell $first with tile $nextValue');
        expect(app.gp.outcomeCount, 1, reason: lastDragDescription);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('adversarial: stale filled control cannot remove restored input',
      (t) async {
    final app = await mount(t, true);
    final all = solution(state(t));
    await restore(t, prepared(t, all.length, all.length * 2));
    final first = all.entries.first;
    place(state(t), first.key, first.value);
    await t.pump();
    final old = t.widget<GestureDetector>(filled().first);
    final before = snapshot(t);
    await restore(t, before);
    old.onTap!();
    await t.pump();
    expect(snapshot(t), before);
    expect(app.gp.outcomeCount, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('adversarial: restore clears an in-flight drop visual',
      (t) async {
    final app = await mount(t, false);
    final all = solution(state(t));
    await restore(t, prepared(t, all.length, all.length * 2));
    final first = all.entries.first;
    place(state(t), first.key, first.value);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(dropScales(t), isNotEmpty);
    final before = snapshot(t);
    await restore(t, before);
    expect(dropScales(t), isEmpty);
    expect(snapshot(t), before);
    expect(app.gp.outcomeCount, 0);
  });

  for (final initiallyReduced in [false, true]) {
    testWidgets(
        'adversarial: drop respects reduced motion (initial:$initiallyReduced)',
        (t) async {
      final app = await mount(t, initiallyReduced);
      final all = solution(state(t));
      await restore(t, prepared(t, all.length, all.length * 2));
      final first = all.entries.first;
      final poolBefore = List<int>.from(snapshot(t)[poolKey] as List);
      place(state(t), first.key, first.value);
      await t.pump();
      if (!initiallyReduced) {
        await t.pump(const Duration(milliseconds: 100));
        expect(dropScales(t).single.scale.status, AnimationStatus.forward);
        app.motion.value = true;
        await t.pump();
        await t.pump();
      }
      final after = snapshot(t);
      expect(after[movesKey], all.length * 2 - 1);
      if (!reusable) {
        poolBefore.remove(first.value);
      }
      expect(after[poolKey], unorderedEquals(poolBefore));
      for (final scale in dropScales(t)) {
        expect(scale.scale.value, 1);
        expect(scale.scale.status, AnimationStatus.completed);
      }
      expect(app.gp.outcomeCount, 0);
    });
  }

  testWidgets('adversarial: exhausted restore offers one dialog without replay',
      (t) async {
    final app = await mount(t, true);
    final board = prepared(t, 1, 0);
    await restore(t, board);
    await t.pump(const Duration(milliseconds: 1700));
    // Warp completion may enqueue the dialog after this frame. Build it, then
    // let its separate entrance animation finish before real retry input.
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    expect(state(t).capturePuzzleSession(), isNull);
    expect(roundDialogs, findsOneWidget);
    expect(app.gp.outcomeCount, 0);
    final retry = t
        .widgetList<ElevatedButton>(find.descendant(
            of: roundDialogs, matching: find.byType(ElevatedButton)))
        .first;
    Navigator.of(t.element(roundDialogs)).pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    retry.onPressed!();
    await t.pump();
    expect(roundDialogs, findsNothing);
    expect(state(t).capturePuzzleSession(), isNull);
    expect(app.gp.outcomeCount, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('adversarial: retained hover callback is harmless after disposal',
      (t) async {
    await mount(t, false);
    final dynamic target =
        t.widget(find.byWidgetPredicate((w) => w is DragTarget).first);
    final dynamic source =
        t.widget(find.byWidgetPredicate((w) => w is Draggable).first);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    expect(() => target.onLeave?.call(source.data), returnsNormally);
    expect(t.takeException(), isNull);
  });
}
