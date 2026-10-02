import 'generator_random.dart';
import 'dart:math' as math;
import '../models/math_problem.dart';

const allDenoms = [1, 2, 5, 10, 20, 50];

Map<String, dynamic> generateGalacticMarket(int grade, int level,
    {math.Random? random}) {
  random ??= generatorRandom();
  int unknownCount = 0, correctDenomination = 1, changeTotal = 0;
  List<int> knownCoins = [], denomOptions = [];
  final mathProblems = <MathProblem>[];
  // Unknown coin count — grade sets base, level adds progression
  //   Grade 1: 2 → 4 over 20 levels
  //   Grade 2: 3 → 6 over 20 levels
  //   Grade 3: 4 → 7 over 20 levels
  //   Grade 4: 4 → 8 over 20 levels
  final baseUnknown = [0, 2, 3, 4, 4][grade.clamp(0, 4)];
  final maxUnknown = [0, 4, 6, 7, 8][grade.clamp(0, 4)];
  unknownCount =
      baseUnknown + ((level - 1) * (maxUnknown - baseUnknown) / 19).round();

  // Denomination pool — grade gates which values appear, level expands
  final List<int> availDenoms;
  if (grade <= 1) {
    // Start with [1,2,5], add 10 at L6, add 20 at L14
    availDenoms = [1, 2, 5];
    if (level >= 6) availDenoms.add(10);
    if (level >= 14) availDenoms.add(20);
  } else if (grade <= 2) {
    // Start with [1,2,5,10], add 20 at L4, add 50 at L12
    availDenoms = [1, 2, 5, 10];
    if (level >= 4) availDenoms.add(20);
    if (level >= 12) availDenoms.add(50);
  } else {
    // Full pool from the start; higher denoms make arithmetic harder
    availDenoms = List.of(allDenoms);
  }
  correctDenomination = availDenoms[random.nextInt(availDenoms.length)];

  final unknownTotal = correctDenomination * unknownCount;

  // Known (distractor) coins — more at higher levels for harder sums
  //   Grade 1: 1 → 3 over 20 levels
  //   Grade 2: 2 → 4 over 20 levels
  //   Grade 3+: 2 → 5 over 20 levels
  final baseKnown = grade <= 1 ? 1 : 2;
  final maxKnown = grade <= 1 ? 3 : (grade <= 2 ? 4 : 5);
  final knownCount =
      baseKnown + ((level - 1) * (maxKnown - baseKnown) / 19).round();
  knownCoins = [];
  for (int i = 0; i < knownCount; i++) {
    knownCoins.add(availDenoms[random.nextInt(availDenoms.length)]);
  }

  final knownTotal = knownCoins.fold(0, (s, c) => s + c);
  changeTotal = knownTotal + unknownTotal;

  // Generate denomination options (include correct + distractors)
  final options = <int>{correctDenomination};
  for (final d in availDenoms) {
    options.add(d);
    if (options.length >= 5) break;
  }
  if (options.length < 5) {
    final available = allDenoms.where((d) => !options.contains(d)).toList()
      ..shuffle(random);
    options.addAll(available.take(5 - options.length));
  }
  denomOptions = options.toList()..sort();

  // Create math problem for SRI
  mathProblems
      .add(MathProblem.division(unknownTotal, unknownCount, difficulty: grade));

  return {
    '_changeTotal': changeTotal,
    '_correctDenomination': correctDenomination,
    '_denomOptions': denomOptions,
    '_knownCoins': knownCoins,
    '_mathProblems': mathProblems.map((p) => p.toJson()).toList(),
    '_unknownCount': unknownCount
  };
}
