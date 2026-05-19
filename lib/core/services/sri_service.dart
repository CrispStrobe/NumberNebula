// lib/core/services/sri_service.dart:
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/games/models/math_problem.dart';
import '../../features/games/constants/app_constants.dart';
import '../../features/games/tuning.dart';

// Data model for each tracked problem
class SriProblemData {
  final String problemId;
  int successCount;
  int failureCount;
  double easinessFactor; // E-Factor from SM-2 algorithm
  int repetitions;
  DateTime nextReviewDate;

  SriProblemData({
    required this.problemId,
    this.successCount = 0,
    this.failureCount = 0,
    this.easinessFactor = kSm2InitialEasiness,
    this.repetitions = 0,
    required this.nextReviewDate,
  });

  Map<String, dynamic> toJson() => {
    'id': problemId,
    's': successCount,
    'f': failureCount,
    'ef': easinessFactor,
    'r': repetitions,
    'next': nextReviewDate.toIso8601String(),
  };

  factory SriProblemData.fromJson(Map<String, dynamic> json) => SriProblemData(
    problemId: json['id'],
    successCount: json['s'] ?? 0,
    failureCount: json['f'] ?? 0,
    easinessFactor: json['ef'] ?? kSm2InitialEasiness,
    repetitions: json['r'] ?? 0,
    nextReviewDate: DateTime.parse(json['next']),
  );
}

// The main service class
class SriService with ChangeNotifier {
  Map<String, SriProblemData> _sriDatabase = {};
  static const _sriStorageKey = 'sri_database';
  
  final Set<String> _alreadyReturnedThisSession = {};
  DateTime? _sessionStartTime;

  void _log(String message) {
    debugPrint('[SRI_SERVICE] 🧠 $message');
  }

  void resetSession() {
    _alreadyReturnedThisSession.clear();
    _sessionStartTime = DateTime.now();
    _log('Session reset. Clearing returned problems cache.');
  }

  void _checkSessionExpiry() {
    if (_sessionStartTime == null || 
        DateTime.now().difference(_sessionStartTime!).inMinutes > 10) {
      resetSession();
    }
  }

    /// NEW: Calculates a detailed breakdown of progress across operations and number ranges.
    /// This powers the Progress Matrix heatmap.
  Map<MathOperation, Map<NumberRange, OperationStat>> getDetailedBreakdown() {
    _log('Calculating detailed progress breakdown...');
    // Initialize a nested map to hold our aggregated data.
    // MODIFIED: Add a field to accumulate the total E-Factor for averaging
    final breakdown = {
      for (var op in MathOperation.values)
        op: {
          for (var range in NumberRange.values)
            range: {'tracked': 0, 'mastered': 0, 'totalEFactor': 0.0}
        }
    };

    _sriDatabase.forEach((problemId, data) {
        final parts = problemId.split('_');
        if (parts.length != 3) return;

        // 1. Determine the operation from the problem ID prefix.
        MathOperation? operation;
        switch (parts[0]) {
        case 'ADD': operation = MathOperation.addition; break;
        case 'SUB': operation = MathOperation.subtraction; break;
        case 'MUL': operation = MathOperation.multiplication; break;
        case 'DIV': operation = MathOperation.division; break;
        }
        if (operation == null) return;

        // 2. Determine the number range from the largest operand.
        final operand1 = int.tryParse(parts[1]) ?? 0;
        final operand2 = int.tryParse(parts[2]) ?? 0;
        final maxOperand = max(operand1, operand2);

        NumberRange range;
        if (maxOperand <= 10) {
        range = NumberRange.range1_10;
        } else if (maxOperand <= 20) {
        range = NumberRange.range11_20;
        } else if (maxOperand <= 50) {
        range = NumberRange.range21_50;
        } else {
        range = NumberRange.range51plus;
        }

        // 3. Increment the tracked and mastered counts for the correct bucket.
        // MODIFIED: Increment stats and accumulate the E-Factor
      breakdown[operation]![range]!['tracked'] = (breakdown[operation]![range]!['tracked'] as int) + 1;
      breakdown[operation]![range]!['totalEFactor'] = (breakdown[operation]![range]!['totalEFactor'] as double) + data.easinessFactor;
      if (isProblemMastered(problemId)) {
        breakdown[operation]![range]!['mastered'] = (breakdown[operation]![range]!['mastered'] as int) + 1;
      }
    });

    // Convert the raw map into a more robust map of OperationStat objects.
    // MODIFIED: Convert the raw map to OperationStat objects, calculating the average
    final finalBreakdown = breakdown.map((op, rangeMap) {
      return MapEntry(op, rangeMap.map((range, stats) {
        final tracked = stats['tracked'] as int;
        final mastered = stats['mastered'] as int;
        final totalEFactor = stats['totalEFactor'] as double;
        return MapEntry(
            range,
            OperationStat(
              tracked: tracked,
              mastered: mastered,
              averageEasiness: tracked > 0 ? totalEFactor / tracked : 2.5,
            ));
      }));
    });
    
    _log('✅ Detailed breakdown calculated.');
    return finalBreakdown;
    }

