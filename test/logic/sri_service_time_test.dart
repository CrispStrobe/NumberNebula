import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/features/games/constants/app_constants.dart';
import 'package:space_math_academy/features/games/models/math_problem.dart';

void main() {
  group('SriService with injected clock', () {
    late DateTime fakeNow;
    late SriService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      fakeNow = DateTime(2026, 6, 10, 12, 0);
      service = SriService(getNow: () => fakeNow);
      await service.loadSriData();
    });

    MathProblem makeProblem({
      String expression = '2 + 3',
      int answer = 5,
    }) =>
        MathProblem(
          expression: expression,
          answer: answer,
          operation: MathOperation.addition,
          operandA: 2,
          operandB: 3,
          difficulty: 1,
        );

    test('recordResponse schedules next review relative to injected clock',
        () {
      final p = makeProblem();
      service.recordResponse(p, true);

      // After first correct answer, SM-2 schedules review in 1 day.
      // nextReviewDate should be fakeNow + 1 day.
      final problems = service.getProblemsForReview(limit: 10);
      // Not yet due (same day)
      expect(problems, isEmpty);
    });

    test('problems become due when clock advances past review date', () {
      final p = makeProblem();
      service.recordResponse(p, true);

      // Advance 2 days — problem should now be due for review.
      fakeNow = DateTime(2026, 6, 12, 12, 0);
      final due = service.getProblemsForReview(limit: 10);
      expect(due, isNotEmpty);
      expect(due.first, contains('ADD'));
    });

    test('repeated correct answers grow the repetition count', () {
      final p = makeProblem();
      // SM-2: EF starts at 2.5, grows +0.1 per correct answer.
      // Mastery needs EF > 4.0, so 16+ correct answers (2.5 + 16*0.1 = 4.1).
      for (int i = 0; i < 16; i++) {
        service.recordResponse(p, true);
      }

      // After many correct answers, the problem should eventually be mastered
      // (SM-2: reps >= 3 AND EF > 4.0 AND failures <= 1).
      expect(service.isProblemMastered('ADD_2_3'), isTrue);
    });
  });
}
