// Contract test: every type consumed via `context.read<T>()` /
// `context.watch<T>()` / `Consumer<T>` somewhere in lib/ is registered
// in the provider tree in lib/main.dart. Catches the class of bug
// where a game calls context.read<NewService>() but NewService was
// never registered — manifests as a ProviderNotFoundException at
// runtime when the player opens that game.
//
// Strategy: maintain a hardcoded list of expected provider types as
// the source of truth (mirroring lib/main.dart:88-103). The test is
// a thin "did you forget to register / consume a provider" guard.
// When you add a provider, update both main.dart AND this list.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Provider types registered in lib/main.dart's MultiProvider.
/// Mirror exactly what runApp(MultiProvider(providers: [...])) sets up.
const Set<String> registeredProviders = {
  'GameProvider',
  'SriService',
  'CognitiveProfileService',
  'GridlockPuzzleTracker',
  'PurchaseService',
  'DebugProvider',
  'ProgressService',
  'AudioService',
};

void main() {
  test('every context.read<T>() / context.watch<T>() / Consumer<T> '
      'type is in the registered provider tree', () {
    final regex = RegExp(
      r'(?:context\.(?:read|watch)|Consumer|Selector(?:\d+)?)<(\w+)>',
    );
    final consumedTypes = <String>{};

    final libDir = Directory('lib');
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Skip the entry point itself — it's where providers are declared.
      if (entity.path.endsWith('lib/main.dart')) continue;
      final content = entity.readAsStringSync();
      for (final m in regex.allMatches(content)) {
        consumedTypes.add(m.group(1)!);
      }
    }

    expect(consumedTypes, isNotEmpty,
        reason: 'No provider consumers found in lib/ — regex drifted?');

    final unregistered = consumedTypes
        .where((t) => !registeredProviders.contains(t))
        .toSet();
    expect(unregistered, isEmpty,
        reason: 'Type(s) consumed via Provider but not registered in '
            'lib/main.dart: $unregistered. Either register them in the '
            'MultiProvider, or update registeredProviders in this test '
            'if they\'re registered via a different mechanism.');
  });
}
