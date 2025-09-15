// lib/core/services/sri_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/games/models/math_problem.dart';
import '../../features/games/constants/app_constants.dart';

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
    this.easinessFactor = 2.5,
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
    easinessFactor: json['ef'] ?? 2.5,
    repetitions: json['r'] ?? 0,
    nextReviewDate: DateTime.parse(json['next']),
  );
}

// The main service class
class SriService with ChangeNotifier {
  Map<String, SriProblemData> _sriDatabase = {};
  static const _sriStorageKey = 'sri_database';
  
  // FIX: Add session tracking to prevent returning same problems repeatedly
  final Set<String> _alreadyReturnedThisSession = {};
  DateTime? _sessionStartTime;

  // Verbose logging for SRI operations
  void _log(String message) {
    debugPrint('[SRI_SERVICE] 🧠 $message');
  }

  // FIX: Reset session tracking when needed
  void resetSession() {
    _alreadyReturnedThisSession.clear();
    _sessionStartTime = DateTime.now();
    _log('Session reset. Clearing returned problems cache.');
  }

  // FIX: Auto-reset session if it's been more than 10 minutes
  void _checkSessionExpiry() {
    if (_sessionStartTime == null || 
        DateTime.now().difference(_sessionStartTime!).inMinutes > 10) {
      resetSession();
    }
  }

  // Generate a unique, consistent ID for any math problem
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
      // This case should not be reached with a valid enum.
      throw Exception("Unknown MathOperation type for SRI ID generation: ${problem.operation}");
    }
  }
  
  bool isProblemMastered(String problemId) {
    final data = _sriDatabase[problemId];
    if (data == null) return false;

    // Define "mastery" as:
    // - At least 3 successful attempts in a row (repetitions)
    // - High easiness factor (the problem is consistently easy for the player)
    // - Very few or no failures
    final isMastered = data.repetitions >= 3 && data.easinessFactor > 4.0 && data.failureCount <= 1;

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
    
    // Reset session on load
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

    // Get existing data or create a new entry
    final data = _sriDatabase[problemId] ?? SriProblemData(
      problemId: problemId,
      nextReviewDate: DateTime.now(),
    );

    if (wasCorrect) {
      data.successCount++;
    } else {
      data.failureCount++;
    }

    // Simplified SM-2 algorithm for spaced repetition
    // Quality of response (q): 5 for correct, 1 for incorrect
    final q = wasCorrect ? 5 : 1;

    if (q < 3) {
      // Incorrect response: reset repetition count
      data.repetitions = 0;
    } else {
      data.repetitions++;
    }

    // Update easiness factor
    data.easinessFactor = data.easinessFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (data.easinessFactor < 1.3) data.easinessFactor = 1.3;

    // Calculate next review interval
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
    // Auto-save on every response for robustness
    saveSriData();
  }

  // FIX: Enhanced getProblemsForReview with session tracking and exclusion support
  List<String> getProblemsForReview({
    int limit = 5, 
    Set<String>? excludeIds,
    bool resetSessionFirst = false
  }) {
    // Auto-reset session if expired or explicitly requested
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

    // Sort by the most difficult (lowest easiness factor) and longest overdue
    reviewable.sort((a, b) {
        int efComparison = a.easinessFactor.compareTo(b.easinessFactor);
        if (efComparison != 0) return efComparison;
        return a.nextReviewDate.compareTo(b.nextReviewDate);
    });
    
    final problemIds = reviewable.map((data) => data.problemId).take(limit).toList();
    
    // Track returned problems to avoid duplicates
    _alreadyReturnedThisSession.addAll(problemIds);
    
    _log('Found ${problemIds.length} NEW problems due for review (excluding ${allExcluded.length} already returned/excluded).');
    if (problemIds.isNotEmpty) {
      _log('Returning: ${problemIds.join(", ")}');
    }
    
    return problemIds;
  }

  // FIX: Convenience method to get available review count without returning problems
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

  // FIX: Method to clear session and get fresh problems (useful for new games)
  List<String> getFreshProblemsForReview({int limit = 5, Set<String>? excludeIds}) {
    return getProblemsForReview(
      limit: limit, 
      excludeIds: excludeIds, 
      resetSessionFirst: true
    );
  }

  // Debug method to see current session state
  void debugPrintSessionState() {
    _log('SESSION DEBUG: ${_alreadyReturnedThisSession.length} problems returned this session');
    _log('Returned problems: ${_alreadyReturnedThisSession.join(", ")}');
    _log('Available for review: ${getAvailableReviewCount()}');
  }
}