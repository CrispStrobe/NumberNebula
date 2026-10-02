import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/services/puzzle_session_store.dart';
import '../../../generated/l10n.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/game_learning_shell.dart';

mixin PuzzleSessionMixin<T extends StatefulWidget> on State<T> {
  String get sessionGameKey;
  int get sessionGrade;
  int get sessionLevel;
  Map<String, dynamic>? capturePuzzleSession();
  void applyPuzzleSession(Map<String, dynamic> state);
  bool _finished = false;
  bool _disposing = false;
  GameProvider? _sessionProvider;
  GamePauseController? _pauseController;
  bool? _reducedMotion;
  final _decorativeRunning = <AnimationController>{};
  bool get puzzleSessionFinished => _finished;
  String? _lastSaved;
  Timer? _saveTimer;
  Timer? _checkpointTimer;
  static const _continuousGames = {
    'asteroid_math',
    'bubble_math',
    'hyperdrive_gates',
    'planet_hopping',
    'pathfinder',
    'cargo_bay_arranger',
    'puzzle_math',
    'asteroid_field_navigator',
    'star_loader_game'
  };

  /// Animation-only mutations never schedule board serialization.
  void setVisualState(VoidCallback fn) => super.setState(fn);
  late final WidgetsBindingObserver _sessionObserver;

  @override
  void initState() {
    super.initState();
    _sessionObserver = _PuzzleSessionObserver(() {
      savePuzzleSession();
      unawaited(PuzzleSessionStore.instance.flush());
    });
    WidgetsBinding.instance.addObserver(_sessionObserver);
    if (_continuousGames.contains(sessionGameKey)) {
      _checkpointTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && !(_pauseController?.paused ?? false)) {
          savePuzzleSession();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sessionProvider = context.read<GameProvider>();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reducedMotion != reduced) {
      _reducedMotion = reduced;
      onPuzzleSessionMotionChanged(reduced);
    }
    final pause = GamePauseScope.of(context);
    if (pause != _pauseController) {
      _pauseController?.removeListener(_onSessionPause);
      _pauseController = pause;
      _pauseController?.captureBoard = _captureHintBoard;
      _pauseController?.addListener(_onSessionPause);
    }
  }

  Map<String, dynamic>? _captureHintBoard() =>
      _finished ? null : capturePuzzleSession();

  void onPuzzleSessionMotionChanged(bool reduced) {}
  void updateDecorativeMotion(
      List<AnimationController> controllers, bool reduced) {
    for (final controller in controllers) {
      if (reduced) {
        if (controller.isAnimating) _decorativeRunning.add(controller);
        controller.stop();
      } else if (_decorativeRunning.remove(controller)) {
        controller.repeat(reverse: true);
      }
    }
  }

  void onPuzzleSessionPauseChanged(bool paused) {}
  void _onSessionPause() {
    if (!mounted) return;
    onPuzzleSessionPauseChanged(_pauseController?.paused ?? false);
    savePuzzleSession();
    unawaited(PuzzleSessionStore.instance.flush());
  }

  void beginPuzzleSession() {
    if (_sessionProvider?.coachingGameKey == sessionGameKey) {
      _sessionProvider!.coachingHintsUsed = 0;
    }
    _finished = false;
    _lastSaved = null;
  }

  void finishPuzzleSession() {
    _finished = true;
    _saveTimer?.cancel();
    unawaited(PuzzleSessionStore.instance
        .clear(sessionGameKey)
        .catchError((Object e) {
      if (kDebugMode) debugPrint('Could not clear puzzle: $e');
    }));
  }

  Future<bool> restorePuzzleSession() async {
    try {
      final state = await PuzzleSessionStore.instance
          .load(sessionGameKey, sessionGrade, sessionLevel);
      if (state == null || !mounted) return false;
      final s = S.of(context)!;
      final pause = GamePauseScope.of(context);
      final wasPaused = pause?.paused ?? false;
      pause?.setPaused(true);
      bool? resume;
      try {
        resume = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
                    title: Text(s.resumePuzzleTitle),
                    content: Text(s.resumePuzzleDescription),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(s.startNewPuzzle)),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: Text(s.resumePuzzle)),
                    ]));
      } finally {
        pause?.setPaused(wasPaused);
      }
      if (!mounted) return true;
      if (resume != true) {
        await PuzzleSessionStore.instance.clear(sessionGameKey);
        return false;
      }
      beginPuzzleSession();
      if (state['_coachingHints'] is int) {
        _sessionProvider?.coachingHintsUsed = state['_coachingHints'] as int;
      }
      setState(() => applyPuzzleSession(state));
      return true;
    } catch (e) {
      await PuzzleSessionStore.instance.clear(sessionGameKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context)!.resumePuzzleFailed)));
      }
      return false;
    }
  }

  void savePuzzleSession() {
    _saveTimer?.cancel();
    if (_finished || _disposing) return;
    final state = capturePuzzleSession();
    if (state == null) return;
    if (_sessionProvider?.coachingGameKey == sessionGameKey) {
      state['_coachingHints'] = _sessionProvider?.coachingHintsUsed ?? 0;
    }
    final encoded = jsonEncode(state);
    if (_lastSaved == encoded) return;
    _lastSaved = encoded;
    unawaited(PuzzleSessionStore.instance
        .saveEncoded(sessionGameKey, sessionGrade, sessionLevel, encoded)
        .catchError((Object e) {
      _lastSaved = null;
      if (kDebugMode) debugPrint('Could not save puzzle: $e');
    }));
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    // Gameplay changes coalesce; visual updates use setVisualState instead.
    // Moving games also have a slower checkpoint for position/time changes.
    if (_saveTimer?.isActive ?? false) return;
    _saveTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) savePuzzleSession();
    });
  }

  /// Capture once, before a screen clears its models and controllers.
  void disposePuzzleSession() {
    if (_disposing) return;
    savePuzzleSession();
    unawaited(PuzzleSessionStore.instance.flush());
    _checkpointTimer?.cancel();
    _disposing = true;
    _saveTimer?.cancel();
  }

  @override
  void dispose() {
    disposePuzzleSession();
    _saveTimer?.cancel();
    _pauseController?.removeListener(_onSessionPause);
    if (_pauseController?.captureBoard == _captureHintBoard) {
      _pauseController?.captureBoard = null;
    }
    WidgetsBinding.instance.removeObserver(_sessionObserver);
    super.dispose();
  }
}

class _PuzzleSessionObserver extends WidgetsBindingObserver {
  final VoidCallback save;
  _PuzzleSessionObserver(this.save);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) save();
  }

  @override
  void didHaveMemoryPressure() => save();
}
