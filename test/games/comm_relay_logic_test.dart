// Unit tests for comm_relay_logic.dart.
//
// Tests pure cipher logic: Caesar encrypt/decrypt, Atbash self-inverse,
// keyword cipher, puzzle generation invariants, and answer validation.

import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/comm_relay_logic.dart';

void main() {
  group('Caesar cipher', () {
    test('encrypt then decrypt recovers original (uppercase)', () {
      const plain = 'HELLO WORLD';
      for (int shift = 0; shift < 26; shift++) {
        final encrypted = CommRelayPuzzle.encryptCaesar(plain, shift);
        final decrypted = CommRelayPuzzle.decryptCaesar(encrypted, shift);
        expect(decrypted, plain,
            reason: 'Caesar shift=$shift should be reversible');
      }
    });

    test('encrypt then decrypt recovers original (lowercase)', () {
      const plain = 'hello world';
      for (int shift = 0; shift < 26; shift++) {
        final encrypted = CommRelayPuzzle.encryptCaesar(plain, shift);
        final decrypted = CommRelayPuzzle.decryptCaesar(encrypted, shift);
        expect(decrypted, plain);
      }
    });

    test('shift 0 is identity', () {
      const text = 'STAR CHART';
      expect(CommRelayPuzzle.encryptCaesar(text, 0), text);
      expect(CommRelayPuzzle.decryptCaesar(text, 0), text);
    });

    test('shift 26 is identity', () {
      const text = 'ORBIT';
      expect(CommRelayPuzzle.encryptCaesar(text, 26), text);
    });

    test('known Caesar shift 3: A->D, Z->C', () {
      expect(CommRelayPuzzle.encryptCaesar('A', 3), 'D');
      expect(CommRelayPuzzle.encryptCaesar('Z', 3), 'C');
      expect(CommRelayPuzzle.encryptCaesar('ABC', 3), 'DEF');
    });

    test('non-alpha characters are preserved', () {
      const text = 'HELLO, WORLD! 123';
      final encrypted = CommRelayPuzzle.encryptCaesar(text, 5);
      // Spaces, punctuation, digits unchanged
      expect(encrypted.contains(','), isTrue);
      expect(encrypted.contains('!'), isTrue);
      expect(encrypted.contains(' '), isTrue);
      expect(encrypted.contains('123'), isTrue);
    });
  });

  group('Atbash cipher', () {
    test('Atbash is self-inverse', () {
      const plain = 'HELLO WORLD';
      final encrypted = CommRelayPuzzle.encryptAtbash(plain);
      final decrypted = CommRelayPuzzle.encryptAtbash(encrypted);
      expect(decrypted, plain,
          reason: 'Atbash applied twice should recover original');
    });

    test('Atbash is self-inverse (lowercase)', () {
      const plain = 'hello world';
      final encrypted = CommRelayPuzzle.encryptAtbash(plain);
      final decrypted = CommRelayPuzzle.encryptAtbash(encrypted);
      expect(decrypted, plain);
    });

    test('known Atbash mappings: A<->Z, B<->Y, M<->N', () {
      expect(CommRelayPuzzle.encryptAtbash('A'), 'Z');
      expect(CommRelayPuzzle.encryptAtbash('Z'), 'A');
      expect(CommRelayPuzzle.encryptAtbash('B'), 'Y');
      expect(CommRelayPuzzle.encryptAtbash('M'), 'N');
      expect(CommRelayPuzzle.encryptAtbash('N'), 'M');
    });

    test('non-alpha characters are preserved', () {
      const text = 'STAR 123!';
      final encrypted = CommRelayPuzzle.encryptAtbash(text);
      expect(encrypted.contains(' '), isTrue);
      expect(encrypted.contains('123'), isTrue);
      expect(encrypted.contains('!'), isTrue);
    });
  });

  group('CommRelayPuzzle.checkAnswer', () {
    test('accepts correct answer (case-insensitive)', () {
      final puzzle = CommRelayPuzzle(
        plainText: 'STAR',
        cipherText: 'VWDU',
        cipherType: CipherType.caesar,
        shiftAmount: 3,
        hintLetters: {},
      );
      expect(puzzle.checkAnswer('STAR'), isTrue);
      expect(puzzle.checkAnswer('star'), isTrue);
      expect(puzzle.checkAnswer('Star'), isTrue);
      expect(puzzle.checkAnswer(' STAR '), isTrue);
    });

    test('rejects wrong answer', () {
      final puzzle = CommRelayPuzzle(
        plainText: 'STAR',
        cipherText: 'VWDU',
        cipherType: CipherType.caesar,
        shiftAmount: 3,
        hintLetters: {},
      );
      expect(puzzle.checkAnswer('MOON'), isFalse);
      expect(puzzle.checkAnswer(''), isFalse);
    });
  });

  group('CommRelayPuzzle.checkShift', () {
    test('correct shift is accepted', () {
      final puzzle = CommRelayPuzzle(
        plainText: 'STAR',
        cipherText: 'VWDU',
        cipherType: CipherType.caesar,
        shiftAmount: 3,
        hintLetters: {},
      );
      expect(puzzle.checkShift(3), isTrue);
      expect(puzzle.checkShift(29), isTrue); // 29 % 26 == 3
    });

    test('wrong shift is rejected', () {
      final puzzle = CommRelayPuzzle(
        plainText: 'STAR',
        cipherText: 'VWDU',
        cipherType: CipherType.caesar,
        shiftAmount: 3,
        hintLetters: {},
      );
      expect(puzzle.checkShift(4), isFalse);
      expect(puzzle.checkShift(0), isFalse);
    });

    test('checkShift returns false for non-Caesar ciphers', () {
      final puzzle = CommRelayPuzzle(
        plainText: 'STAR',
        cipherText: 'HGZI',
        cipherType: CipherType.atbash,
        hintLetters: {},
      );
      expect(puzzle.checkShift(3), isFalse);
    });
  });

  group('CommRelayPuzzle.generate: invariants', () {
    test('grade 1: single word Caesar with shift 1-3', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = CommRelayPuzzle.generate(
          grade: 1,
          level: 1,
          isGerman: false,
          seed: seed,
        );
        expect(puzzle.cipherType, CipherType.caesar);
        expect(puzzle.shiftAmount, inInclusiveRange(1, 3));
        expect(puzzle.plainText.contains(' '), isFalse,
            reason: 'Grade 1 should use single words');

        // Verify cipher text matches encryption
        final expected =
            CommRelayPuzzle.encryptCaesar(puzzle.plainText, puzzle.shiftAmount!);
        expect(puzzle.cipherText, expected);
      }
    });

    test('grade 2: sentence Caesar with shift 1-25', () {
      for (int seed = 0; seed < 5; seed++) {
        final puzzle = CommRelayPuzzle.generate(
          grade: 2,
          level: 1,
          isGerman: false,
          seed: seed,
        );
        expect(puzzle.cipherType, CipherType.caesar);
        expect(puzzle.shiftAmount, inInclusiveRange(1, 25));

        final expected =
            CommRelayPuzzle.encryptCaesar(puzzle.plainText, puzzle.shiftAmount!);
        expect(puzzle.cipherText, expected);
      }
    });

    test('grade 3-4: Atbash cipher text decrypts back to plain', () {
      for (int seed = 0; seed < 20; seed++) {
        final puzzle = CommRelayPuzzle.generate(
          grade: 3,
          level: 1,
          isGerman: false,
          seed: seed,
        );

        if (puzzle.cipherType == CipherType.atbash) {
          // Atbash is self-inverse
          final decrypted = CommRelayPuzzle.encryptAtbash(puzzle.cipherText);
          expect(decrypted, puzzle.plainText);
        }
      }
    });

    test('generated puzzle checkAnswer accepts its own plainText', () {
      for (int grade = 1; grade <= 4; grade++) {
        for (int seed = 0; seed < 3; seed++) {
          final puzzle = CommRelayPuzzle.generate(
            grade: grade,
            level: 1,
            isGerman: false,
            seed: seed,
          );
          expect(puzzle.checkAnswer(puzzle.plainText), isTrue);
        }
      }
    });

    test('German mode generates German words/sentences', () {
      final puzzle = CommRelayPuzzle.generate(
        grade: 1,
        level: 1,
        isGerman: true,
        seed: 0,
      );
      // Just verify it generates successfully and checkAnswer works
      expect(puzzle.plainText.isNotEmpty, isTrue);
      expect(puzzle.checkAnswer(puzzle.plainText), isTrue);
    });
  });
}
