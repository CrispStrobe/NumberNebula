import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/debug_provider.dart';
import 'package:space_math_academy/core/services/puzzle_session_store.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/cargo_bay_arranger_game.dart';
import 'package:space_math_academy/generated/l10n.dart';
import '../../tool/cargo_row_scenarios.dart';

void main() {
  testWidgets(
      'async preview generation preserves promotion and one hold per turn',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'default';
    PuzzleSessionStore.resetForTesting();
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gp = GameProvider(
        progressService: ProgressService(),
        sriService: SriService(),
        cognitiveProfileService: CognitiveProfileService());
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gp),
          ChangeNotifierProvider(create: (_) => DebugProvider()),
        ],
        child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const CargoBayArrangerGame(grade: 6, level: 1))));
    dynamic state = tester.state(find.byType(CargoBayArrangerGame));
    Future<Map<String, dynamic>> snapshot() async {
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 5));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)));
        final captured = state.capturePuzzleSession() as Map<String, dynamic>?;
        if (captured != null) {
          return Map<String, dynamic>.from(jsonDecode(jsonEncode(captured)));
        }
      }
      throw StateError('Cargo preview never became ready');
    }

    String payload(dynamic piece) =>
        jsonEncode({'shape': piece['shape'], 'cubes': piece['cubes']});
    final original = await snapshot();
    final input = cargoScenario(6, 1, 0, 0, 20261002);
    original['grid'] = [
      for (final row in input.board)
        [
          for (final value in row)
            value == null ? null : {'value': value, 'color': 0xFF4DD0E1}
        ]
    ];
    original['nextPiece'] = input.piece.toJson();
    state.applyPuzzleSession(original);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    final held = await snapshot();
    expect(payload(held['currentPiece']), payload(original['nextPiece']));
    expect(payload(held['heldPiece']), payload(original['currentPiece']));
    expect(held['hasUsedHold'], true);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    final secondHold = await snapshot();
    expect(payload(secondHold['currentPiece']), payload(held['currentPiece']));
    expect(payload(secondHold['heldPiece']), payload(held['heldPiece']));
    expect(secondHold['shapeBag'], held['shapeBag']);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 120));
    expect(state.capturePuzzleSession(), isNull,
        reason: 'An animated row clear is not a restorable state');
    state.applyPuzzleSession(secondHold);
    await tester.pump(const Duration(milliseconds: 700));
    final restored = await snapshot();
    expect(restored['grid'], secondHold['grid'],
        reason:
            'A delayed clear from the previous board must not affect restoration');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 120));
    final dropped = await snapshot();
    expect(payload(dropped['currentPiece']), payload(held['nextPiece']));
    expect(dropped['hasUsedHold'], false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 700));
    PuzzleSessionStore.resetForTesting();
  });
}
