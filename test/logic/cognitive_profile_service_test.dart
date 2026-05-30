// Unit tests for CognitiveProfileService.
//
// Covers: recordAttempt accumulation, the hasMastery gate (minimum
// attempts AND success ratio >= threshold), snapshot independence
// (returned copy must not alias internal state), and the save/load
// persistence round-trip via shared_preferences (mocked).
//
// NOTE: the service has no `clear` method, so the "clear" leg of the
// round-trip is exercised by persisting an empty profile and reloading
// it into a fresh instance (which yields an empty profile).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/models/skill_category.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/features/games/tuning.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('recordAttempt accumulation', () {
    test('accumulates attempts and successes per skill/difficulty', () {
      final svc = CognitiveProfileService();

      svc.recordAttempt(SkillCategory.arithmetic, 1, true);
      svc.recordAttempt(SkillCategory.arithmetic, 1, false);
      svc.recordAttempt(SkillCategory.arithmetic, 1, true);

      final stats = svc.snapshot[SkillCategory.arithmetic]![1]!;
      expect(stats.attempts, 3);
      expect(stats.successes, 2);
      expect(svc.totalAttempts, 3);
    });

    test('keeps separate buckets per difficulty and per skill', () {
      final svc = CognitiveProfileService();

      svc.recordAttempt(SkillCategory.arithmetic, 1, true);
      svc.recordAttempt(SkillCategory.arithmetic, 2, false);
      svc.recordAttempt(SkillCategory.spatial2d, 1, true);

      final snap = svc.snapshot;
      expect(snap[SkillCategory.arithmetic]![1]!.attempts, 1);
      expect(snap[SkillCategory.arithmetic]![2]!.attempts, 1);
      expect(snap[SkillCategory.arithmetic]![2]!.successes, 0);
      expect(snap[SkillCategory.spatial2d]![1]!.successes, 1);
      expect(svc.totalAttempts, 3);
    });
  });

  group('hasMastery gate', () {
    test('false when fewer than the minimum number of attempts', () {
      final svc = CognitiveProfileService();
      // All successes but below the minimum-attempts threshold.
      for (var i = 0; i < kMinAttemptsForMastery - 1; i++) {
        svc.recordAttempt(SkillCategory.arithmetic, 1, true);
      }
      expect(svc.hasMastery(SkillCategory.arithmetic, 1), isFalse);
    });

    test('false for unseen skill/difficulty', () {
      final svc = CognitiveProfileService();
      expect(svc.hasMastery(SkillCategory.logicDeduction, 9), isFalse);
    });

    test('true when attempts >= min AND ratio >= default threshold', () {
      final svc = CognitiveProfileService();
      // 5 attempts, 5 successes => ratio 1.0 >= 0.7, attempts >= min.
      for (var i = 0; i < kMinAttemptsForMastery; i++) {
        svc.recordAttempt(SkillCategory.arithmetic, 1, true);
      }
      expect(svc.hasMastery(SkillCategory.arithmetic, 1), isTrue);
    });

    test('false when enough attempts but ratio below threshold', () {
      final svc = CognitiveProfileService();
      // Drive ratio clearly below 0.7: 2 of 10 succeed = 0.2.
      for (var i = 0; i < 10; i++) {
        svc.recordAttempt(SkillCategory.arithmetic, 1, i < 2);
      }
      expect(svc.hasMastery(SkillCategory.arithmetic, 1), isFalse);
    });

    test('respects a custom threshold argument', () {
      final svc = CognitiveProfileService();
      // 6 of 10 = 0.6: below default 0.7 but at/above a 0.6 threshold.
      for (var i = 0; i < 10; i++) {
        svc.recordAttempt(SkillCategory.arithmetic, 1, i < 6);
      }
      expect(svc.hasMastery(SkillCategory.arithmetic, 1), isFalse);
      expect(
        svc.hasMastery(SkillCategory.arithmetic, 1, threshold: 0.6),
        isTrue,
      );
    });
  });

  group('snapshot independence', () {
    test('mutating the snapshot does not affect internal state', () {
      final svc = CognitiveProfileService();
      svc.recordAttempt(SkillCategory.arithmetic, 1, true);

      final snap = svc.snapshot;
      // Mutate the returned copy aggressively.
      snap[SkillCategory.arithmetic]![1]!.attempts = 999;
      snap[SkillCategory.arithmetic]![1]!.successes = 999;
      snap.clear();

      // Internal state must be untouched.
      final fresh = svc.snapshot;
      expect(fresh[SkillCategory.arithmetic]![1]!.attempts, 1);
      expect(fresh[SkillCategory.arithmetic]![1]!.successes, 1);
      expect(svc.totalAttempts, 1);
    });
  });

  group('save / load round-trip', () {
    test('saved profile reloads into a fresh instance', () async {
      final writer = CognitiveProfileService();
      writer.recordAttempt(SkillCategory.arithmetic, 1, true);
      writer.recordAttempt(SkillCategory.arithmetic, 1, false);
      writer.recordAttempt(SkillCategory.spatial3d, 2, true);
      await writer.saveProfile();

      final reader = CognitiveProfileService();
      await reader.loadProfile();

      final snap = reader.snapshot;
      expect(snap[SkillCategory.arithmetic]![1]!.attempts, 2);
      expect(snap[SkillCategory.arithmetic]![1]!.successes, 1);
      expect(snap[SkillCategory.spatial3d]![2]!.attempts, 1);
      expect(snap[SkillCategory.spatial3d]![2]!.successes, 1);
      expect(reader.totalAttempts, 3);
    });

    test('loading with no stored data yields an empty profile', () async {
      // Fresh mock prefs (set in setUp) => nothing stored.
      final reader = CognitiveProfileService();
      await reader.loadProfile();
      expect(reader.snapshot, isEmpty);
      expect(reader.totalAttempts, 0);
    });

    test('persisting an empty profile clears any previously stored data',
        () async {
      final writer = CognitiveProfileService();
      writer.recordAttempt(SkillCategory.arithmetic, 1, true);
      await writer.saveProfile();

      // Emulate a "clear": a brand-new (empty) profile overwrites storage.
      final cleared = CognitiveProfileService();
      await cleared.saveProfile();

      final reader = CognitiveProfileService();
      await reader.loadProfile();
      expect(reader.snapshot, isEmpty);
      expect(reader.totalAttempts, 0);
    });
  });
}
