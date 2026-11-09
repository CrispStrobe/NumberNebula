import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/kompass/screens/kompass_paper_screen.dart';
import 'package:space_math_academy/features/kompass/services/kompass_repository.dart';
import 'package:space_math_academy/features/kompass/services/kompass_store.dart';

// Use the committed files without scheduling decoder isolates in FakeAsync.
class _PaperBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final german in [false, true]) {
    testWidgets('paper tasks load offline and consume exposure only ($german)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      ProfilePreferences.activeId = 'paper-$german';
      final store = await KompassStore.open();
      final bundle = _PaperBundle();
      final pack = await KompassRepository.load(bundle: bundle);
      final manifest = jsonDecode(
          await bundle.loadString('assets/kompass/print/manifest.json')) as Map;
      final sheet = (manifest['worksheets'] as List).first as Map;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(german ? 'de' : 'en'),
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        home: KompassPaperScreen(pack: pack, store: store, assetBundle: bundle),
      ));
      await tester.pumpAndSettle();
      final open =
          find.text(german ? 'Übungsheft öffnen' : 'Open practice booklet');
      await tester.scrollUntilVisible(open, 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(open);
      await tester.pumpAndSettle();
      final expectedFamilies = (sheet['taskIds'] as List)
          .map((id) => pack.taskById(id as String)!.familyId)
          .toSet();
      expect(store.exposedFamilies, expectedFamilies);
      expect(store.attempts, isEmpty);
      final first = pack.taskById((sheet['taskIds'] as List).first as String)!;
      final solution = first.solution[german ? 'de' : 'en']!;
      expect(find.text(solution), findsNothing);
      final solutions = find.byType(SwitchListTile);
      await tester.scrollUntilVisible(solutions, 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(solutions);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(solution), 250,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(solution), findsOneWidget);
      expect(store.attempts, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await store.flush();
      ProfilePreferences.activeId = 'default';
    });
  }
}
