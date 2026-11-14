// lib/core/services/crash_logger.dart
//
// Local-first crash logging. Persists crash details to a rotating file in
// the app's documents directory. Nothing leaves the device unless the user
// explicitly invokes [exportLog] — this keeps crash data fully under the
// user's control and avoids any third-party data-processing dependency.
//
// Reads can happen synchronously after init() to allow a Settings screen
// to display the current log; writes are async-best-effort because they
// fire from FlutterError.onError where awaiting would prolong an already
// painful frame.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CrashEntry {
  final DateTime timestamp;
  final String source; // 'flutter' | 'platform' | 'manual'
  final String summary;
  final String? stackTrace;
  final Map<String, String>? context;

  CrashEntry({
    required this.timestamp,
    required this.source,
    required this.summary,
    this.stackTrace,
    this.context,
  });

  Map<String, dynamic> toJson() => {
        'ts': timestamp.toIso8601String(),
        'src': source,
        'summary': summary,
        if (stackTrace != null) 'stack': stackTrace,
        if (context != null) 'ctx': context,
      };

  factory CrashEntry.fromJson(Map<String, dynamic> json) => CrashEntry(
        timestamp: DateTime.parse(json['ts'] as String),
        source: json['src'] as String,
        summary: json['summary'] as String,
        stackTrace: json['stack'] as String?,
        context: (json['ctx'] as Map?)?.cast<String, String>(),
      );
}

class CrashLogger {
  CrashLogger._();
  static final CrashLogger instance = CrashLogger._();

  static const _filename = 'crash_log.jsonl';
  static const _activityFilename = 'pending_activity.json';
  static const _maxEntries = 50;

  File? _file;
  File? _activity;
  bool _initialized = false;

  /// Initialize the logger and install global error handlers. Idempotent.
  /// Call once early in main(), before runApp.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File(p.join(dir.path, _filename));
      _activity = File(p.join(dir.path, _activityFilename));
      _reportUnfinishedActivity();
    } catch (e) {
      // If we can't even open the file we still install handlers; entries
      // will just be debugPrint'd. Better than crashing the crash logger.
      if (kDebugMode) debugPrint('[CrashLogger] Could not open log file: $e');
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _recordSync(
        source: 'flutter',
        summary: details.exceptionAsString(),
        stackTrace: details.stack?.toString(),
        context: {
          if (details.library != null) 'library': details.library!,
          if (details.context != null) 'context': details.context!.toString(),
        },
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _recordSync(
        source: 'platform',
        summary: error.toString(),
        stackTrace: stack.toString(),
      );
      return true; // suppress default termination
    };
  }

  /// Marks the start of an action that has crashed natively before (opening
  /// a KOMPASS session or lab). A native crash (SIGSEGV in compiled code)
  /// kills the process before any Dart handler runs, so nothing would be
  /// logged. The marker is written synchronously; [endActivity] removes it
  /// once the screen has drawn. If the app dies in between, the next launch
  /// records which action was running.
  void beginActivity(String name) {
    final file = _activity;
    if (file == null) return;
    try {
      file.writeAsStringSync(
        jsonEncode({
          'activity': name,
          'ts': DateTime.now().toIso8601String(),
        }),
        flush: true,
      );
    } catch (_) {
      // Never let diagnostics break the action itself.
    }
  }

  /// Clears the marker set by [beginActivity].
  void endActivity() {
    final file = _activity;
    if (file == null) return;
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  void _reportUnfinishedActivity() {
    final file = _activity;
    if (file == null) return;
    try {
      if (!file.existsSync()) return;
      final raw = file.readAsStringSync();
      file.deleteSync();
      String activity = 'unknown';
      String? started;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        activity = json['activity'] as String? ?? activity;
        started = json['ts'] as String?;
      } catch (_) {}
      _recordSync(
        source: 'native',
        summary: 'The app ended unexpectedly while: $activity',
        context: {
          if (started != null) 'started': started,
          'note': 'No Dart stack exists for a native crash; the device '
              'crash report (Settings > Privacy > Analytics) has the '
              'addresses.',
        },
      );
    } catch (_) {}
  }

  /// Manually record an issue (e.g. caught exception in a service).
  Future<void> record({
    required String summary,
    String? stackTrace,
    Map<String, String>? context,
  }) async {
    _recordSync(
      source: 'manual',
      summary: summary,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void _recordSync({
    required String source,
    required String summary,
    String? stackTrace,
    Map<String, String>? context,
  }) {
    final entry = CrashEntry(
      timestamp: DateTime.now(),
      source: source,
      summary: summary,
      stackTrace: stackTrace,
      context: context,
    );

    if (kDebugMode) debugPrint('[CrashLogger] $source: $summary');

    final file = _file;
    if (file == null) return;

    // Fire-and-forget append. Errors here are intentionally swallowed —
    // the logger itself must never crash the app.
    unawaited(() async {
      try {
        await file.writeAsString(
          '${jsonEncode(entry.toJson())}\n',
          mode: FileMode.append,
          flush: false,
        );
        await _maybeRotate();
      } catch (e) {
        if (kDebugMode) debugPrint('[CrashLogger] write failed: $e');
      }
    }());
  }

  Future<void> _maybeRotate() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    final lines = await file.readAsLines();
    if (lines.length <= _maxEntries) return;
    final keep = lines.sublist(lines.length - _maxEntries);
    await file.writeAsString('${keep.join('\n')}\n');
  }

  /// Read all currently-stored crashes. Newest last.
  Future<List<CrashEntry>> readAll() async {
    final file = _file;
    if (file == null || !await file.exists()) return const [];
    final lines = await file.readAsLines();
    final entries = <CrashEntry>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        entries
            .add(CrashEntry.fromJson(jsonDecode(line) as Map<String, dynamic>));
      } catch (_) {
        // Skip malformed lines silently.
      }
    }
    return entries;
  }

  Future<void> clear() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    await file.delete();
  }

  /// Path to the log file, for sharing via the platform share sheet.
  /// Returns null until [init] completes.
  String? get logFilePath => _file?.path;
}
