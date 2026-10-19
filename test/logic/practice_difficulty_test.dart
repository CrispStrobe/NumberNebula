import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/features/games/constants/difficulty_manager.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/services/generation_configs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'arithmetic uses the selected easy/normal/challenge grade consistently',
    () {
      final provider = GameProvider(
        progressService: ProgressService(),
        sriService: SriService(),
        cognitiveProfileService: CognitiveProfileService(),
      )..setGrade(3);
      for (final mode in DifficultyMode.values) {
        provider.setDifficultyMode(mode);
        expect(
          DifficultyManager.getDifficulty(provider, 3).grade,
          provider.effectiveGrade,
        );
        expect(
          provider.grade,
          3,
          reason: 'The official profile grade stays fixed',
        );
        expect(
          DifficultyManager.getDifficulty(provider, 3, gradeOverride: 2).grade,
          2,
        );
      }
      provider.dispose();
    },
  );
  test('introductory triangle structure stages blanks before distractors', () {
    for (var grade = 1; grade <= 6; grade++) {
      var nodes = 0, blanks = 0, choices = 0;
      for (var level = 1; level <= 20; level++) {
        final profile = MagicTriangleGenerationConfig(grade, level);
        expect(profile.circlesPerSide, greaterThanOrEqualTo(nodes));
        expect(profile.hiddenCount, greaterThanOrEqualTo(blanks));
        expect(
          profile.hiddenCount + profile.decoyCount,
          greaterThanOrEqualTo(choices),
        );
        if (level <= 4) {
          expect(profile.decoyCount, 0);
          expect(profile.requireDeductionChain, isTrue);
        }
        nodes = profile.circlesPerSide;
        blanks = profile.hiddenCount;
        choices = blanks + profile.decoyCount;
      }
    }
  });
}
