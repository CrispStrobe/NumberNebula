// lib/features/games/services/comm_relay_logic.dart
import 'dart:math' as math;

/// Cipher types supported by the Comm Relay game.
enum CipherType { caesar, atbash, keyword }

class CommRelayPuzzle {
  final String plainText;
  final String cipherText;
  final CipherType cipherType;
  final int? shiftAmount; // For Caesar cipher
  final String? keyword; // For keyword cipher
  final Map<String, String> hintLetters; // Revealed letter mappings (cipher -> plain)

  CommRelayPuzzle({
    required this.plainText,
    required this.cipherText,
    required this.cipherType,
    this.shiftAmount,
    this.keyword,
    required this.hintLetters,
  });

  /// Check if the player's decoded message matches the plain text.
  bool checkAnswer(String answer) {
    return answer.toUpperCase().trim() == plainText.toUpperCase().trim();
  }

  /// Check if a specific shift value produces the correct decryption (Caesar only).
  bool checkShift(int shift) {
    if (cipherType != CipherType.caesar) return false;
    return shift % 26 == (shiftAmount ?? 0) % 26;
  }

  /// Decrypt the cipher text with a given shift (Caesar only).
  static String decryptCaesar(String text, int shift) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c >= 65 && c <= 90) {
        // Uppercase
        buffer.writeCharCode(((c - 65 - shift) % 26 + 26) % 26 + 65);
      } else if (c >= 97 && c <= 122) {
        // Lowercase
        buffer.writeCharCode(((c - 97 - shift) % 26 + 26) % 26 + 97);
      } else {
        buffer.writeCharCode(c);
      }
    }
    return buffer.toString();
  }

  /// Encrypt with Caesar cipher.
  static String encryptCaesar(String text, int shift) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c >= 65 && c <= 90) {
        buffer.writeCharCode((c - 65 + shift) % 26 + 65);
      } else if (c >= 97 && c <= 122) {
        buffer.writeCharCode((c - 97 + shift) % 26 + 97);
      } else {
        buffer.writeCharCode(c);
      }
    }
    return buffer.toString();
  }

  /// Encrypt with Atbash cipher (A=Z, B=Y, ...).
  static String encryptAtbash(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c >= 65 && c <= 90) {
        buffer.writeCharCode(90 - (c - 65));
      } else if (c >= 97 && c <= 122) {
        buffer.writeCharCode(122 - (c - 97));
      } else {
        buffer.writeCharCode(c);
      }
    }
    return buffer.toString();
  }

  /// Generate a puzzle based on grade and level.
  static CommRelayPuzzle generate({
    required int grade,
    required int level,
    required bool isGerman,
    int? seed,
  }) {
    final random = math.Random(seed);

    final enWords = [
      'STAR', 'MOON', 'SUN', 'ORBIT', 'COMET', 'MARS', 'VENUS',
      'NOVA', 'NEBULA', 'ROCKET', 'PLANET', 'SATURN', 'EARTH', 'SOLAR',
    ];
    final deWords = [
      'STERN', 'MOND', 'SONNE', 'ORBIT', 'KOMET', 'MARS', 'VENUS',
      'NOVA', 'NEBEL', 'RAKETE', 'PLANET', 'SATURN', 'ERDE', 'SOLAR',
    ];

    final enSentences = [
      'THE STAR IS BRIGHT',
      'MARS HAS TWO MOONS',
      'ORBIT THE PLANET',
      'ROCKET TO THE MOON',
      'VENUS IS HOT',
      'EARTH IS OUR HOME',
      'SOLAR WIND BLOWS',
      'COMET TAIL GLOWS',
      'NEBULA FORMS STARS',
      'SATURN HAS RINGS',
    ];
    final deSentences = [
      'DER STERN LEUCHTET',
      'MARS HAT ZWEI MONDE',
      'ORBIT DEN PLANETEN',
      'RAKETE ZUM MOND',
      'VENUS IST HEISS',
      'ERDE IST UNSER HEIM',
      'KOMET SCHWEIF LEUCHTET',
      'NEBEL FORMT STERNE',
      'SATURN HAT RINGE',
      'NOVA STRAHLT HELL',
    ];

    final words = isGerman ? deWords : enWords;
    final sentences = isGerman ? deSentences : enSentences;

    if (grade <= 1) {
      // Simple Caesar, shift 1-3, single word
      final shift = 1 + random.nextInt(3);
      final word = words[random.nextInt(words.length)];
      final cipher = encryptCaesar(word, shift);

      return CommRelayPuzzle(
        plainText: word,
        cipherText: cipher,
        cipherType: CipherType.caesar,
        shiftAmount: shift,
        hintLetters: {},
      );
    } else if (grade <= 2) {
      // Caesar, shift 1-25, sentence
      final shift = 1 + random.nextInt(25);
      final sentence = sentences[random.nextInt(sentences.length)];
      final cipher = encryptCaesar(sentence, shift);

      return CommRelayPuzzle(
        plainText: sentence,
        cipherText: cipher,
        cipherType: CipherType.caesar,
        shiftAmount: shift,
        hintLetters: {},
      );
    } else {
      // Grade 3-4: Atbash or keyword cipher with hint letters
      final useAtbash = random.nextBool();
      final sentence = sentences[random.nextInt(sentences.length)];

      if (useAtbash) {
        final cipher = encryptAtbash(sentence);

        // Reveal some hint letters
        final hints = <String, String>{};
        final uniqueLetters = sentence.replaceAll(' ', '').split('').toSet().toList();
        uniqueLetters.shuffle(random);
        final hintCount = (uniqueLetters.length * 0.3).ceil();
        for (int i = 0; i < hintCount && i < uniqueLetters.length; i++) {
          final plain = uniqueLetters[i];
          final encrypted = encryptAtbash(plain);
          hints[encrypted] = plain;
        }

        return CommRelayPuzzle(
          plainText: sentence,
          cipherText: cipher,
          cipherType: CipherType.atbash,
          hintLetters: hints,
        );
      } else {
        // Keyword cipher: use a shifted alphabet built from a keyword
        final keywords = ['SPACE', 'ORBIT', 'LUNAR', 'NEBULA', 'COMET'];
        final kw = keywords[random.nextInt(keywords.length)];
        final cipher = _encryptKeyword(sentence, kw);

        final hints = <String, String>{};
        final uniqueLetters = sentence.replaceAll(' ', '').split('').toSet().toList();
        uniqueLetters.shuffle(random);
        final hintCount = (uniqueLetters.length * 0.3).ceil();
        for (int i = 0; i < hintCount && i < uniqueLetters.length; i++) {
          final plain = uniqueLetters[i];
          final encrypted = _encryptKeyword(plain, kw);
          hints[encrypted] = plain;
        }

        return CommRelayPuzzle(
          plainText: sentence,
          cipherText: cipher,
          cipherType: CipherType.keyword,
          keyword: kw,
          hintLetters: hints,
        );
      }
    }
  }

  /// Build a substitution alphabet from a keyword and encrypt.
  static String _encryptKeyword(String text, String keyword) {
    // Build cipher alphabet: keyword letters (no duplicates) + remaining letters
    final seen = <String>{};
    final cipherAlphabet = <String>[];

    for (final c in keyword.toUpperCase().split('')) {
      if (!seen.contains(c)) {
        seen.add(c);
        cipherAlphabet.add(c);
      }
    }
    for (int i = 0; i < 26; i++) {
      final letter = String.fromCharCode(65 + i);
      if (!seen.contains(letter)) {
        seen.add(letter);
        cipherAlphabet.add(letter);
      }
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c >= 65 && c <= 90) {
        buffer.write(cipherAlphabet[c - 65]);
      } else if (c >= 97 && c <= 122) {
        buffer.write(cipherAlphabet[c - 97].toLowerCase());
      } else {
        buffer.writeCharCode(c);
      }
    }
    return buffer.toString();
  }
}
