// lib/features/games/services/gridlock_puzzle_tracker.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Tracks which gridlock puzzles have been played by the user
class GridlockPuzzleTracker with ChangeNotifier {
  Set<String> _playedPuzzleIds = {};
  static const _storageKey = 'gridlock_played_puzzles';

  Set<String> get playedPuzzleIds => Set.unmodifiable(_playedPuzzleIds);

  /// Load played puzzle IDs from storage
  Future<void> loadPlayedPuzzles() async {
    if (kDebugMode) debugPrint('[GRIDLOCK_TRACKER] Loading played puzzles...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _playedPuzzleIds = Set<String>.from(jsonList);
        if (kDebugMode) debugPrint('[GRIDLOCK_TRACKER] ✅ Loaded ${_playedPuzzleIds.length} played puzzles');
      } else {
        debugPrint('[GRIDLOCK_TRACKER] No saved data found, starting fresh');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GRIDLOCK_TRACKER] ❌ Error loading data: $e');
      _playedPuzzleIds = {};
    }
    notifyListeners();
  }

  /// Save played puzzle IDs to storage
  Future<void> _savePlayedPuzzles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(_playedPuzzleIds.toList());
      await prefs.setString(_storageKey, jsonString);
      if (kDebugMode) debugPrint('[GRIDLOCK_TRACKER] ✅ Saved ${_playedPuzzleIds.length} played puzzles');
    } catch (e) {
      debugPrint('[GRIDLOCK_TRACKER] ❌ Error saving data: $e');
    }
  }

  /// Mark a puzzle as played
  void markPuzzleAsPlayed(String puzzleId) {
    if (_playedPuzzleIds.add(puzzleId)) {
      if (kDebugMode) debugPrint('[GRIDLOCK_TRACKER] Marked puzzle $puzzleId as played (${_playedPuzzleIds.length} total)');
      _savePlayedPuzzles();
      notifyListeners();
    }
  }

  /// Check if a puzzle has been played
  bool hasPlayedPuzzle(String puzzleId) {
    return _playedPuzzleIds.contains(puzzleId);
  }

  /// Get count of played puzzles
  int get playedCount => _playedPuzzleIds.length;

  /// Reset all played puzzles (useful for testing or reset functionality)
  Future<void> resetPlayedPuzzles() async {
    if (kDebugMode) debugPrint('[GRIDLOCK_TRACKER] Resetting all played puzzles');
    _playedPuzzleIds.clear();
    await _savePlayedPuzzles();
    notifyListeners();
  }

  /// Get played puzzles for a specific complexity range
  Set<String> getPlayedPuzzlesForComplexity(double complexity, {double tolerance = 0.3}) {
    // Filter played puzzles that match the complexity range
    // Puzzle IDs are in format 'GRID_XXX', complexity needs to be derived from the data
    return _playedPuzzleIds.where((id) {
      // This will be used in conjunction with the data file
      return true; // Placeholder - actual filtering done in game logic
    }).toSet();
  }
}