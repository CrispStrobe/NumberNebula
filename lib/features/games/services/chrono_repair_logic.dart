import 'generator_random.dart';
import 'dart:math' as math;
import '../models/math_problem.dart';

enum ClockMalfunction { offset, mirror, combined }

Map<String, dynamic> generateChronoRepair(int grade, int level,
    {math.Random? random}) {
  random ??= generatorRandom();
  int correctHour = 1,
      correctMinute = 0,
      displayedHour = 1,
      displayedMinute = 0,
      offsetHours = 0,
      offsetMinutes = 0;
  ClockMalfunction malfunction = ClockMalfunction.offset;
  final mathProblems = <MathProblem>[];
  // Generate a random correct time
  correctHour = random.nextInt(12) + 1; // 1-12
  correctMinute = random.nextInt(12) * 5; // 0, 5, 10, ..., 55

  if (grade <= 1) {
    // Simple offset
    malfunction = ClockMalfunction.offset;
    offsetHours = random.nextInt(3) + 1; // 1-3 hours
    offsetMinutes = 0;
    displayedHour = ((correctHour + offsetHours - 1) % 12) + 1;
    displayedMinute = correctMinute;
  } else if (grade == 2) {
    // Reflect both hands around the vertical axis, including the hour hand's
    // fractional advance. Mirroring each component separately loses an hour
    // whenever the original minute is nonzero.
    malfunction = ClockMalfunction.mirror;
    final reflected = (720 - (correctHour % 12 * 60 + correctMinute)) % 720;
    displayedHour = reflected ~/ 60;
    if (displayedHour == 0) displayedHour = 12;
    displayedMinute = reflected % 60;
  } else {
    // Combined: offset + mirror or offset with minutes
    malfunction = ClockMalfunction.combined;
    offsetHours = random.nextInt(4) + 1;
    offsetMinutes = (random.nextInt(4) + 1) * 15; // 15, 30, 45, 60

    int totalMinutes =
        correctHour * 60 + correctMinute + offsetHours * 60 + offsetMinutes;
    displayedHour = ((totalMinutes ~/ 60) % 12);
    if (displayedHour == 0) displayedHour = 12;
    displayedMinute = totalMinutes % 60;
  }

  // Create MathProblem for SRI tracking
  mathProblems
      .add(MathProblem.addition(correctHour, offsetHours, difficulty: grade));
  if (offsetMinutes > 0) {
    mathProblems.add(
        MathProblem.addition(correctMinute, offsetMinutes, difficulty: grade));
  }

  return {
    '_correctHour': correctHour,
    '_correctMinute': correctMinute,
    '_displayedHour': displayedHour,
    '_displayedMinute': displayedMinute,
    '_malfunction': malfunction.name,
    '_mathProblems': mathProblems.map((p) => p.toJson()).toList(),
    '_offsetHours': offsetHours,
    '_offsetMinutes': offsetMinutes
  };
}
