// Optimization contract tests — ensure optimizations don't regress.
//
// These tests grep the source tree for patterns that should not appear
// in production code. They run as part of the normal test suite and CI.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Collect all .dart files under [dir], excluding generated code.
List<File> _dartFilesIn(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) return [];
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.dart') && !f.path.contains('/generated/'))
      .toList();
}

void main() {
  group('O1 — debugPrint calls must be guarded', () {
    test('no unguarded debugPrint() in lib/', () {
      final violations = <String>[];

      for (final file in _dartFilesIn('lib')) {
        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (!line.contains('debugPrint(')) continue;

          // Check if guarded by kDebugMode within 3 preceding lines.
          bool guarded = false;
          for (int j = i; j >= (i - 3).clamp(0, i); j--) {
            if (lines[j].contains('kDebugMode')) {
              guarded = true;
              break;
            }
          }
          // Also accept: if (verbose) debugPrint, if (attempts...) debugPrint
          if (line.startsWith('if (') && line.contains('debugPrint(')) {
            guarded = true;
          }
          // Skip comments.
          if (line.startsWith('//') || line.startsWith('*')) {
            guarded = true;
          }

          if (!guarded) {
            violations.add('${file.path}:${i + 1}: $line');
          }
        }
      }

      expect(violations, isEmpty,
          reason:
              'All debugPrint() calls must be wrapped in if (kDebugMode). '
              'Found ${violations.length} unguarded call(s):\n'
              '${violations.take(10).join('\n')}');
    });
  });

  group('O2 — no unused fields with ignore comments', () {
    test('no // ignore: unused_field in lib/', () {
      final violations = <String>[];

      for (final file in _dartFilesIn('lib')) {
        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].contains('// ignore: unused_field')) {
            violations.add('${file.path}:${i + 1}');
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'Remove unused fields instead of ignoring them.\n'
              '${violations.join('\n')}');
    });
  });

  group('O4 — no unpinned dependencies', () {
    test('pubspec.yaml has no "any" version constraints', () {
      final pubspec = File('pubspec.yaml');
      if (!pubspec.existsSync()) {
        return;
      }

      final violations = <String>[];
      final lines = pubspec.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // Match "  package_name: any" but not inside comments.
        if (line.endsWith(': any') && !line.startsWith('#')) {
          violations.add('pubspec.yaml:${i + 1}: $line');
        }
      }

      expect(violations, isEmpty,
          reason: 'Pin all dependencies to version ranges, not "any".\n'
              '${violations.join('\n')}');
    });
  });

  group('O5 — no standalone CLI scripts shipping in lib/', () {
    test('convert_rushdb.dart is not in lib/', () {
      // This file was a standalone CLI tool with no app imports.
      // It should live in tool/, not lib/.
      final file = File('lib/shared/utils/convert_rushdb.dart');
      expect(file.existsSync(), isFalse,
          reason: 'convert_rushdb.dart is a CLI tool — it belongs in tool/');
    });

    test('lib/main.dart is the only entry point in lib/', () {
      // A `main()` anywhere else means a CLI harness is shipping as app
      // code: dead weight in the bundle, and usually dragging in dart:io with
      // it. Such scripts belong in tool/.
      final violations = <String>[];

      for (final file in _dartFilesIn('lib')) {
        if (file.path.endsWith('lib/main.dart')) continue;
        for (final line in file.readAsLinesSync()) {
          if (RegExp(r'^\s*(void|Future<void>)\s+main\s*\(').hasMatch(line)) {
            violations.add(file.path);
            break;
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'CLI entry points found in lib/ — move them to tool/:\n'
              '${violations.join('\n')}');
    });

    test('no dart:io in code that has to build for web', () {
      // dart:io compiles for web (dart2js ships a stub) but almost every
      // API in it throws UnsupportedError at runtime there, so an unguarded
      // use is a crash the build will not catch — verified: a web release
      // build succeeds with the allowlist below. Those two gate their file
      // access at the call site; anything new here needs the same care.
      const allowed = {
        'lib/core/services/crash_logger.dart',
        'lib/features/games/services/starloader_level_manager.dart',
      };
      final violations = <String>[];

      for (final file in _dartFilesIn('lib')) {
        final normalized = file.path.replaceFirst(RegExp(r'^\./'), '');
        if (allowed.contains(normalized)) continue;
        if (file.readAsStringSync().contains("import 'dart:io'")) {
          violations.add(normalized);
        }
      }

      expect(violations, isEmpty,
          reason: 'dart:io imported in lib/ outside the platform-gated '
              'allowlist:\n${violations.join('\n')}');
    });
  });

  group('O6 — DebugPanel guarded by kDebugMode', () {
    test('DebugPanel() construction is inside kDebugMode guard', () {
      final violations = <String>[];

      for (final file in _dartFilesIn('lib')) {
        if (file.path.contains('debug_panel.dart')) continue;

        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          // Only match actual construction, not method names.
          if (!line.contains('DebugPanel(')) continue;
          if (line.startsWith('import')) continue;

          // Check surrounding lines (5 before, 5 after) for kDebugMode.
          bool guarded = false;
          final lo = (i - 5).clamp(0, lines.length);
          final hi = (i + 5).clamp(0, lines.length);
          for (int j = lo; j < hi; j++) {
            if (lines[j].contains('kDebugMode')) {
              guarded = true;
              break;
            }
          }

          if (!guarded) {
            violations.add('${file.path}:${i + 1}: $line');
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'DebugPanel construction must be guarded by kDebugMode.\n'
              '${violations.join('\n')}');
    });
  });

  group('O7 — image assets within size budget', () {
    test('PNG images under 500 KB', () {
      final dir = Directory('assets/images');
      if (!dir.existsSync()) return;

      const maxPngBytes = 500 * 1024; // 500 KB
      final violations = <String>[];

      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.png')) continue;
        final size = file.lengthSync();
        if (size > maxPngBytes) {
          violations.add(
              '${file.path}: ${(size / 1024).round()} KB (max ${maxPngBytes ~/ 1024} KB)');
        }
      }

      expect(violations, isEmpty,
          reason: 'Compress PNG images to stay under budget.\n'
              '${violations.join('\n')}');
    });
  });

  group('O8 — game code stays out of the main web bundle', () {
    test('no game screen is reachable from main.dart without a deferred import',
        () {
      // Walk the eager import/export graph from the entry point. A single
      // non-deferred import of a game screen puts that game (and everything
      // it imports) back into the bundle every visitor downloads first.
      final parents = <String, String>{};
      final visited = _eagerlyReachable('lib/main.dart', parents);

      final gameScreen = RegExp(r'^lib/features/games/screens/\w+_game\.dart$');
      final leaks = visited.where(gameScreen.hasMatch).map((p) {
        final chain = [p];
        while (parents[chain.last] != null) {
          chain.add(parents[chain.last]!);
        }
        return chain.reversed.join(' -> ');
      }).toList();

      expect(visited.length, greaterThan(20),
          reason: 'import walker found too little — did the parser drift?');
      expect(leaks, isEmpty,
          reason: 'Game screens imported eagerly (load them through '
              'lib/features/games/game_registry.dart instead):\n'
              '${leaks.join('\n')}');
    });

    test('the registry, menu and missions agree on the set of games', () {
      final registry =
          File('lib/features/games/game_registry.dart').readAsStringSync();
      final registered = RegExp(r"^  '(\w+)': _DeferredGame\(", multiLine: true)
          .allMatches(registry)
          .map((m) => m.group(1)!)
          .toSet();
      final deferredImports = RegExp(r"^import 'screens/\w+_game\.dart'\s+deferred as",
              multiLine: true)
          .allMatches(registry)
          .length;

      final menu = File('lib/features/games/screens/game_menu_screen.dart')
          .readAsStringSync();
      final menuKeys = RegExp(r"gameKey:\s*'([^']+)'")
          .allMatches(menu)
          .map((m) => m.group(1)!)
          .toSet();

      expect(registered.length, 48);
      expect(deferredImports, registered.length,
          reason: 'every registered game needs its own deferred import');
      expect(menuKeys.difference(registered), isEmpty,
          reason: 'menu games missing from game_registry.dart');
    });

    test('every named game route in main.dart maps to a registered game', () {
      final main = File('lib/main.dart').readAsStringSync();
      final table = RegExp(r'_gameRouteKeys = \{([^}]*)\}').firstMatch(main);
      expect(table, isNotNull);
      final routeKeys = RegExp(r"'(\w+)'")
          .allMatches(table!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();
      final registry =
          File('lib/features/games/game_registry.dart').readAsStringSync();
      for (final key in routeKeys) {
        expect(registry, contains("  '$key': _DeferredGame("),
            reason: 'route for $key');
      }
    });
  });

  group('O9 — no dead weight in the app bundle', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('every direct dependency is used by lib/', () {
      final deps = RegExp(r'^dependencies:\n((?:  .*\n|\n)*)', multiLine: true)
          .firstMatch(pubspec)!
          .group(1)!;
      final names = RegExp(r'^  (\w+):', multiLine: true)
          .allMatches(deps)
          .map((m) => m.group(1)!)
          .toSet();
      // SDK packages and plugins that are used without a Dart import.
      const implicit = {
        'flutter',
        'flutter_localizations',
        'in_app_purchase_storekit',
        'intl', // used by the generated l10n code in lib/generated/
      };
      final sources =
          _dartFilesIn('lib').map((f) => f.readAsStringSync()).join('\n');
      final unused = names
          .difference(implicit)
          .where((n) => !sources.contains("package:$n/"))
          .toList();
      expect(unused, isEmpty,
          reason: 'Unused dependencies still get resolved and can ship '
              'assets: $unused');
    });

    test('font files are declared individually, not as a whole folder', () {
      // A folder entry bundles every font in it, including the unused
      // variable font; the fonts: section already bundles the ones in use.
      expect(pubspec, isNot(contains(RegExp(r'^\s*- assets/fonts/\s*$',
          multiLine: true))));
    });

    test('the app icon source is not inside a bundled asset folder', () {
      final bundledDirs = RegExp(r'^\s*- (assets/[\w/]+/)\s*$', multiLine: true)
          .allMatches(pubspec)
          .map((m) => m.group(1)!);
      final iconPath =
          RegExp(r'image_path: "([^"]+)"').firstMatch(pubspec)!.group(1)!;
      for (final dir in bundledDirs) {
        expect(iconPath.startsWith(dir), isFalse,
            reason: '$iconPath would ship inside the app via $dir');
      }
    });

    test('puzzle images are WebP', () {
      final images = Directory('assets/images')
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => RegExp(r'puzzle\d+\.').hasMatch(p))
          .toList();
      expect(images, isNotEmpty);
      expect(images.where((p) => !p.endsWith('.webp')), isEmpty);
    });

    test('bundled JSON data is minified', () {
      for (final path in [
        'assets/data/starloader_levels.json',
        'assets/puzzles/gridlock_puzzles.json',
      ]) {
        final text = File(path).readAsStringSync();
        expect(text, isNot(contains('\n  ')),
            reason: '$path is pretty-printed; the indentation ships too');
      }
    });

    test('no source file over 300 KB in the initial web bundle', () {
      // Big data tables compiled into code every visitor downloads before
      // the menu appears. Files behind a deferred import only load with
      // their game. Generated l10n tables are exempt.
      const maxBytes = 300 * 1024;
      final big = _eagerlyReachable('lib/main.dart', {})
          .where((p) => !p.startsWith('lib/generated/'))
          .map(File.new)
          .where((f) => f.existsSync() && f.lengthSync() > maxBytes)
          .map((f) => '${f.path}: ${f.lengthSync() ~/ 1024} KB')
          .toList();
      expect(big, isEmpty,
          reason: 'Large data belongs in an asset loaded on demand, not '
              'compiled into the app:\n${big.join('\n')}');
    });
  });

  group('O10 — first paint on the web', () {
    test('index.html shows a splash that the first Flutter frame removes', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('id="splash"'));
      expect(html, contains("'flutter-first-frame'"));
    });
  });

  group('O11 — hosting headers', () {
    test('vercel.json cross-origin isolates the app for threaded skwasm', () {
      final config = jsonDecode(File('vercel.json').readAsStringSync())
          as Map<String, dynamic>;
      final headers = {
        for (final rule in (config['headers'] as List).cast<Map>())
          if (rule['source'] == '/(.*)')
            for (final h in (rule['headers'] as List).cast<Map>())
              (h['key'] as String).toLowerCase(): h['value'],
      };
      expect(headers['cross-origin-opener-policy'], 'same-origin');
      expect(headers['cross-origin-embedder-policy'], 'credentialless');
    });
  });

  group('O12 — animation runs on vsync', () {
    test('no Timer.periodic faster than 100 ms drives animation', () {
      // A fast periodic Timer is not synced to the display, keeps firing in
      // a background tab and drifts. Use a Ticker / AnimationController.
      final fast = RegExp(
          r'Timer\.periodic\(\s*(?:const\s+)?Duration\(\s*milliseconds:\s*(\d+)');
      final violations = <String>[];
      for (final file in _dartFilesIn('lib')) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final m = fast.firstMatch(lines[i]);
          if (m != null && int.parse(m.group(1)!) < 100) {
            violations.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });
}

/// Every local file reachable from [entry] through non-deferred imports and
/// exports. Records each file's first importer in [parents].
Set<String> _eagerlyReachable(String entry, Map<String, String> parents) {
  final visited = <String>{};
  final queue = <String>[entry];
  while (queue.isNotEmpty) {
    final path = queue.removeLast();
    if (!visited.add(path)) continue;
    for (final target in _eagerLocalImports(path)) {
      parents.putIfAbsent(target, () => path);
      queue.add(target);
    }
  }
  return visited;
}

/// Local files [path] imports or exports without `deferred`.
List<String> _eagerLocalImports(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  final directive = RegExp(
      r"^(?:import|export)\s+'([^']+)'([^;]*);",
      multiLine: true);
  final result = <String>[];
  for (final m in directive.allMatches(file.readAsStringSync())) {
    if (m.group(2)!.contains('deferred')) continue;
    final uri = m.group(1)!;
    String? target;
    if (uri.startsWith('package:space_math_academy/')) {
      target = 'lib/${uri.substring('package:space_math_academy/'.length)}';
    } else if (!uri.contains(':')) {
      target = _normalize('${File(path).parent.path}/$uri');
    }
    if (target != null) result.add(target);
  }
  return result;
}

String _normalize(String path) {
  final out = <String>[];
  for (final part in path.split('/')) {
    if (part == '..') {
      out.removeLast();
    } else if (part != '.' && part.isNotEmpty) {
      out.add(part);
    }
  }
  return out.join('/');
}