  String _getProblemId(MathProblem problem) {
    if (problem.operation == MathOperation.addition) {
      return 'ADD_${min(problem.operandA, problem.operandB)}_${max(problem.operandA, problem.operandB)}';
    } else if (problem.operation == MathOperation.subtraction) {
      return 'SUB_${problem.operandA}_${problem.operandB}';
    } else if (problem.operation == MathOperation.multiplication) {
      return 'MUL_${min(problem.operandA, problem.operandB)}_${max(problem.operandA, problem.operandB)}';
    } else if (problem.operation == MathOperation.division) {
      return 'DIV_${problem.operandA}_${problem.operandB}';
    } else {
      throw Exception("Unknown MathOperation type for SRI ID generation: ${problem.operation}");
    }
  }
  
  bool isProblemMastered(String problemId) {
    final data = _sriDatabase[problemId];
    if (data == null) return false;

    final isMastered = data.repetitions >= kSm2MinimumRepetitionsForMastery &&
        data.easinessFactor > kSm2MasteryEasinessThreshold &&
        data.failureCount <= kSm2MaxFailuresForMastery;

    if (isMastered) {
      _log('Problem "$problemId" is considered MASTERED. Skipping for now.');
    }
    return isMastered;
  }
  
  Future<void> loadSriData() async {
    _log('Loading SRI database from storage...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_sriStorageKey);
      if (jsonString != null) {
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        _sriDatabase = jsonMap.map(
          (key, value) => MapEntry(key, SriProblemData.fromJson(value)),
        );
        _log('✅ Successfully loaded ${_sriDatabase.length} SRI records.');
      } else {
        _log('No SRI data found. Starting with a fresh database.');
      }
    } catch (e) {
      _log('❌ Error loading SRI data: $e. Using an empty database.');
      _sriDatabase = {};
    }
    
    resetSession();
    notifyListeners();
  }

  Future<void> saveSriData() async {
    _log('Saving SRI database to storage...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(
        _sriDatabase.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString(_sriStorageKey, jsonString);
      _log('✅ Successfully saved ${_sriDatabase.length} SRI records.');
    } catch (e) {
      _log('❌ Error saving SRI data: $e');
    }
  }

  void recordResponse(MathProblem problem, bool wasCorrect) {
    final problemId = _getProblemId(problem);
    _log('Recording response for problem "$problemId": ${wasCorrect ? "Correct" : "Incorrect"}');

    final data = _sriDatabase[problemId] ?? SriProblemData(
      problemId: problemId,
      nextReviewDate: DateTime.now(),
    );

    if (wasCorrect) {
      data.successCount++;
    } else {
      data.failureCount++;
    }

    final q = wasCorrect ? 5 : 1;

    if (q < 3) {
      data.repetitions = 0;
    } else {
      data.repetitions++;
    }

    data.easinessFactor = data.easinessFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (data.easinessFactor < kSm2MinimumEasiness) {
      data.easinessFactor = kSm2MinimumEasiness;
    }

    int intervalInDays;
    if (data.repetitions <= 1) {
      intervalInDays = 1;
    } else if (data.repetitions == 2) {
      intervalInDays = 6;
    } else {
      intervalInDays = (data.repetitions - 1) * data.easinessFactor.round();
    }

    data.nextReviewDate = DateTime.now().add(Duration(days: intervalInDays));
    
    _sriDatabase[problemId] = data;
    _log('Updated SRI for "$problemId": EF=${data.easinessFactor.toStringAsFixed(2)}, Reps=${data.repetitions}, NextReview=${data.nextReviewDate.toIso8601String().substring(0, 10)}');
    
    notifyListeners();
    saveSriData();
  }

