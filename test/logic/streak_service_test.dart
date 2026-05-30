// Unit tests for StreakService daily-streak tracking.
//
// Time-boundary cases (continue/reset across calendar days) depend on
// DateTime.now(), which the service reads directly with no injectable clock.
// We can't fake that without editing lib/, so we test the deterministic
// behaviours: same-day idempotency, playedToday, longest never regressing,
// and a load() persistence round-trip via SharedPreferences mock storage.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/streak_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load() on a fresh store gives a zeroed, loaded state', () async {
    final s = StreakService();
    expect(s.isLoaded, isFalse);

    await s.load();

    expect(s.isLoaded, isTrue);
    expect(s.currentStreak, 0);
    expect(s.longestStreak, 0);
    expect(s.lastPlayedDay, isNull);
    expect(s.playedToday, isFalse);
  });

  test('first markPlayed today sets current/longest to 1 and playedToday',
      () async {
    final s = StreakService();
    await s.markPlayed();

    expect(s.currentStreak, 1);
    expect(s.longestStreak, 1);
    expect(s.playedToday, isTrue);
    expect(s.lastPlayedDay, isNotNull);
  });

  test('markPlayed is idempotent within the same calendar day', () async {
    final s = StreakService();
    await s.markPlayed();
    final afterFirst = s.lastPlayedDay;

    var notifications = 0;
    s.addListener(() => notifications++);

    // Repeated calls the same day must not change anything.
    await s.markPlayed();
    await s.markPlayed();

    expect(s.currentStreak, 1);
    expect(s.longestStreak, 1);
    expect(s.lastPlayedDay, afterFirst);
    expect(notifications, 0,
        reason: 'no-op same-day calls should not notify listeners');
  });

  test('longest never decreases across markPlayed calls', () async {
    final s = StreakService();
    final longestSamples = <int>[];
    for (var i = 0; i < 5; i++) {
      await s.markPlayed();
      longestSamples.add(s.longestStreak);
    }
    // Each sample must be >= the previous one.
    for (var i = 1; i < longestSamples.length; i++) {
      expect(longestSamples[i], greaterThanOrEqualTo(longestSamples[i - 1]));
    }
    // current can never exceed longest.
    expect(s.currentStreak, lessThanOrEqualTo(s.longestStreak));
  });

  test('markPlayed persists and load() round-trips the stored values',
      () async {
    final writer = StreakService();
    await writer.markPlayed();
    final expectedCurrent = writer.currentStreak;
    final expectedLongest = writer.longestStreak;
    final expectedDay = writer.lastPlayedDay;

    // Verify it landed in the underlying store.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('streak_current'), expectedCurrent);
    expect(prefs.getInt('streak_longest'), expectedLongest);
    expect(prefs.getString('streak_lastDay'), isNotNull);

    // A fresh instance reading the same store reproduces the state.
    final reader = StreakService();
    await reader.load();

    expect(reader.currentStreak, expectedCurrent);
    expect(reader.longestStreak, expectedLongest);
    expect(reader.lastPlayedDay, expectedDay);
    expect(reader.playedToday, isTrue,
        reason: 'lastPlayedDay was today, so playedToday must be true');
  });

  test('load() heals a stale streak (last played >= 2 days ago resets current)',
      () async {
    // Seed a streak whose last-played day is well in the past so the
    // heal-on-load branch fires deterministically regardless of "today".
    final old = DateTime.now().subtract(const Duration(days: 10));
    final oldDate = DateTime(old.year, old.month, old.day);
    SharedPreferences.setMockInitialValues({
      'streak_current': 7,
      'streak_longest': 12,
      'streak_lastDay': oldDate.toIso8601String(),
    });

    final s = StreakService();
    await s.load();

    expect(s.currentStreak, 0, reason: 'broken streak should reset to 0');
    expect(s.longestStreak, 12, reason: 'longest is preserved across a reset');

    // The reset is persisted too.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('streak_current'), 0);
    expect(prefs.getInt('streak_longest'), 12);
  });

  test('load() preserves a same-day streak (no false heal)', () async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    SharedPreferences.setMockInitialValues({
      'streak_current': 3,
      'streak_longest': 5,
      'streak_lastDay': todayDate.toIso8601String(),
    });

    final s = StreakService();
    await s.load();

    expect(s.currentStreak, 3);
    expect(s.longestStreak, 5);
    expect(s.playedToday, isTrue);
  });
}
