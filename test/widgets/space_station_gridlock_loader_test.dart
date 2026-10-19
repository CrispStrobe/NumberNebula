import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/features/games/data/gridlock_puzzles_data.dart';
import 'package:space_math_academy/features/games/screens/space_station_gridlock_game.dart';
import 'space_station_gridlock_round_test.dart' as fixtures;

Future<void> _startLoad(
  WidgetTester t,
  fixtures.GridlockTestApp app,
  Future<GridlockPuzzleDatabase> Function() load,
) async {
  app.game = SpaceStationGridlockGame(grade: 1, level: 1, loadDatabase: load);
  await t.pumpWidget(app.build());
  await t.tap(find.byIcon(Icons.refresh).first);
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  await t.pump();
}

void main() {
  var id = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'gridlock_loader_${id++}';
    PuzzleSessionStore.resetForTesting();
  });
  for (final fail in [false, true]) {
    testWidgets(
      'seam: stale database ${fail ? 'failure' : 'success'} cannot overwrite restored board or consume a puzzle',
      (t) async {
        final (app, real) = await fixtures.mountGridlock(t);
        final db = await t.runAsync(GridlockPuzzleDatabase.load);
        final pending = Completer<GridlockPuzzleDatabase>();
        var calls = 0;
        final played = app.tracker.playedPuzzleIds;
        await _startLoad(t, app, () {
          calls++;
          return pending.future;
        });
        expect(calls, 1);
        final replacement = fixtures.gridlockFixture(real);
        await fixtures.restoreGridlock(t, replacement);
        if (fail) {
          pending.completeError(
            StateError('controlled obsolete database failure'),
          );
        } else {
          pending.complete(db!);
        }
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 100));
          await t.pump();
        }
        expect(fixtures.captureGridlock(t), replacement);
        expect(app.tracker.playedPuzzleIds, played);
        expect(app.gp.outcomeCount, 0);
        await fixtures.moveGridlockLeft(t);
        expect(fixtures.captureGridlock(t)['moveCount'], 2);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'seam: newer database load owns board and tracker after reversed completion',
    (t) async {
      final (app, real) = await fixtures.mountGridlock(t);
      final db = await t.runAsync(GridlockPuzzleDatabase.load);
      final old = Completer<GridlockPuzzleDatabase>();
      final current = Completer<GridlockPuzzleDatabase>();
      await _startLoad(t, app, () => old.future);
      await fixtures.restoreGridlock(t, fixtures.gridlockFixture(real));
      final played = app.tracker.playedPuzzleIds;
      await _startLoad(t, app, () => current.future);
      current.complete(db!);
      await fixtures.waitGridlockPlayable(t);
      final accepted = fixtures.captureGridlock(t);
      expect(accepted['moveCount'], 0);
      expect(accepted['_currentPuzzleId'], isNotNull);
      expect(app.tracker.playedPuzzleIds.difference(played), {
        accepted['_currentPuzzleId'],
      });
      final after = app.tracker.playedPuzzleIds;
      old.completeError(StateError('older load finished last'));
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      expect(fixtures.captureGridlock(t), accepted);
      expect(app.tracker.playedPuzzleIds, after);
      expect(app.gp.outcomeCount, 0);
      expect(t.takeException(), isNull);
    },
  );
  for (final fail in [false, true]) {
    testWidgets(
      'seam: disposed database ${fail ? 'failure' : 'success'} cannot mutate tracker or navigate',
      (t) async {
        final (app, _) = await fixtures.mountGridlock(t);
        final db = await t.runAsync(GridlockPuzzleDatabase.load);
        final pending = Completer<GridlockPuzzleDatabase>();
        final played = app.tracker.playedPuzzleIds;
        await _startLoad(t, app, () => pending.future);
        await t.pumpWidget(const SizedBox.shrink());
        if (fail) {
          pending.completeError(StateError('disposed load failure'));
        } else {
          pending.complete(db!);
        }
        await t.pump(const Duration(seconds: 2));
        await t.pump();
        expect(app.tracker.playedPuzzleIds, played);
        expect(app.gp.outcomeCount, 0);
        expect(t.takeException(), isNull);
      },
    );
  }
}
