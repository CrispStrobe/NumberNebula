// Unit tests for scoreToStars() and kStarThresholds in tuning.dart.
//
// scoreToStars is a pure function: (gameType, score, wasSuccessful) → 0-3 stars.
// We test:
//   * Loss always yields 0 stars
//   * Score 0 on a win yields 1 star
//   * Known games hit their per-game thresholds correctly
//   * Unknown games fall back to the generic percentile brackets
//   * Boundary values (exactly at threshold)

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/tuning.dart';

void main() {
  group('scoreToStars — loss always returns 0', () {
    test('loss returns 0 regardless of score', () {
      expect(scoreToStars('kenken', 9999, false), 0);
      expect(scoreToStars('bubble_math', 500, false), 0);
      expect(scoreToStars('unknown_game', 1000, false), 0);
    });
  });

  group('scoreToStars — win with score 0 returns 1', () {
    test('zero-score win gets 1 star', () {
      expect(scoreToStars('kenken', 0, true), 1);
      expect(scoreToStars('bubble_math', 0, true), 1);
    });
  });

  group('scoreToStars — known games use kStarThresholds', () {
    test('kenken thresholds: [300, 800, 1200]', () {
      // kStarThresholds['kenken'] = [300, 800, 1200]
      expect(scoreToStars('kenken', 100, true), 1); // below 300
      expect(scoreToStars('kenken', 300, true), 1); // at 1-star min but below 2-star
      expect(scoreToStars('kenken', 799, true), 1); // just below 2-star
      expect(scoreToStars('kenken', 800, true), 2); // exactly 2-star
      expect(scoreToStars('kenken', 1199, true), 2); // just below 3-star
      expect(scoreToStars('kenken', 1200, true), 3); // exactly 3-star
      expect(scoreToStars('kenken', 5000, true), 3); // well above
    });

    test('bubble_math thresholds: [50, 200, 400]', () {
      expect(scoreToStars('bubble_math', 30, true), 1);
      expect(scoreToStars('bubble_math', 200, true), 2);
      expect(scoreToStars('bubble_math', 400, true), 3);
      expect(scoreToStars('bubble_math', 399, true), 2);
    });

    test('asteroid_duel thresholds: [100, 350, 500]', () {
      expect(scoreToStars('asteroid_duel', 50, true), 1);
      expect(scoreToStars('asteroid_duel', 350, true), 2);
      expect(scoreToStars('asteroid_duel', 500, true), 3);
    });

    test('space_station_gridlock thresholds: [250, 700, 1000]', () {
      expect(scoreToStars('space_station_gridlock', 100, true), 1);
      expect(scoreToStars('space_station_gridlock', 700, true), 2);
      expect(scoreToStars('space_station_gridlock', 1000, true), 3);
    });
  });

  group('scoreToStars — unknown game uses generic fallback', () {
    test('fallback brackets: <400 → 1, 400-799 → 2, >=800 → 3', () {
      const unknown = 'totally_fake_game_xyz';
      expect(scoreToStars(unknown, 50, true), 1);
      expect(scoreToStars(unknown, 399, true), 1);
      expect(scoreToStars(unknown, 400, true), 2);
      expect(scoreToStars(unknown, 799, true), 2);
      expect(scoreToStars(unknown, 800, true), 3);
      expect(scoreToStars(unknown, 5000, true), 3);
    });
  });

  group('kStarThresholds completeness', () {
    test('every game in the map has exactly 3 threshold values', () {
      for (final entry in kStarThresholds.entries) {
        expect(entry.value.length, 3,
            reason: '${entry.key} should have [1-star, 2-star, 3-star]');
      }
    });

    test('thresholds are strictly ascending for every game', () {
      for (final entry in kStarThresholds.entries) {
        expect(entry.value[0] < entry.value[1], isTrue,
            reason: '${entry.key}: 1-star < 2-star');
        expect(entry.value[1] < entry.value[2], isTrue,
            reason: '${entry.key}: 2-star < 3-star');
      }
    });

    test('all thresholds are positive', () {
      for (final entry in kStarThresholds.entries) {
        for (final v in entry.value) {
          expect(v > 0, isTrue,
              reason: '${entry.key}: threshold $v must be > 0');
        }
      }
    });
  });
}
