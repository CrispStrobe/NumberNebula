// PuzzleImageService finds the puzzle images through Flutter's asset
// manifest. It used to read AssetManifest.json, which Flutter no longer
// generates, so it silently fell back to a hardcoded list (and on the web
// requested a file that 404s on every start).

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/core/services/puzzle_image_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('discovers the bundled puzzle images from the asset manifest', () async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);

    await PuzzleImageService.instance.init();

    // The hardcoded list is only a fallback; the manifest must be what
    // found them.
    expect(logs.where((l) => l.contains('fallback')), isEmpty);
    expect(logs.where((l) => l.contains('Found 7 puzzle images')), hasLength(1));

    final paths = [
      for (var level = 1; level <= 7; level++)
        PuzzleImageService.instance.getImageForLevel(level)!,
    ];
    expect(paths, [
      for (var i = 1; i <= 7; i++) 'assets/images/puzzle0$i.webp',
    ]);
    // Levels cycle through the images.
    expect(PuzzleImageService.instance.getImageForLevel(8), paths.first);
  });
}
