// ignore_for_file: avoid_print
// tool/bump_version.dart
//
// Bumps `version:` in pubspec.yaml. The build number always increments — the
// stores reject an upload that reuses one — and the semver part moves by the
// segment you ask for.
//
// Usage:
//   dart run tool/bump_version.dart patch     # 1.2.0+2 -> 1.2.1+3
//   dart run tool/bump_version.dart minor     # 1.2.0+2 -> 1.3.0+3
//   dart run tool/bump_version.dart major     # 1.2.0+2 -> 2.0.0+3
//   dart run tool/bump_version.dart build     # 1.2.0+2 -> 1.2.0+3
//   dart run tool/bump_version.dart --set 2.0.0+17
//   dart run tool/bump_version.dart patch --dry-run
//
// Prints the new version to stdout so a release script can capture it.

import 'dart:io';

const _usage = '''
Usage: dart run tool/bump_version.dart <major|minor|patch|build> [--dry-run]
       dart run tool/bump_version.dart --set <x.y.z+build> [--dry-run]
''';

/// A pubspec version: semver plus the mandatory build number.
class AppVersion {
  final int major;
  final int minor;
  final int patch;
  final int build;

  const AppVersion(this.major, this.minor, this.patch, this.build);

  static final RegExp pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$');

  /// Parses `1.2.0+2`, or null if it isn't in that shape.
  static AppVersion? tryParse(String raw) {
    final match = pattern.firstMatch(raw.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
    );
  }

  /// The bumped version. Every bump advances the build number.
  AppVersion bump(String segment) {
    switch (segment) {
      case 'major':
        return AppVersion(major + 1, 0, 0, build + 1);
      case 'minor':
        return AppVersion(major, minor + 1, 0, build + 1);
      case 'patch':
        return AppVersion(major, minor, patch + 1, build + 1);
      case 'build':
        return AppVersion(major, minor, patch, build + 1);
      default:
        throw ArgumentError('Unknown segment "$segment"');
    }
  }

  @override
  String toString() => '$major.$minor.$patch+$build';
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.write(_usage);
    exit(64); // EX_USAGE
  }

  final dryRun = args.contains('--dry-run');
  final positional = args.where((a) => a != '--dry-run').toList();

  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('pubspec.yaml not found — run this from the project root.');
    exit(66); // EX_NOINPUT
  }

  final source = pubspec.readAsStringSync();
  final versionLine = RegExp(r'^version:\s*(.+)$', multiLine: true);
  final currentMatch = versionLine.firstMatch(source);
  if (currentMatch == null) {
    stderr.writeln('No `version:` line in pubspec.yaml.');
    exit(65); // EX_DATAERR
  }

  final current = AppVersion.tryParse(currentMatch.group(1)!);
  if (current == null) {
    stderr.writeln('Version "${currentMatch.group(1)}" is not `x.y.z+build`.');
    exit(65);
  }

  final AppVersion next;
  if (positional.first == '--set') {
    if (positional.length < 2) {
      stderr.write(_usage);
      exit(64);
    }
    final explicit = AppVersion.tryParse(positional[1]);
    if (explicit == null) {
      stderr.writeln('"${positional[1]}" is not `x.y.z+build`.');
      exit(65);
    }
    next = explicit;
  } else {
    const segments = {'major', 'minor', 'patch', 'build'};
    if (!segments.contains(positional.first)) {
      stderr.write(_usage);
      exit(64);
    }
    next = current.bump(positional.first);
  }

  if (next.build <= current.build && positional.first != '--set') {
    stderr.writeln('Refusing to write a build number that does not advance.');
    exit(65);
  }

  print('$current -> $next');
  if (dryRun) return;

  pubspec.writeAsStringSync(
      source.replaceFirst(currentMatch.group(0)!, 'version: $next'));
  stdout.writeln('pubspec.yaml updated.');
}
