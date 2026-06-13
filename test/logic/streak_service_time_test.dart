import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/streak_service.dart';

void main() {
  group('StreakService with injected clock', () {
    late DateTime fakeNow;
    late StreakService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeNow = DateTime(2026, 6, 10, 12, 0); // Tuesday noon
      service = StreakService(getNow: () => fakeNow);
    });

    test('markPlayed starts a streak of 1', () async {
      await service.markPlayed();
      expect(service.currentStreak, 1);
      expect(service.longestStreak, 1);
    });

    test('markPlayed twice same day is idempotent', () async {
      await service.markPlayed();
      fakeNow = DateTime(2026, 6, 10, 18, 0); // same day, evening
      await service.markPlayed();
      expect(service.currentStreak, 1);
    });

    test('consecutive days grow the streak', () async {
      await service.markPlayed();
      // Next day
      fakeNow = DateTime(2026, 6, 11, 9, 0);
      await service.markPlayed();
      expect(service.currentStreak, 2);
      // Day after
      fakeNow = DateTime(2026, 6, 12, 9, 0);
      await service.markPlayed();
      expect(service.currentStreak, 3);
      expect(service.longestStreak, 3);
    });

    test('skipping a day resets streak to 1', () async {
      await service.markPlayed();
      fakeNow = DateTime(2026, 6, 11, 9, 0);
      await service.markPlayed();
      expect(service.currentStreak, 2);
      // Skip a day (June 13 — missed June 12)
      fakeNow = DateTime(2026, 6, 13, 9, 0);
      await service.markPlayed();
      expect(service.currentStreak, 1);
      expect(service.longestStreak, 2); // previous best preserved
    });

    test('load heals stale streak', () async {
      // Play for 3 days
      await service.markPlayed();
      fakeNow = DateTime(2026, 6, 11, 9, 0);
      await service.markPlayed();
      fakeNow = DateTime(2026, 6, 12, 9, 0);
      await service.markPlayed();
      expect(service.currentStreak, 3);

      // Create a new service instance 5 days later — streak should heal to 0
      fakeNow = DateTime(2026, 6, 17, 9, 0);
      final service2 = StreakService(getNow: () => fakeNow);
      await service2.load();
      expect(service2.currentStreak, 0);
      expect(service2.longestStreak, 3); // best ever preserved
    });

    test('playedToday uses injected clock', () async {
      expect(service.playedToday, false);
      await service.markPlayed();
      expect(service.playedToday, true);

      // Advance to next day
      fakeNow = DateTime(2026, 6, 11, 9, 0);
      expect(service.playedToday, false);
    });
  });
}
