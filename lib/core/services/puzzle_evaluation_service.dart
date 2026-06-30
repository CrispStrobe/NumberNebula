// lib/core/services/puzzle_evaluation_service.dart
//
// General-purpose puzzle evaluation tracker for all CSP-based games.
// Stores play stats and player ratings (debug mode) per puzzle,
// exportable as JSON for merging into puzzle datasets.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/space_theme.dart';

/// A single puzzle evaluation entry.
class PuzzleEval {
  final String gameType;
  final String puzzleId;
  final int grade;
  final int level;
  final int rating; // 1-5
  final int solveTimeMs;
  final DateTime playedAt;

  const PuzzleEval({
    required this.gameType,
    required this.puzzleId,
    required this.grade,
    required this.level,
    required this.rating,
    this.solveTimeMs = 0,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
        'gameType': gameType,
        'puzzleId': puzzleId,
        'grade': grade,
        'level': level,
        'rating': rating,
        'solveTimeMs': solveTimeMs,
        'playedAt': playedAt.toIso8601String(),
      };

  factory PuzzleEval.fromJson(Map<String, dynamic> j) => PuzzleEval(
        gameType: j['gameType'] as String,
        puzzleId: j['puzzleId'] as String,
        grade: j['grade'] as int? ?? 1,
        level: j['level'] as int? ?? 1,
        rating: j['rating'] as int? ?? 3,
        solveTimeMs: j['solveTimeMs'] as int? ?? 0,
        playedAt: DateTime.parse(j['playedAt'] as String),
      );
}

/// Singleton service tracking evaluations across all games.
class PuzzleEvaluationService {
  PuzzleEvaluationService._();
  static final instance = PuzzleEvaluationService._();

  static const _key = 'puzzle_evaluations_v1';
  List<PuzzleEval> _evals = [];

  List<PuzzleEval> get evaluations => List.unmodifiable(_evals);
  int get count => _evals.length;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _evals = list
            .map((e) => PuzzleEval.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (kDebugMode) {
        debugPrint('[PuzzleEval] Loaded ${_evals.length} evaluations');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PuzzleEval] Load error: $e');
    }
  }

  Future<void> add(PuzzleEval eval) async {
    _evals.add(eval);
    await _save();
    if (kDebugMode) {
      debugPrint('[PuzzleEval] Added: ${eval.gameType}/${eval.puzzleId} '
          '${eval.rating}/5');
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_evals.map((e) => e.toJson()).toList()));
  }

  /// Export all evaluations as pretty JSON.
  String exportJson() =>
      const JsonEncoder.withIndent('  ')
          .convert(_evals.map((e) => e.toJson()).toList());

  /// Get evaluations for a specific game type.
  List<PuzzleEval> forGame(String gameType) =>
      _evals.where((e) => e.gameType == gameType).toList();

  /// Clear all evaluations.
  Future<void> clear() async {
    _evals.clear();
    await _save();
  }
}

// ─── Reusable debug evaluation widget ────────────────────────────────────

/// A star-rating row for debug mode puzzle evaluation.
/// Drop this into any win dialog:
///
///   if (kDebugMode) DebugPuzzleRating(
///     gameType: 'arithmancer_crosswords',
///     puzzleId: 'attempt_$hashCode',
///     grade: widget.grade,
///     level: widget.level,
///   ),
class DebugPuzzleRating extends StatefulWidget {
  final String gameType;
  final String puzzleId;
  final int grade;
  final int level;
  final int solveTimeMs;

  const DebugPuzzleRating({
    super.key,
    required this.gameType,
    required this.puzzleId,
    required this.grade,
    required this.level,
    this.solveTimeMs = 0,
  });

  @override
  State<DebugPuzzleRating> createState() => _DebugPuzzleRatingState();
}

class _DebugPuzzleRatingState extends State<DebugPuzzleRating> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Rate this puzzle',
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 11,
                color: SpaceTheme.starYellow,
              )),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () {
                  setState(() => _rating = star);
                  PuzzleEvaluationService.instance.add(PuzzleEval(
                    gameType: widget.gameType,
                    puzzleId: widget.puzzleId,
                    grade: widget.grade,
                    level: widget.level,
                    rating: star,
                    solveTimeMs: widget.solveTimeMs,
                    playedAt: DateTime.now(),
                  ));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    star <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: star <= _rating
                        ? SpaceTheme.starYellow
                        : Colors.white24,
                    size: 26,
                  ),
                ),
              );
            }),
          ),
          if (_rating > 0)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${widget.puzzleId}: $_rating/5 saved',
                style: SpaceTheme.bodyStyle.copyWith(
                  fontSize: 9,
                  color: SpaceTheme.alienGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
