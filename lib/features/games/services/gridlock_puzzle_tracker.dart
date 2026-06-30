// lib/features/games/services/gridlock_puzzle_tracker.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Evaluation data for a single puzzle play session.
class PuzzleEvaluation {
  final String puzzleId;
  final int movesUsed;
  final int minMoves;
  final int rating; // 1-5 stars (player-assigned in debug mode)
  final DateTime playedAt;

  const PuzzleEvaluation({
    required this.puzzleId,
    required this.movesUsed,
    required this.minMoves,
    required this.rating,
    required this.playedAt,
  });

  double get efficiency => minMoves > 0 ? minMoves / movesUsed : 0;

  Map<String, dynamic> toJson() => {
        'puzzleId': puzzleId,
        'movesUsed': movesUsed,
        'minMoves': minMoves,
        'rating': rating,
        'playedAt': playedAt.toIso8601String(),
      };

  factory PuzzleEvaluation.fromJson(Map<String, dynamic> json) =>
      PuzzleEvaluation(
        puzzleId: json['puzzleId'] as String,
        movesUsed: json['movesUsed'] as int,
        minMoves: json['minMoves'] as int,
        rating: json['rating'] as int? ?? 3,
        playedAt: DateTime.parse(json['playedAt'] as String),
      );
}

/// Tracks which gridlock puzzles have been played and their evaluations.
class GridlockPuzzleTracker with ChangeNotifier {
  Set<String> _playedPuzzleIds = {};
  List<PuzzleEvaluation> _evaluations = [];

  static const _storageKey = 'gridlock_played_puzzles';
  static const _evalStorageKey = 'gridlock_evaluations';

  Set<String> get playedPuzzleIds => Set.unmodifiable(_playedPuzzleIds);
  List<PuzzleEvaluation> get evaluations => List.unmodifiable(_evaluations);

  /// Load played puzzle IDs and evaluations from storage
  Future<void> loadPlayedPuzzles() async {
    if (kDebugMode) debugPrint('[GRIDLOCK_TRACKER] Loading played puzzles...');
    try {
      final prefs = await SharedPreferences.getInstance();

      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _playedPuzzleIds = Set<String>.from(jsonList);
      }

      final evalString = prefs.getString(_evalStorageKey);
      if (evalString != null) {
        final List<dynamic> evalList = json.decode(evalString);
        _evaluations = evalList
            .map((e) =>
                PuzzleEvaluation.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (kDebugMode) {
        debugPrint('[GRIDLOCK_TRACKER] ✅ Loaded ${_playedPuzzleIds.length} '
            'played, ${_evaluations.length} evaluations');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GRIDLOCK_TRACKER] ❌ Error loading: $e');
      _playedPuzzleIds = {};
      _evaluations = [];
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _storageKey, json.encode(_playedPuzzleIds.toList()));
      await prefs.setString(
          _evalStorageKey,
          json.encode(_evaluations.map((e) => e.toJson()).toList()));
    } catch (e) {
      if (kDebugMode) debugPrint('[GRIDLOCK_TRACKER] ❌ Error saving: $e');
    }
  }

  /// Mark a puzzle as played
  void markPuzzleAsPlayed(String puzzleId) {
    if (_playedPuzzleIds.add(puzzleId)) {
      _save();
      notifyListeners();
    }
  }

  /// Add an evaluation for a played puzzle (debug mode).
  Future<void> addEvaluation(PuzzleEvaluation eval) async {
    _playedPuzzleIds.add(eval.puzzleId);
    _evaluations.add(eval);
    await _save();
    notifyListeners();
    if (kDebugMode) {
      debugPrint('[GRIDLOCK_TRACKER] ⭐ Evaluated ${eval.puzzleId}: '
          '${eval.rating}/5 (${eval.movesUsed}/${eval.minMoves} moves)');
    }
  }

  /// Get the average rating for a puzzle across all evaluations.
  double? getAverageRating(String puzzleId) {
    final evals = _evaluations.where((e) => e.puzzleId == puzzleId);
    if (evals.isEmpty) return null;
    return evals.map((e) => e.rating).reduce((a, b) => a + b) /
        evals.length;
  }

  bool hasPlayedPuzzle(String puzzleId) =>
      _playedPuzzleIds.contains(puzzleId);

  int get playedCount => _playedPuzzleIds.length;
  int get evaluationCount => _evaluations.length;

  /// Export all evaluations as JSON string (for merging with remote dataset).
  String exportEvaluationsJson() {
    return const JsonEncoder.withIndent('  ')
        .convert(_evaluations.map((e) => e.toJson()).toList());
  }

  /// Reset all played puzzles
  Future<void> resetPlayedPuzzles() async {
    _playedPuzzleIds.clear();
    _evaluations.clear();
    await _save();
    notifyListeners();
  }

  /// Get played puzzles for a specific complexity range
  Set<String> getPlayedPuzzlesForComplexity(double complexity,
      {double tolerance = 0.3}) {
    return _playedPuzzleIds;
  }
}