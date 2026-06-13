// Optimization contract tests — ensure optimizations don't regress.
//
// These tests grep the source tree for patterns that should not appear
// in production code. They run as part of the normal test suite and CI.

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
}
