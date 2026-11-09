import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/profile_preferences.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_screen.dart';
import 'package:space_math_academy/features/kompass/models/kompass_attempt.dart';
import 'package:space_math_academy/features/kompass/models/kompass_content.dart';
import 'package:space_math_academy/features/kompass/screens/kompass_hub_screen.dart';
import 'package:space_math_academy/features/kompass/services/kompass_planner.dart';
import 'package:space_math_academy/features/kompass/services/kompass_store.dart';
import 'package:space_math_academy/generated/l10n.dart';

const _relatedFamily = 'md04_draw_two_without_replacement';

Widget _app(KompassPack pack, KompassStore store) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: KompassHubScreen(pack: pack, store: store),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var profileNumber = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfilePreferences.activeId = 'lab-exposure-${profileNumber++}';
  });
  tearDown(() => ProfilePreferences.activeId = 'default');

  testWidgets(
    'opening Chance Detectives exposes related rehearsal content without assessment evidence',
    (tester) async {
      final pack = KompassPack.fromJson(
        jsonDecode(File('assets/kompass/math_v2.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      final related = pack.taskById(_relatedFamily)!;
      expect(related.familyId, _relatedFamily);
      expect(related.use, 'rehearsal');
      final store = await KompassStore.open();
      final before = KompassPlanner.selectSession(
        pack,
        store.attempts,
        mode: KompassMode.rehearsal,
        domain: 'data',
        count: pack.tasks.length,
        exposedFamilies: store.exposedFamilies,
      );
      expect(before.map((task) => task.familyId), contains(_relatedFamily));

      await tester.pumpWidget(_app(pack, store));
      await tester.pumpAndSettle();
      final launch = find.byKey(const ValueKey('kompass-lab-chance_detective'));
      await tester.scrollUntilVisible(
        launch,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(launch);
      await tester.pumpAndSettle();
      await tester.tap(launch);
      await tester.pumpAndSettle();

      expect(find.byType(KompassLabScreen), findsOneWidget);
      final state = tester
          .state<KompassLabScreenState>(find.byType(KompassLabScreen))
          .exportState();
      expect(state['labId'], 'chance_detective');
      expect(state['attempts'], 0);
      expect(state['completed'], isFalse);
      expect(store.exposedFamilies, contains(_relatedFamily));
      expect(store.attempts, isEmpty);

      // Leaving without submitting must not remove the exposure or manufacture
      // an independent observation. Reopen the durable course store as well.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await store.flush();
      final reopened = await KompassStore.open();
      expect(reopened.exposedFamilies, contains(_relatedFamily));
      expect(reopened.attempts, isEmpty);
      final progress = KompassPlanner.progress(pack, reopened.attempts);
      expect(progress['M-D04']!.independentAttempts, 0);
      expect(progress['M-D04']!.state, KompassProgressState.unassessed);

      final after = KompassPlanner.selectSession(
        pack,
        reopened.attempts,
        mode: KompassMode.rehearsal,
        domain: 'data',
        count: pack.tasks.length,
        exposedFamilies: reopened.exposedFamilies,
      );
      expect(after, isNotEmpty);
      expect(
        after.map((task) => task.familyId),
        isNot(contains(_relatedFamily)),
      );
      expect(
        after.every(
          (task) => !reopened.exposedFamilies.contains(task.familyId),
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await reopened.flush();
    },
  );
}
