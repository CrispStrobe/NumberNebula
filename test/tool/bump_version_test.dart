// Unit tests for tool/bump_version.dart — the release version bumper.
//
// The rule the release process depends on: every bump advances the build
// number (stores reject a reused one), and the semver part moves only by the
// segment that was asked for.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/bump_version.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('parses a pubspec version', () {
      final v = AppVersion.tryParse('1.2.0+2')!;
      expect(v.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 0);
      expect(v.build, 2);
      expect(v.toString(), '1.2.0+2');
    });

    test('tolerates surrounding whitespace', () {
      expect(AppVersion.tryParse('  3.4.5+6  ')?.toString(), '3.4.5+6');
    });

    test('rejects anything without a build number or extra parts', () {
      for (final bad in [
        '1.2.0',
        '1.2+3',
        '1.2.0+',
        'v1.2.0+3',
        '1.2.0+3-beta',
        '1.2.0.1+3',
        '',
      ]) {
        expect(AppVersion.tryParse(bad), isNull, reason: 'accepted "$bad"');
      }
    });
  });

  group('AppVersion.bump', () {
    final base = AppVersion.tryParse('1.2.3+7')!;

    test('patch moves the patch segment', () {
      expect(base.bump('patch').toString(), '1.2.4+8');
    });

    test('minor resets patch', () {
      expect(base.bump('minor').toString(), '1.3.0+8');
    });

    test('major resets minor and patch', () {
      expect(base.bump('major').toString(), '2.0.0+8');
    });

    test('build leaves semver alone', () {
      expect(base.bump('build').toString(), '1.2.3+8');
    });

    test('every bump advances the build number', () {
      for (final segment in ['major', 'minor', 'patch', 'build']) {
        expect(base.bump(segment).build, base.build + 1,
            reason: 'segment $segment did not advance the build number');
      }
    });

    test('an unknown segment is rejected', () {
      expect(() => base.bump('nightly'), throwsArgumentError);
    });
  });

  group('pubspec.yaml', () {
    test('declares a version the release tooling can parse', () {
      final source = File('pubspec.yaml').readAsStringSync();
      final match =
          RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(source);

      expect(match, isNotNull, reason: 'pubspec.yaml has no version: line');
      expect(AppVersion.tryParse(match!.group(1)!), isNotNull,
          reason: 'version "${match.group(1)}" is not x.y.z+build — '
              'tool/bump_version.dart and the store uploads both need that shape');
    });
  });
}
