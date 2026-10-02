import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/player_profile_service.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/profiles/screens/player_profiles_screen.dart';
import 'package:space_math_academy/generated/l10n.dart';

void main() {
  testWidgets('create, rename and select a sibling profile from the UI', (tester) async {
    SharedPreferences.setMockInitialValues({}); ProfilePreferences.activeId = 'default';
    final service = PlayerProfileService(); await service.load();
    service.onSwitch = (id) async => ProfilePreferences.activeId = id;
    await tester.pumpWidget(ChangeNotifierProvider.value(value: service, child: MaterialApp(
      localizationsDelegates: S.localizationsDelegates, supportedLocales: S.supportedLocales,
      home: const PlayerProfilesScreen())));
    await tester.tap(find.text('Add player')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Lina');
    await tester.tap(find.text('Save')); await tester.pumpAndSettle();
    expect(find.text('Lina'), findsOneWidget); expect(service.players, hasLength(2));
    await tester.tap(find.text('Lina')); await tester.pumpAndSettle();
    expect(service.active.name, 'Lina');
    final tile = find.ancestor(of: find.text('Lina'), matching: find.byType(ListTile));
    await tester.tap(find.descendant(of: tile, matching: find.byIcon(Icons.edit))); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Lina 🚀');
    await tester.tap(find.text('Save')); await tester.pumpAndSettle();
    expect(service.active.name, 'Lina 🚀'); expect(tester.takeException(), isNull);
    ProfilePreferences.activeId = 'default';
  });
}
