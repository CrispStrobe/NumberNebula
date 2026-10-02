import 'generator_random.dart';
import 'dart:math' as math;
import '../models/math_problem.dart';

const List<String> alienNames = [
  'Zorblings',
  'Glimfoxes',
  'Kraknids',
  'Snazzles',
  'Whifflers',
  'Bloopoids',
  'Drixels',
  'Quazzites',
];

Map<String, dynamic> generateXenobiologyLab(int grade, int level,
    {math.Random? random}) {
  random ??= generatorRandom();
  bool hasThirdType = false;
  String nameA = '', nameB = '', nameC = '';
  int eyesA = 0,
      legsA = 0,
      eyesB = 0,
      legsB = 0,
      countA = 0,
      countB = 0,
      maxSliderValue = 0,
      eyesC = 0,
      legsC = 0,
      countC = 0,
      totalEyes = 0,
      totalLegs = 0;
  final mathProblems = <MathProblem>[];
  hasThirdType = grade >= 3;

  final shuffledNames = List<String>.from(alienNames)..shuffle(random);
  nameA = shuffledNames[0];
  nameB = shuffledNames[1];

  if (grade <= 2) {
    eyesA = random.nextInt(3) + 2;
    legsA = random.nextInt(3) + 2;
    eyesB = random.nextInt(3) + 2;
    legsB = random.nextInt(3) + 2;

    var guard = 0;
    while (eyesA * legsB == eyesB * legsA && guard++ < 500) {
      eyesB = random.nextInt(3) + 2;
      legsB = random.nextInt(3) + 2;
    }

    countA = random.nextInt(5) + 1;
    countB = random.nextInt(5) + 1;
    maxSliderValue = 8;
  } else {
    eyesA = random.nextInt(4) + 2;
    legsA = random.nextInt(5) + 2;
    eyesB = random.nextInt(4) + 2;
    legsB = random.nextInt(5) + 2;

    var guard = 0;
    while (eyesA * legsB == eyesB * legsA && guard++ < 500) {
      eyesB = random.nextInt(4) + 2;
      legsB = random.nextInt(5) + 2;
    }

    countA = random.nextInt(6) + 2;
    countB = random.nextInt(6) + 2;
    maxSliderValue = 12;

    if (hasThirdType) {
      nameC = shuffledNames[2];
      eyesC = random.nextInt(3) + 1;
      legsC = random.nextInt(4) + 2;
      countC = random.nextInt(3) + 1;
    }
  }

  totalEyes =
      countA * eyesA + countB * eyesB + (hasThirdType ? countC * eyesC : 0);
  totalLegs =
      countA * legsA + countB * legsB + (hasThirdType ? countC * legsC : 0);

  mathProblems
      .add(MathProblem.multiplication(countA, eyesA, difficulty: grade));
  mathProblems
      .add(MathProblem.multiplication(countB, legsB, difficulty: grade));
  mathProblems.add(
      MathProblem.addition(countA * eyesA, countB * eyesB, difficulty: grade));

  return {
    '_countA': countA,
    '_countB': countB,
    '_countC': countC,
    '_eyesA': eyesA,
    '_eyesB': eyesB,
    '_eyesC': eyesC,
    '_hasThirdType': hasThirdType,
    '_legsA': legsA,
    '_legsB': legsB,
    '_legsC': legsC,
    '_mathProblems': mathProblems.map((p) => p.toJson()).toList(),
    '_maxSliderValue': maxSliderValue,
    '_nameA': nameA,
    '_nameB': nameB,
    '_nameC': nameC,
    '_totalEyes': totalEyes,
    '_totalLegs': totalLegs
  };
}

/// Accept any nonnegative assignment satisfying the clues visible to the child.
/// Some three-species systems have multiple valid solutions.
bool matchesCensusTotals(Map<String, dynamic> puzzle, int a, int b, int c) {
  final maximum = puzzle['_maxSliderValue'] as int;
  final third = puzzle['_hasThirdType'] == true;
  if (a < 0 || b < 0 || c < 0 || a > maximum || b > maximum || c > maximum) {
    return false;
  }
  final eyes = a * (puzzle['_eyesA'] as int) +
      b * (puzzle['_eyesB'] as int) +
      (third ? c * (puzzle['_eyesC'] as int) : 0);
  final legs = a * (puzzle['_legsA'] as int) +
      b * (puzzle['_legsB'] as int) +
      (third ? c * (puzzle['_legsC'] as int) : 0);
  return eyes == puzzle['_totalEyes'] &&
      legs == puzzle['_totalLegs'] &&
      (!third ||
          a + b + c ==
              (puzzle['_countA'] as int) +
                  (puzzle['_countB'] as int) +
                  (puzzle['_countC'] as int));
}