  List<String> getProblemsForReview({
    int limit = 5, 
    Set<String>? excludeIds,
    bool resetSessionFirst = false
  }) {
    if (resetSessionFirst) {
      resetSession();
    } else {
      _checkSessionExpiry();
    }

    final now = DateTime.now();
    final allExcluded = <String>{
      ..._alreadyReturnedThisSession,
      ...?excludeIds,
    };

    final reviewable = _sriDatabase.values
        .where((data) => 
            data.nextReviewDate.isBefore(now) && 
            !allExcluded.contains(data.problemId) &&
            !isProblemMastered(data.problemId))
        .toList();

    reviewable.sort((a, b) {
        int efComparison = a.easinessFactor.compareTo(b.easinessFactor);
        if (efComparison != 0) return efComparison;
        return a.nextReviewDate.compareTo(b.nextReviewDate);
    });
    
    final problemIds = reviewable.map((data) => data.problemId).take(limit).toList();
    
    _alreadyReturnedThisSession.addAll(problemIds);
    
    _log('Found ${problemIds.length} NEW problems due for review (excluding ${allExcluded.length} already returned/excluded).');
    if (problemIds.isNotEmpty) {
      _log('Returning: ${problemIds.join(", ")}');
    }
    
    return problemIds;
  }

  int getAvailableReviewCount({Set<String>? excludeIds}) {
    _checkSessionExpiry();
    
    final now = DateTime.now();
    final allExcluded = <String>{
      ..._alreadyReturnedThisSession,
      ...?excludeIds,
    };

    return _sriDatabase.values
        .where((data) => 
            data.nextReviewDate.isBefore(now) && 
            !allExcluded.contains(data.problemId) &&
            !isProblemMastered(data.problemId))
        .length;
  }

  List<String> getFreshProblemsForReview({int limit = 5, Set<String>? excludeIds}) {
    return getProblemsForReview(
      limit: limit, 
      excludeIds: excludeIds, 
      resetSessionFirst: true
    );
  }

  void debugPrintSessionState() {
    _log('SESSION DEBUG: ${_alreadyReturnedThisSession.length} problems returned this session');
    _log('Returned problems: ${_alreadyReturnedThisSession.join(", ")}');
    _log('Available for review: ${getAvailableReviewCount()}');
  }

  // --- NEW: STATISTICS GETTERS for Advanced Viewer ---

  /// Returns the total number of unique problems tracked by the SRI system.
  int get totalTrackedProblems => _sriDatabase.length;

  /// Returns the number of problems considered "mastered".
  int get masteredProblemCount {
    return _sriDatabase.keys.where((id) => isProblemMastered(id)).length;
  }

  /// Returns the number of problems currently being learned (not yet mastered).
  int get learningProblemCount => totalTrackedProblems - masteredProblemCount;

  /// Returns a list of the most difficult problems (lowest easiness factor).
  List<SriProblemData> getMostDifficultProblems({int limit = 5}) {
    final problems = _sriDatabase.values.toList();
    // Sort by easiness factor, ascending.
    problems.sort((a, b) => a.easinessFactor.compareTo(b.easinessFactor));
    return problems.take(limit).toList();
  }

  /// Returns a list of the problems with the highest failure counts.
  List<SriProblemData> getMostFailedProblems({int limit = 5}) {
    final problems = _sriDatabase.values.toList();
    // Sort by failure count, descending, then by easiness factor as a tie-breaker.
    problems.sort((a, b) {
      final failCompare = b.failureCount.compareTo(a.failureCount);
      if (failCompare != 0) return failCompare;
      return a.easinessFactor.compareTo(b.easinessFactor);
    });
    // Filter out problems that have never been failed
    return problems.where((p) => p.failureCount > 0).take(limit).toList();
  }
}

/// NEW: A helper to get a display-friendly label for a number range.
/// TODO: might use the S.of(context) localization instance.
String getNumberRangeLabel(NumberRange range) {
    switch (range) {
        case NumberRange.range1_10: return '1-10';
        case NumberRange.range11_20: return '11-20';
        case NumberRange.range21_50: return '21-50';
        case NumberRange.range51plus: return '51+';
    }
    }

class OperationStat {
  final int tracked;
  final int mastered;
  final double averageEasiness; // NEW: To track average E-Factor
  double get masteryPercent => tracked > 0 ? mastered / tracked : 0.0;

  OperationStat({
    this.tracked = 0,
    this.mastered = 0,
    this.averageEasiness = 2.5, // Default E-Factor
  });
}


/// NEW: Defines the number range buckets used for analysis.
enum NumberRange { range1_10, range11_20, range21_50, range51plus }