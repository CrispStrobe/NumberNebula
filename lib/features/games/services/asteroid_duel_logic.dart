import 'generator_random.dart';
import 'dart:math' as math;

Map<String, dynamic> generateAsteroidDuel(int grade, int level,
    {math.Random? random}) {
  random ??= generatorRandom();
  int totalAsteroids = 0, maxPerTurn = 0, remaining = 0;
  if (grade <= 1) {
    totalAsteroids = random.nextInt(5) + 8; // 8-12
    maxPerTurn = 3;
  } else if (grade == 2) {
    totalAsteroids = random.nextInt(6) + 12; // 12-17
    maxPerTurn = 3;
  } else if (grade == 3) {
    totalAsteroids = random.nextInt(6) + 16; // 16-21
    maxPerTurn = 4;
  } else {
    totalAsteroids = random.nextInt(8) + 18; // 18-25
    maxPerTurn = 4;
  }

  remaining = totalAsteroids;

  return {
    '_maxPerTurn': maxPerTurn,
    '_remaining': remaining,
    '_totalAsteroids': totalAsteroids
  };
}
