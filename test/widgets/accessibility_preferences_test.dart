import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/core/services/app_haptics.dart';
import 'package:space_math_academy/core/services/progress_service.dart';
import 'package:space_math_academy/core/services/sri_service.dart';
import 'package:space_math_academy/core/services/cognitive_profile_service.dart';
import 'package:space_math_academy/features/games/providers/game_provider.dart';
import 'package:space_math_academy/features/games/mixins/game_animations_mixin.dart';

class AnimationProbe extends StatefulWidget {
  const AnimationProbe({super.key});
  @override
  State<AnimationProbe> createState() => AnimationProbeState();
}

class AnimationProbeState extends State<AnimationProbe>
    with TickerProviderStateMixin, GameAnimationsMixin {
  @override
  void initState() {
    super.initState();
    initGameAnimations();
  }

  @override
  void dispose() {
    disposeGameAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    AppHaptics.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  test('disabled haptics suppress every platform feedback call', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    final gp = GameProvider(
        progressService: ProgressService(),
        sriService: SriService(),
        cognitiveProfileService: CognitiveProfileService());
    gp.setHapticEnabled(false);
    await AppHaptics.lightImpact();
    await AppHaptics.mediumImpact();
    await AppHaptics.heavyImpact();
    await AppHaptics.selectionClick();
    await AppHaptics.vibrate();
    expect(calls, isEmpty);
    gp.setHapticEnabled(true);
    await AppHaptics.selectionClick();
    expect(calls.single.method, 'HapticFeedback.vibrate');
  });
  test('profile reload restores accessibility preferences and legacy defaults',
      () {
    final gp = GameProvider(
        progressService: ProgressService(),
        sriService: SriService(),
        cognitiveProfileService: CognitiveProfileService());
    gp.setHapticEnabled(false);
    gp.setReduceMotion(true);
    final saved = gp.toJson();
    gp.setHapticEnabled(true);
    gp.setReduceMotion(false);
    gp.fromJson(saved);
    expect(gp.hapticEnabled, isFalse);
    expect(AppHaptics.enabled, isFalse);
    expect(gp.reduceMotion, isTrue);
    gp.fromJson({});
    expect(gp.hapticEnabled, isTrue);
    expect(AppHaptics.enabled, isTrue);
    expect(gp.reduceMotion, isFalse);
  });
  testWidgets('system reduced motion stops ambience and resumes on change',
      (tester) async {
    final key = GlobalKey<AnimationProbeState>();
    Widget app(bool reduced) => MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: AnimationProbe(key: key),
        );
    await tester.pumpWidget(app(true));
    final state = key.currentState!;
    expect(state.glowController.isAnimating, isFalse);
    expect(state.pulseController.isAnimating, isFalse);
    expect(state.successController.duration, Duration.zero);
    await tester.pumpWidget(app(false));
    expect(state.glowController.isAnimating, isTrue);
    expect(state.pulseController.isAnimating, isTrue);
    expect(state.successController.duration, const Duration(milliseconds: 600));
    await tester.pumpWidget(const SizedBox());
  });
}
