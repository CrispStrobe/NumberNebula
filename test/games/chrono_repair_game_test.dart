// Unit tests for the mathematical invariants of the Chrono Repair game.
//
// The game logic is fully private inside _ChronoRepairGameState and the
// ClockMalfunction enum. We reimplement the malfunction formulas and test
// that displayed-to-correct time mapping is correct for all malfunction types.

import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

/// Malfunction types matching the game's ClockMalfunction enum.
enum _Malfunction { offset, mirror, combined }

class _ChronoPuzzle {
  final int correctHour;
  final int correctMinute;
  final int displayedHour;
  final int displayedMinute;
  final _Malfunction malfunction;
  final int offsetHours;
  final int offsetMinutes;

  _ChronoPuzzle({
    required this.correctHour,
    required this.correctMinute,
    required this.displayedHour,
    required this.displayedMinute,
    required this.malfunction,
    required this.offsetHours,
    required this.offsetMinutes,
  });

  static _ChronoPuzzle generate(int grade, math.Random random) {
    final correctHour = random.nextInt(12) + 1; // 1-12
    final correctMinute = random.nextInt(12) * 5; // 0,5,...,55

    int displayedHour, displayedMinute;
    _Malfunction malfunction;
    int offsetHours = 0, offsetMinutes = 0;

    if (grade <= 1) {
      malfunction = _Malfunction.offset;
      offsetHours = random.nextInt(3) + 1;
      displayedHour = ((correctHour + offsetHours - 1) % 12) + 1;
      displayedMinute = correctMinute;
    } else if (grade == 2) {
      malfunction = _Malfunction.mirror;
      displayedHour = ((12 - correctHour) % 12);
      if (displayedHour == 0) displayedHour = 12;
      displayedMinute = (60 - correctMinute) % 60;
    } else {
      malfunction = _Malfunction.combined;
      offsetHours = random.nextInt(4) + 1;
      offsetMinutes = (random.nextInt(4) + 1) * 15;

      int totalMinutes =
          correctHour * 60 + correctMinute + offsetHours * 60 + offsetMinutes;
      displayedHour = ((totalMinutes ~/ 60) % 12);
      if (displayedHour == 0) displayedHour = 12;
      displayedMinute = totalMinutes % 60;
    }

    return _ChronoPuzzle(
      correctHour: correctHour,
      correctMinute: correctMinute,
      displayedHour: displayedHour,
      displayedMinute: displayedMinute,
      malfunction: malfunction,
      offsetHours: offsetHours,
      offsetMinutes: offsetMinutes,
    );
  }
}

void main() {
  group('Chrono Repair: offset malfunction (grade 1)', () {
    test('displayed time = correct time + offset hours', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _ChronoPuzzle.generate(1, random);
        expect(p.malfunction, _Malfunction.offset);
        expect(p.offsetHours, inInclusiveRange(1, 3));

        // Verify displayed hour
        final expectedDisplayed =
            ((p.correctHour + p.offsetHours - 1) % 12) + 1;
        expect(p.displayedHour, expectedDisplayed);
        expect(p.displayedMinute, p.correctMinute);
      }
    });

    test('correct hour can be recovered from displayed by subtracting offset',
        () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _ChronoPuzzle.generate(1, random);
        final recovered =
            ((p.displayedHour - p.offsetHours - 1) % 12 + 12) % 12 + 1;
        expect(recovered, p.correctHour);
      }
    });
  });

  group('Chrono Repair: mirror malfunction (grade 2)', () {
    test('mirror reflects hour and minute correctly', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _ChronoPuzzle.generate(2, random);
        expect(p.malfunction, _Malfunction.mirror);

        // Verify mirror formula
        int expectedHour = ((12 - p.correctHour) % 12);
        if (expectedHour == 0) expectedHour = 12;
        expect(p.displayedHour, expectedHour);
        expect(p.displayedMinute, (60 - p.correctMinute) % 60);
      }
    });

    test('mirror is self-inverse: applying mirror twice recovers original', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _ChronoPuzzle.generate(2, random);

        // Apply mirror to the displayed time
        int recoveredHour = ((12 - p.displayedHour) % 12);
        if (recoveredHour == 0) recoveredHour = 12;
        int recoveredMinute = (60 - p.displayedMinute) % 60;

        expect(recoveredHour, p.correctHour);
        expect(recoveredMinute, p.correctMinute);
      }
    });

    test('mirror of specific known values', () {
      // hour 3 -> (12-3)%12 = 9
      int h = ((12 - 3) % 12);
      if (h == 0) h = 12;
      expect(h, 9);

      // hour 12 -> (12-12)%12 = 0 -> 12
      h = ((12 - 12) % 12);
      if (h == 0) h = 12;
      expect(h, 12);

      // hour 6 -> (12-6)%12 = 6
      h = ((12 - 6) % 12);
      if (h == 0) h = 12;
      expect(h, 6);

      // minute 15 -> (60-15)%60 = 45
      expect((60 - 15) % 60, 45);

      // minute 0 -> (60-0)%60 = 0
      expect((60 - 0) % 60, 0);
    });
  });

  group('Chrono Repair: combined malfunction (grade 3-4)', () {
    test('displayed time = correct + offset hours + offset minutes', () {
      final random = math.Random();
      for (int i = 0; i < 5; i++) {
        final p = _ChronoPuzzle.generate(3, random);
        expect(p.malfunction, _Malfunction.combined);
        expect(p.offsetHours, inInclusiveRange(1, 4));
        expect(p.offsetMinutes, isIn([15, 30, 45, 60]));

        // Verify formula
        int totalMinutes = p.correctHour * 60 +
            p.correctMinute +
            p.offsetHours * 60 +
            p.offsetMinutes;
        int expectedHour = ((totalMinutes ~/ 60) % 12);
        if (expectedHour == 0) expectedHour = 12;
        int expectedMinute = totalMinutes % 60;

        expect(p.displayedHour, expectedHour);
        expect(p.displayedMinute, expectedMinute);
      }
    });
  });

  group('Chrono Repair: time value ranges', () {
    test('correct hour is always 1-12', () {
      final random = math.Random();
      for (int grade = 1; grade <= 4; grade++) {
        for (int i = 0; i < 3; i++) {
          final p = _ChronoPuzzle.generate(grade, random);
          expect(p.correctHour, inInclusiveRange(1, 12));
        }
      }
    });

    test('correct minute is always a multiple of 5 in [0, 55]', () {
      final random = math.Random();
      for (int grade = 1; grade <= 4; grade++) {
        for (int i = 0; i < 3; i++) {
          final p = _ChronoPuzzle.generate(grade, random);
          expect(p.correctMinute % 5, 0);
          expect(p.correctMinute, inInclusiveRange(0, 55));
        }
      }
    });

    test('displayed hour is always 1-12', () {
      final random = math.Random();
      for (int grade = 1; grade <= 4; grade++) {
        for (int i = 0; i < 5; i++) {
          final p = _ChronoPuzzle.generate(grade, random);
          expect(p.displayedHour, inInclusiveRange(1, 12));
        }
      }
    });

    test('displayed minute is always 0-59', () {
      final random = math.Random();
      for (int grade = 1; grade <= 4; grade++) {
        for (int i = 0; i < 5; i++) {
          final p = _ChronoPuzzle.generate(grade, random);
          expect(p.displayedMinute, inInclusiveRange(0, 59));
        }
      }
    });
  });
}
