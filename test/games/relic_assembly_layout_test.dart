// Relic Assembly sizes its board and tray from the space it is given. At the
// old fixed sizes (80px cells, 65px tray pieces, a 22px rotate button) a
// tablet showed thumbnail pieces with tiny edge glyphs and most of the screen
// empty.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/screens/relic_assembly_game.dart';
import 'package:space_math_academy/generated/l10n.dart';

Widget _harness() {
  final progress = ProgressService();
  final sri = SriService();
  final cognitive = CognitiveProfileService();
  final game = GameProvider(
    progressService: progress,
    sriService: sri,
    cognitiveProfileService: cognitive,
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: game),
      ChangeNotifierProvider.value(value: sri),
      ChangeNotifierProvider.value(value: cognitive),
      Provider.value(value: progress),
    ],
    child: const MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: Locale('en'),
      home: RelicAssemblyGame(grade: 1, level: 1),
    ),
  );
}

/// Sizes of the square tray pieces: Draggable children in the tray.
List<double> _traySizes(WidgetTester tester) => tester
    .widgetList<Draggable<int>>(find.byType(Draggable<int>))
    .map((d) => tester.getSize(find.byWidget(d.child)).width)
    .toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (name, size, minPiece) in [
    ('tablet landscape', const Size(1280, 800), 90.0),
    ('phone portrait', const Size(390, 844), 56.0),
  ]) {
    testWidgets('$name: lays out without overflow, pieces at least $minPiece px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness());
      // Generation is async; pump frames, never settle (the board glows forever).
      for (var i = 0; i < 20 && find.byType(Draggable<int>).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);

      final sizes = _traySizes(tester);
      expect(sizes, isNotEmpty);
      for (final s in sizes) {
        expect(s, greaterThanOrEqualTo(minPiece));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
