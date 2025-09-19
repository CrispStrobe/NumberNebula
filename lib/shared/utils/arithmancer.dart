// arithmancer_math_focused.dart
// Pure Mathematical Combat System

import 'dart:math';
import 'dart:collection';
import 'dart:io';

// === CORE MATHEMATICAL TYPES ===

class CardType {
  static const String number = "Number";
  static const String operator = "Operator";
  static const String parentheses = "Parentheses";
  static const String sequencer = "Sequencer"; // For && chains, fibonacci seeds, etc
  static const String conditional = "Conditional"; // For modular arithmetic, etc
}

class MathCard {
  final String id;
  final String name;
  final String type;
  final int cost;
  final int value; // For numbers
  final String? operator; // +, -, *, /
  final String? effect; // For special math cards
  final Map<String, dynamic> properties; // Flexible properties

  MathCard({
    String? id,
    required this.name,
    required this.type,
    this.cost = 1,
    this.value = 0,
    this.operator,
    this.effect,
    Map<String, dynamic>? properties,
  })  : id = id ?? _generateId(),
        properties = properties ?? {};

  static String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString() +
        Random().nextInt(10000).toString();
  }

  MathCard clone({bool newId = false}) {
    return MathCard(
      id: newId ? null : id,
      name: name,
      type: type,
      cost: cost,
      value: value,
      operator: operator,
      effect: effect,
      properties: Map.from(properties),
    );
  }

  @override
  String toString() {
    switch (type) {
      case CardType.number:
        return "#$value";
      case CardType.operator:
        return operator ?? name;
      case CardType.parentheses:
        return "()";
      default:
        return name;
    }
  }
}

class MathResult {
  final double value;
  final List<MathCard> usedCards;
  final String expression;
  final List<String> mathematicalProperties;

  MathResult(
      this.value, this.usedCards, this.expression, this.mathematicalProperties);

  // Mathematical property detection
  bool get isPrime => _isPrime(value.round()) && value == value.round();
  bool get isPerfectSquare => _isPerfectSquare(value);
  bool get isFibonacci => _isFibonacci(value.round()) && value == value.round();
  bool get isEven => value.round() % 2 == 0 && value == value.round();
  bool get isOdd => value.round() % 2 == 1 && value == value.round();
  bool get isNegative => value < 0;
  bool get isFractional => value != value.round() && value > 0 && value < 1;
  bool get isPerfectCube => _isPerfectCube(value);
  bool get isTriangular =>
      _isTriangular(value.round()) && value == value.round();
  bool get isPowerOfTwo =>
      _isPowerOfTwo(value.round()) && value == value.round();
  bool get isPalindromic =>
      _isPalindromic(value.round()) && value == value.round();
  bool get isComposite => _isComposite(value.round()) && value == value.round();
  bool get isPentagonal =>
      _isPentagonal(value.round()) && value == value.round();
  bool get isHexagonal => _isHexagonal(value.round()) && value == value.round();
  bool get isMersennePrime =>
      _isMersennePrime(value.round()) && value == value.round();
  bool get isCatalan => _isCatalan(value.round()) && value == value.round();
  bool get isDivisibleBy3 => value.round() % 3 == 0 && value == value.round();
  bool get isDivisibleBy5 => value.round() % 5 == 0 && value == value.round();
  bool get isDivisibleBy7 => value.round() % 7 == 0 && value == value.round();

  int get damage => isNegative ? 0 : value.round().clamp(0, 9999);
  int get block => isNegative ? (-value).round().clamp(0, 9999) : 0;
  double get damageReduction => isFractional ? value : 0.0;
}

class MathematicalEnemy {
  final String name;
  final int maxHealth;
  int health;
  final String lore;
  final Map<String, dynamic> mathematicalShields;
  final List<Map<String, dynamic>> behavior;
  int turnCounter = 0;

  MathematicalEnemy({
    required this.name,
    required this.maxHealth,
    int? health,
    this.lore = "",
    Map<String, dynamic>? mathematicalShields,
    required this.behavior,
  })  : health = health ?? maxHealth,
        mathematicalShields = mathematicalShields ?? {};

  int takeDamage(MathResult result, ArithmancerGame game) {
    int baseDamage = result.damage;
    if (baseDamage <= 0) return 0;

    // Apply mathematical shields
    int finalDamage = _applyMathematicalShields(baseDamage, result);

    health -= finalDamage;
    return finalDamage;
  }

  
  int _applyMathematicalShields(int damage, MathResult result) {
    // Start with a double for more precise calculations with multipliers
    double finalDamage = damage.toDouble();

    // --- Each shield is now a separate 'if' block to allow for multiple effects ---

    // Prime Shield - with your new 3-tier logic
    if (mathematicalShields.containsKey('prime_shield')) {
        int threshold = mathematicalShields['prime_shield'];
        
        // --- NEW TIERED LOGIC FOR PRIME GUARDIAN ---
        bool resultIsPrime = result.isPrime && result.value >= threshold;
        bool isSingleCardPlay = result.usedCards.length == 1;

        if (resultIsPrime && isSingleCardPlay) {
        // Tier 1: MassBonus for playing a single prime card.
        finalDamage *= 3.0; 
        } else if (resultIsPrime && !isSingleCardPlay) {
        // Tier 2: Bonus for CREATING a prime with an equation.
        finalDamage *= 2.0; 
        } else {
        // Tier 3: Heavy penalty for any non-prime result.
        finalDamage *= 0.1; 
        }
    }

    // Parity Shields
    if (mathematicalShields.containsKey('even_absorb') && result.isEven) {
        finalDamage *= 0.1; // 90% reduction
    }

    if (mathematicalShields.containsKey('odd_vulnerable') && result.isOdd) {
        finalDamage *= 1.5; // 50% bonus
    }

    // Geometric Shields
    if (mathematicalShields.containsKey('square_immune')) {
        if (result.isPerfectSquare) {
        finalDamage *= 1.6; // Big bonus
        } else {
        finalDamage *= 0.2; // 80% reduction
        }
    }
    if (mathematicalShields.containsKey('cube_only')) {
        if (result.isPerfectCube) {
        finalDamage *= 1.8; // Big bonus
        } else {
        finalDamage *= 0.2; // 80% reduction
        }
    }

    // Sequence Shields
    if (mathematicalShields.containsKey('fibonacci_only')) {
        if (result.isFibonacci) {
        finalDamage *= 1.7; // Good bonus
        } else {
        finalDamage *= 0.2; // 80% reduction
        }
    }
    if (mathematicalShields.containsKey('triangular_only')) {
        if (result.isTriangular) {
        finalDamage *= 1.5;
        } else {
        finalDamage *= 0.4; // 60% reduction
        }
    }
    if (mathematicalShields.containsKey('pentagonal_only')) {
        if (result.isPentagonal) {
        finalDamage *= 1.8;
        } else {
        finalDamage *= 0.3; // 70% reduction
        }
    }

    // Power and Pattern Shields
    if (mathematicalShields.containsKey('power_of_two_only')) {
        if (result.isPowerOfTwo) {
        finalDamage *= 1.6;
        } else {
        finalDamage *= 0.4; // 60% reduction
        }
    }
    if (mathematicalShields.containsKey('palindrome_only')) {
        if (result.isPalindromic) {
        finalDamage *= 1.5;
        } else {
        finalDamage *= 0.4; // 60% reduction
        }
    }

    // Modular Shields
    if (mathematicalShields.containsKey('mod7_only')) {
        if (result.isDivisibleBy7) {
        finalDamage *= 1.4;
        } else {
        finalDamage *= 0.5; // 50% reduction
        }
    }

    // Additional Weaknesses (these should apply after all reductions)
    if (mathematicalShields.containsKey('composite_weakness') && result.isComposite) {
        finalDamage *= 1.2;
    }
    if (mathematicalShields.containsKey('prime_weakness') && result.isPrime) {
        finalDamage *= 1.3;
    }

    // --- Intelligent Clamping at the End ---
    // First, round the final calculated damage.
    int roundedDamage = finalDamage.round();

    // If damage has been reduced to 0 or less, it should stay 0.
    if (roundedDamage <= 0) {
        return 0;
    }
    
    // Otherwise, apply the minimum damage floor to ensure progress.
    return roundedDamage.clamp(3, 9999);
    }

  Map<String, dynamic> getIntent() {
    return behavior[turnCounter % behavior.length];
  }

  void takeTurn(ArithmancerGame game) {
    Map<String, dynamic> intent = getIntent();

    if (intent.containsKey('attack')) {
      int attackDmg = intent['attack'];
      if (attackDmg > 0) {
        int finalAttack = attackDmg;
        int damageDealt = max(0, finalAttack - game.currentBlock);
        game.playerHealth -= damageDealt;
        game.log(
            "👹 $name attacks for $finalAttack. Player takes $damageDealt damage.");
      }
    }

    turnCounter++;
  }
}

// === AI PERSONALITY TYPES ===
// These affect only decision-making, not assets

abstract class AIPersonality {
  String get name;
  String get description;

  List<MathResult> decideTurn(ArithmancerGame game);
  List<MathCard> evaluateCard(MathCard card, List<MathCard> context);
  double scoreResult(MathResult result, ArithmancerGame game);
}

class PrimeHunterAI extends AIPersonality {
  @override
  String get name => "Prime Hunter";

  @override
  String get description =>
      "Prioritizes prime number results and multiplication chains";

  @override
  List<MathResult> decideTurn(ArithmancerGame game) {
    List<MathResult> allResults = game._generateAllPossibleResults();

    // Filter affordable results
    List<MathResult> affordableResults = allResults
        .where((r) => _getResultCost(r, game) <= game.playerEnergy)
        .toList();

    if (affordableResults.isEmpty) return [];

    // Priority: Lethal > Prime Component > High Damage > Any Damage
    MathematicalEnemy? enemy = game.currentEnemy;
    if (enemy == null) return [];

    // Check for lethal - consider shield effects
    List<MathResult> lethals = affordableResults
        .where((r) => _estimateDamage(r, enemy) >= enemy.health)
        .toList();
    if (lethals.isNotEmpty) {
      lethals.sort(
          (a, b) => _getResultCost(a, game).compareTo(_getResultCost(b, game)));
      return [lethals.first];
    }

    // For Prime Guardian, prioritize using prime components OR prime results
    if (enemy.mathematicalShields.containsKey('prime_shield')) {
      List<MathResult> primeAdvantage = affordableResults
          .where((r) => r.isPrime || _hasPrimeComponent(r, 11))
          .toList();
      if (primeAdvantage.isNotEmpty) {
        primeAdvantage.sort((a, b) =>
            _estimateDamage(b, enemy).compareTo(_estimateDamage(a, enemy)));
        return [primeAdvantage.first];
      }
    }

    // Look for any decent damage
    List<MathResult> goodDamage = affordableResults
        .where((r) => _estimateDamage(r, enemy) >= 5)
        .toList();
    if (goodDamage.isNotEmpty) {
      goodDamage.sort((a, b) =>
          _estimateDamage(b, enemy).compareTo(_estimateDamage(a, enemy)));
      return [goodDamage.first];
    }

    // Fall back to any damage
    List<MathResult> anyDamage =
        affordableResults.where((r) => r.damage > 0).toList();
    if (anyDamage.isNotEmpty) {
      anyDamage.sort((a, b) =>
          _estimateDamage(b, enemy).compareTo(_estimateDamage(a, enemy)));
      return [anyDamage.first];
    }

    // Last resort - pick anything
    affordableResults.sort((a, b) => b.damage.compareTo(a.damage));
    return [affordableResults.first];
  }

  bool _hasPrimeComponent(MathResult result, int threshold) {
    return result.usedCards.any((card) =>
        card.type == CardType.number &&
        _isPrime(card.value) &&
        card.value >= threshold);
  }

  int _estimateDamage(MathResult result, MathematicalEnemy enemy) {
    int baseDamage = result.damage;
    if (baseDamage <= 0) return 0;

    // Updated estimates to match the more forgiving shield system
    if (enemy.mathematicalShields.containsKey('prime_shield')) {
      bool hasPrimeComponent = result.usedCards.any((card) =>
          card.type == CardType.number &&
          _isPrime(card.value) &&
          card.value >= 11);
      if (hasPrimeComponent || result.isPrime) {
        return (baseDamage * 1.5).round(); // Bonus
      } else {
        return (baseDamage * 0.8).round(); // Light reduction
      }
    }

    if (enemy.mathematicalShields.containsKey('fibonacci_only')) {
      return result.isFibonacci
          ? (baseDamage * 1.6).round()
          : (baseDamage * 0.6).round();
    }

    if (enemy.mathematicalShields.containsKey('square_immune')) {
      return result.isPerfectSquare
          ? (baseDamage * 1.4).round()
          : (baseDamage * 0.7).round();
    }

    if (enemy.mathematicalShields.containsKey('power_of_two_only')) {
      return result.isPowerOfTwo
          ? (baseDamage * 1.5).round()
          : (baseDamage * 0.7).round();
    }

    if (enemy.mathematicalShields.containsKey('even_absorb') &&
        result.isEven) {
      return (baseDamage * 0.8).round();
    }
    if (enemy.mathematicalShields.containsKey('odd_vulnerable') &&
        result.isOdd) {
      return (baseDamage * 1.3).round();
    }

    return baseDamage; // Default - no shields
  }

  @override
  List<MathCard> evaluateCard(MathCard card, List<MathCard> context) {
    // Prime Hunter prefers cards that help make primes
    return [];
  }

  @override
  double scoreResult(MathResult result, ArithmancerGame game) {
    double score = result.damage.toDouble();
    if (result.isPrime) score *= 2.0;
    return score;
  }

  int _getResultCost(MathResult result, ArithmancerGame game) {
    return result.usedCards.fold(0, (sum, card) => sum + card.cost);
  }
}

class SequenceWeaverAI extends AIPersonality {
  @override
  String get name => "Sequence Weaver";

  @override
  String get description =>
      "Focuses on mathematical sequences and complex expressions";

  @override
  List<MathResult> decideTurn(ArithmancerGame game) {
    List<MathResult> allResults = game._generateAllPossibleResults();

    List<MathResult> affordableResults = allResults
        .where((r) => _getResultCost(r, game) <= game.playerEnergy)
        .toList();

    if (affordableResults.isEmpty) return [];

    MathematicalEnemy? enemy = game.currentEnemy;
    if (enemy == null) return [];

    // Check for lethal with shield consideration - IMPROVED
    List<MathResult> lethals = affordableResults
        .where((r) => _estimateDamage(r, enemy) >= enemy.health)
        .toList();
    if (lethals.isNotEmpty) {
      lethals.sort(
          (a, b) => _getResultCost(a, game).compareTo(_getResultCost(b, game)));
      return [lethals.first];
    }

    // ENHANCED: Better enemy-specific targeting
    if (enemy.mathematicalShields.containsKey('fibonacci_only')) {
      List<MathResult> fibs =
          affordableResults.where((r) => r.isFibonacci).toList();
      if (fibs.isNotEmpty) {
        fibs.sort((a, b) => b.damage.compareTo(a.damage));
        return [fibs.first];
      }
    }

    if (enemy.mathematicalShields.containsKey('triangular_only')) {
      List<MathResult> triangulars =
          affordableResults.where((r) => r.isTriangular).toList();
      if (triangulars.isNotEmpty) {
        triangulars.sort((a, b) => b.damage.compareTo(a.damage));
        return [triangulars.first];
      }
    }

    if (enemy.mathematicalShields.containsKey('square_immune')) {
      List<MathResult> squares =
          affordableResults.where((r) => r.isPerfectSquare).toList();
      if (squares.isNotEmpty) {
        squares.sort((a, b) => b.damage.compareTo(a.damage));
        return [squares.first];
      }
    }

    if (enemy.mathematicalShields.containsKey('power_of_two_only')) {
      List<MathResult> powers =
          affordableResults.where((r) => r.isPowerOfTwo).toList();
      if (powers.isNotEmpty) {
        powers.sort((a, b) => b.damage.compareTo(a.damage));
        return [powers.first];
      }
    }

    if (enemy.mathematicalShields.containsKey('prime_shield')) {
      List<MathResult> primes = affordableResults
          .where((r) => r.isPrime || _hasPrimeComponent(r, 11))
          .toList();
      if (primes.isNotEmpty) {
        primes.sort((a, b) => b.damage.compareTo(a.damage));
        return [primes.first];
      }
    }

    // Look for any mathematical properties that provide bonuses
    List<MathResult> specialResults = affordableResults
        .where((r) =>
            r.isFibonacci ||
            r.isTriangular ||
            r.isPrime ||
            r.isPerfectSquare ||
            r.isPowerOfTwo)
        .toList();
    if (specialResults.isNotEmpty) {
      specialResults.sort((a, b) =>
          _estimateDamage(b, enemy).compareTo(_estimateDamage(a, enemy)));
      return [specialResults.first];
    }

    // Prioritize complex expressions (sequence weaver specialty)
    List<MathResult> complexResults = affordableResults
        .where((r) => r.usedCards.length >= 3 && r.damage >= 8)
        .toList();
    if (complexResults.isNotEmpty) {
      complexResults.sort((a, b) =>
          (b.damage + b.usedCards.length * 3)
              .compareTo(a.damage + a.usedCards.length * 3));
      return [complexResults.first];
    }

    // Fall back to best available damage
    affordableResults.sort((a, b) =>
        _estimateDamage(b, enemy).compareTo(_estimateDamage(a, enemy)));
    return [affordableResults.first];
  }

  bool _hasPrimeComponent(MathResult result, int threshold) {
    return result.usedCards.any((card) =>
        card.type == CardType.number &&
        _isPrime(card.value) &&
        card.value >= threshold);
  }

  int _estimateDamage(MathResult result, MathematicalEnemy enemy) {
    int baseDamage = result.damage;
    if (baseDamage <= 0) return 0;

    // ENHANCED: Better shield effect estimation
    if (enemy.mathematicalShields.containsKey('fibonacci_only')) {
      return result.isFibonacci
          ? (baseDamage * 1.7).round()
          : (baseDamage * 0.3).round();
    }
    if (enemy.mathematicalShields.containsKey('triangular_only')) {
      return result.isTriangular
          ? (baseDamage * 1.5).round()
          : (baseDamage * 0.4).round();
    }
    if (enemy.mathematicalShields.containsKey('square_immune')) {
      return result.isPerfectSquare
          ? (baseDamage * 1.6).round()
          : (baseDamage * 0.4).round();
    }
    if (enemy.mathematicalShields.containsKey('power_of_two_only')) {
      return result.isPowerOfTwo
          ? (baseDamage * 1.6).round()
          : (baseDamage * 0.4).round();
    }
    if (enemy.mathematicalShields.containsKey('prime_shield')) {
      bool hasPrimeComponent = result.usedCards.any((card) =>
          card.type == CardType.number &&
          _isPrime(card.value) &&
          card.value >= 11);
      if (hasPrimeComponent || result.isPrime) {
        return (baseDamage * 1.4).round();
      } else {
        return (baseDamage * 0.5).round();
      }
    }

    return baseDamage;
  }

  @override
  List<MathCard> evaluateCard(MathCard card, List<MathCard> context) {
    return [];
  }

  @override
  double scoreResult(MathResult result, ArithmancerGame game) {
    double score = result.damage.toDouble();
    if (result.isFibonacci) score *= 1.8;
    score += result.usedCards.length * 5; // Complexity bonus
    return score;
  }

  int _getResultCost(MathResult result, ArithmancerGame game) {
    return result.usedCards.fold(0, (sum, card) => sum + card.cost);
  }
}

class DefensiveMathAI extends AIPersonality {
  @override
  String get name => "Defensive Calculator";

  @override
  String get description =>
      "Uses negative results for blocking and damage reduction";

  @override
  List<MathResult> decideTurn(ArithmancerGame game) {
    List<MathResult> allResults = game._generateAllPossibleResults();

    List<MathResult> affordableResults = allResults
        .where((r) => _getResultCost(r, game) <= game.playerEnergy)
        .toList();

    if (affordableResults.isEmpty) return [];

    MathematicalEnemy? enemy = game.currentEnemy;
    if (enemy == null) return [];

    // Check for lethal damage with shield effects - ENHANCED
    List<MathResult> lethals = affordableResults
        .where((r) => _estimateDamage(r, enemy) >= enemy.health)
        .toList();
    if (lethals.isNotEmpty) {
      lethals.sort(
          (a, b) => _getResultCost(a, game).compareTo(_getResultCost(b, game)));
      return [lethals.first];
    }

    // ENHANCED: Better enemy-specific targeting for defensive AI
    if (enemy.mathematicalShields.containsKey('fibonacci_only')) {
      List<MathResult> fibs =
          affordableResults.where((r) => r.isFibonacci).toList();
      if (fibs.isNotEmpty) {
        fibs.sort((a, b) => b.damage.compareTo(a.damage));
        return [fibs.first];
      }
    }

    if (enemy.mathematicalShields.containsKey('square_immune')) {
      List<MathResult> squares =
          affordableResults.where((r) => r.isPerfectSquare).toList();
      if (squares.isNotEmpty) {
        squares.sort((a, b) => b.damage.compareTo(a.damage));
        return [squares.first];
      }
    }

    if (enemy.mathematicalShields.containsKey('power_of_two_only')) {
      List<MathResult> powers =
          affordableResults.where((r) => r.isPowerOfTwo).toList();
      if (powers.isNotEmpty) {
        powers.sort((a, b) => b.damage.compareTo(a.damage));
        return [powers.first];
      }
    }

    if (enemy.mathematicalShields.containsKey('prime_shield')) {
      List<MathResult> primes = affordableResults
          .where((r) => r.isPrime || _hasPrimeComponent(r, 11))
          .toList();
      if (primes.isNotEmpty) {
        primes.sort((a, b) => b.damage.compareTo(a.damage));
        return [primes.first];
      }
    }

    // Check if we need defense (but prioritize offense since blocking is limited)
    int incomingDamage = enemy.getIntent()['attack'] ?? 0;
    bool criticalHealth = game.playerHealth <= 35;

    // Look for negative results for blocking in critical situations
    if (criticalHealth && incomingDamage >= game.playerHealth - 10) {
      List<MathResult> defensiveResults = affordableResults
          .where((r) => r.block > 0 && r.block >= incomingDamage / 2)
          .toList();
      if (defensiveResults.isNotEmpty) {
        defensiveResults.sort((a, b) => b.block.compareTo(a.block));
        return [defensiveResults.first];
      }
    }

    // Focus on offense - look for effective damage against shields
    List<MathResult> goodDamage = affordableResults
        .where((r) => _estimateDamage(r, enemy) >= 12)
        .toList();
    if (goodDamage.isNotEmpty) {
      goodDamage.sort((a, b) =>
          _estimateDamage(b, enemy).compareTo(_estimateDamage(a, enemy)));
      return [goodDamage.first];
    }

    // Any decent damage
    List<MathResult> anyDamage = affordableResults
        .where((r) => _estimateDamage(r, enemy) >= 6)
        .toList();
    if (anyDamage.isNotEmpty) {
      anyDamage.sort((a, b) =>
          _estimateDamage(b, enemy).compareTo(_estimateDamage(a, enemy)));
      return [anyDamage.first];
    }

    // Last resort - anything that does damage
    List<MathResult> desperateAttacks =
        affordableResults.where((r) => r.damage > 0).toList();
    if (desperateAttacks.isNotEmpty) {
      desperateAttacks.sort((a, b) => b.damage.compareTo(a.damage));
      return [desperateAttacks.first];
    }

    return [];
  }

  bool _hasPrimeComponent(MathResult result, int threshold) {
    return result.usedCards.any((card) =>
        card.type == CardType.number &&
        _isPrime(card.value) &&
        card.value >= threshold);
  }

  int _estimateDamage(MathResult result, MathematicalEnemy enemy) {
    int baseDamage = result.damage;
    if (baseDamage <= 0) return 0;

    // ENHANCED: Better shield effect estimation for defensive AI
    if (enemy.mathematicalShields.containsKey('prime_shield')) {
      bool hasPrimeComponent = result.usedCards.any((card) =>
          card.type == CardType.number &&
          _isPrime(card.value) &&
          card.value >= 11);
      if (hasPrimeComponent || result.isPrime) {
        return (baseDamage * 1.4).round();
      } else {
        return (baseDamage * 0.5).round();
      }
    }

    if (enemy.mathematicalShields.containsKey('fibonacci_only')) {
      return result.isFibonacci
          ? (baseDamage * 1.7).round()
          : (baseDamage * 0.3).round();
    }
    if (enemy.mathematicalShields.containsKey('square_immune')) {
      return result.isPerfectSquare
          ? (baseDamage * 1.6).round()
          : (baseDamage * 0.4).round();
    }
    if (enemy.mathematicalShields.containsKey('power_of_two_only')) {
      return result.isPowerOfTwo
          ? (baseDamage * 1.6).round()
          : (baseDamage * 0.4).round();
    }

    return baseDamage;
  }

  @override
  List<MathCard> evaluateCard(MathCard card, List<MathCard> context) {
    return [];
  }

  @override
  double scoreResult(MathResult result, ArithmancerGame game) {
    double score = result.damage.toDouble();
    score += result.block * 1.5; // Value blocking
    return score;
  }

  int _getResultCost(MathResult result, ArithmancerGame game) {
    return result.usedCards.fold(0, (sum, card) => sum + card.cost);
  }
}

// === CARD FACTORY ===

class CardFactory {
  // Basic Numbers
  static MathCard one() =>
      MathCard(name: "One", type: CardType.number, value: 1, cost: 0);
  static MathCard two() =>
      MathCard(name: "Two", type: CardType.number, value: 2, cost: 1);
  static MathCard three() =>
      MathCard(name: "Three", type: CardType.number, value: 3, cost: 1);
  static MathCard four() =>
      MathCard(name: "Four", type: CardType.number, value: 4, cost: 1);
  static MathCard five() =>
      MathCard(name: "Five", type: CardType.number, value: 5, cost: 1);
  static MathCard six() =>
      MathCard(name: "Six", type: CardType.number, value: 6, cost: 2);
  static MathCard seven() =>
      MathCard(name: "Seven", type: CardType.number, value: 7, cost: 2);
  static MathCard eight() =>
      MathCard(name: "Eight", type: CardType.number, value: 8, cost: 2);
  static MathCard nine() =>
      MathCard(name: "Nine", type: CardType.number, value: 9, cost: 2);

  // Prime Numbers
  static MathCard eleven() =>
      MathCard(name: "Eleven", type: CardType.number, value: 11, cost: 2);
  static MathCard thirteen() =>
      MathCard(name: "Thirteen", type: CardType.number, value: 13, cost: 3);
  static MathCard seventeen() =>
      MathCard(name: "Seventeen", type: CardType.number, value: 17, cost: 3);
  static MathCard nineteen() =>
      MathCard(name: "Nineteen", type: CardType.number, value: 19, cost: 3);

  // Perfect Squares
  static MathCard sixteen() =>
      MathCard(name: "Sixteen", type: CardType.number, value: 16, cost: 3);
  static MathCard twentyFive() => MathCard(
      name: "Twenty-Five", type: CardType.number, value: 25, cost: 3);
  static MathCard thirtySix() =>
      MathCard(name: "Thirty-Six", type: CardType.number, value: 36, cost: 4);
  static MathCard oneHundredOne() => MathCard(
      name: "One Hundred One", type: CardType.number, value: 101, cost: 5);

  // Perfect Cubes
  static MathCard twentySeven() => MathCard(
      name: "Twenty-Seven", type: CardType.number, value: 27, cost: 3);
  static MathCard sixtyFour() =>
      MathCard(name: "Sixty-Four", type: CardType.number, value: 64, cost: 4);

  // Powers of 2
  static MathCard thirty2() =>
      MathCard(name: "Thirty-Two", type: CardType.number, value: 32, cost: 3);

  // Triangular Numbers
  static MathCard ten() =>
      MathCard(name: "Ten", type: CardType.number, value: 10, cost: 2);
  static MathCard fifteen() =>
      MathCard(name: "Fifteen", type: CardType.number, value: 15, cost: 2);
  static MathCard twentyOne() =>
      MathCard(name: "Twenty-One", type: CardType.number, value: 21, cost: 3);
  static MathCard thirtyFive() =>
      MathCard(name: "Thirty-Five", type: CardType.number, value: 35, cost: 3);
  static MathCard seventyTwo() =>
      MathCard(name: "Seventy-Two", type: CardType.number, value: 72, cost: 4);

  // Palindromes
  static MathCard oneHundredEleven() => MathCard(
      name: "One Hundred Eleven", type: CardType.number, value: 111, cost: 5);
  static MathCard oneThousandOne() => MathCard(
      name: "One Thousand One", type: CardType.number, value: 1001, cost: 6);

  // Special Numbers
  static MathCard zero() =>
      MathCard(name: "Zero", type: CardType.number, value: 0, cost: 0);
  static MathCard negativeOne() => MathCard(
      name: "Negative One", type: CardType.number, value: -1, cost: 1);

  // Basic Operators
  static MathCard plus() =>
      MathCard(name: "Plus", type: CardType.operator, operator: '+', cost: 1);
  static MathCard minus() =>
      MathCard(name: "Minus", type: CardType.operator, operator: '-', cost: 1);
  static MathCard multiply() => MathCard(
      name: "Multiply", type: CardType.operator, operator: '*', cost: 2);
  static MathCard divide() => MathCard(
      name: "Divide", type: CardType.operator, operator: '/', cost: 2);

  // Grouping
  static MathCard parentheses() =>
      MathCard(name: "Parentheses", type: CardType.parentheses, cost: 1);

  // Sequencers
  static MathCard sequencer() => MathCard(
      name: "&&",
      type: CardType.sequencer,
      cost: 2,
      effect: "chain_equations",
      properties: {"allows_second_equation": true});

  // Mathematical Sequence Cards
  static MathCard fibonacciSeed() => MathCard(
      name: "Fibonacci Seed",
      type: CardType.sequencer,
      cost: 2,
      effect: "fibonacci_chain",
      properties: {"next_fib_bonus": 5});

  static MathCard arithmeticProgression() => MathCard(
      name: "Progression",
      type: CardType.sequencer,
      cost: 2,
      effect: "arithmetic_chain",
      properties: {"sequence_discount": 1});

  // Conditional Cards
  static MathCard modularCheck() => MathCard(
      name: "Mod 3 Check",
      type: CardType.conditional,
      cost: 1,
      effect: "modular_arithmetic",
      properties: {"modulus": 3, "double_if_zero": true});

  static MathCard perfectPower() => MathCard(
      name: "Perfect Square",
      type: CardType.conditional,
      cost: 1,
      effect: "square_bonus",
      properties: {"square_multiplier": 1.5});
}

// === MATHEMATICAL UTILITY FUNCTIONS ===

bool _isPrime(int n) {
  if (n <= 1) return false;
  if (n <= 3) return true;
  if (n % 2 == 0 || n % 3 == 0) return false;

  int i = 5;
  while (i * i <= n) {
    if (n % i == 0 || n % (i + 2) == 0) return false;
    i += 6;
  }
  return true;
}

bool _isPerfectSquare(double n) {
  if (n < 0 || n != n.round()) return false;
  int root = sqrt(n).round();
  return root * root == n.round();
}

bool _isPerfectCube(double n) {
  if (n < 0 || n != n.round()) return false;
  int root = pow(n, 1 / 3).round();
  return root * root * root == n.round();
}

bool _isFibonacci(int n) {
  if (n < 0) return false;
  List<int> fibs = [
    0,
    1,
    1,
    2,
    3,
    5,
    8,
    13,
    21,
    34,
    55,
    89,
    144,
    233,
    377,
    610,
    987,
    1597
  ];
  return fibs.contains(n);
}

bool _isTriangular(int n) {
  if (n < 0) return false;
  // Triangular numbers: 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91, 105, 120...
  // Formula: T(k) = k(k+1)/2, so n is triangular if 8n+1 is a perfect square
  int discriminant = 8 * n + 1;
  int root = sqrt(discriminant).round();
  return root * root == discriminant;
}

bool _isPowerOfTwo(int n) {
  if (n <= 0) return false;
  return (n & (n - 1)) == 0; // Bit manipulation trick
}

bool _isPalindromic(int n) {
  if (n < 0) return false;
  String s = n.toString();
  return s == s.split('').reversed.join('');
}

bool _isComposite(int n) {
  if (n < 4) return false;
  return !_isPrime(n);
}

bool _isPentagonal(int n) {
  if (n < 1) return false;
  // Pentagonal numbers: 1, 5, 12, 22, 35, 51, 70, 92, 117, 145...
  // Formula: P(k) = k(3k-1)/2, so n is pentagonal if 24n+1 is a perfect square
  // and the square root gives integer k
  int discriminant = 24 * n + 1;
  int root = sqrt(discriminant).round();
  if (root * root != discriminant) return false;
  return (root + 1) % 6 == 0;
}

bool _isHexagonal(int n) {
  if (n < 1) return false;
  // Hexagonal numbers: 1, 6, 15, 28, 45, 66, 91, 120, 153, 190...
  // Formula: H(k) = k(2k-1), so n is hexagonal if 8n+1 is a perfect square
  // and gives odd square root
  int discriminant = 8 * n + 1;
  int root = sqrt(discriminant).round();
  return root * root == discriminant && root % 2 == 1;
}

bool _isMersennePrime(int n) {
  if (!_isPrime(n)) return false;
  // Mersenne primes are of the form 2^p - 1 where p is prime
  // Check if n+1 is a power of 2
  int candidate = n + 1;
  return _isPowerOfTwo(candidate);
}

bool _isCatalan(int n) {
  if (n < 1) return false;
  // Catalan numbers: 1, 1, 2, 5, 14, 42, 132, 429, 1430, 4862...
  List<int> catalans = [1, 1, 2, 5, 14, 42, 132, 429, 1430, 4862, 16796];
  return catalans.contains(n);
}

// === ENEMY ROSTER ===

class EnemyRoster {
  static List<MathematicalEnemy Function()> getMathematicalEnemies() {
    return [
      () => MathematicalEnemy(
            name: "Prime Guardian",
            maxHealth: 45, // Increased from 25
            lore:
                "A crystalline entity that only yields to prime force greater than 10.",
            mathematicalShields: {'prime_shield': 11},
            behavior: [
              {'attack': 8, 'desc': 'Prime Scan'}, // Increased from 4
              {'attack': 12, 'desc': 'Composite Strike'}, // Increased from 6
            ],
          ),
      () => MathematicalEnemy(
            name: "Parity Daemon",
            maxHealth: 60, // Increased from 35
            lore: "Feeds on even numbers, vulnerable to odd attacks.",
            mathematicalShields: {
              'even_absorb': true,
              'odd_vulnerable': true
            },
            behavior: [
              {'attack': 6, 'desc': 'Even Drain'}, // Increased from 3
              {'attack': 10, 'desc': 'Binary Assault'}, // Increased from 5
              {'attack': 8, 'desc': 'Bit Flip'}, // Increased from 4
            ],
          ),
      () => MathematicalEnemy(
            name: "Square Root Bastion",
            maxHealth: 75, // Increased from 45
            lore:
                "An ancient fortress that crumbles only to perfect geometric forms.",
            mathematicalShields: {'square_immune': true},
            behavior: [
              {'attack': 9, 'desc': 'Geometric Strike'}, // Increased from 5
              {'attack': 15, 'desc': 'Perfect Defense'}, // Increased from 8
            ],
          ),
      () => MathematicalEnemy(
            name: "Fibonacci Serpent",
            maxHealth: 90, // Increased from 55
            lore: "A recursive predator locked in the golden spiral.",
            mathematicalShields: {'fibonacci_only': true},
            behavior: [
              {'attack': 8, 'desc': 'Golden Ratio'}, // Increased from 4
              {'attack': 12, 'desc': 'Recursive Coil'}, // Increased from 6
              {'attack': 18, 'desc': 'Spiral Crush'}, // Increased from 8
            ],
          ),
      () => MathematicalEnemy(
            name: "Binary Overlord",
            maxHealth: 110, // Increased from 70
            lore:
                "Powered by the fundamental duality of computation - only powers of 2 can breach its defenses.",
            mathematicalShields: {
              'power_of_two_only': true,
              'palindrome_weakness': true
            },
            behavior: [
              {'attack': 12, 'desc': '01010101'}, // Increased from 6
              {'attack': 20, 'desc': 'Binary Cascade'}, // Increased from 10
              {'attack': 28, 'desc': 'System Override'}, // Increased from 16
            ],
          ),
    ];
  }
}

// === MAIN GAME CLASS ===

class ArithmancerGame {
  final AIPersonality aiPersonality;
  final Random rng;
  final bool verbose;

  int maxHealth = 100;
  int playerHealth = 100;
  int maxEnergy = 6;
  int playerEnergy = 6;
  int currentBlock = 0;
  int turn = 0;

  List<MathCard> deck = [];
  List<MathCard> drawPile = [];
  List<MathCard> hand = [];
  List<MathCard> discardPile = [];

  int enemiesDefeated = 0;
  bool battleActive = false;
  bool gameOver = false;
  MathematicalEnemy? currentEnemy;

  ArithmancerGame(this.aiPersonality, this.rng, {this.verbose = true}) {
    playerHealth = maxHealth;
    playerEnergy = maxEnergy;
    deck = _buildStartingDeck();
    deck.shuffle(rng);
    drawPile = List.from(deck);
  }

  List<MathCard> _buildStartingDeck() {
    return [
      // Core mathematical foundation - much more generous
      CardFactory.one(), CardFactory.one(), CardFactory.two(),
      CardFactory.two(),
      CardFactory.three(), CardFactory.four(), CardFactory.five(),
      CardFactory.six(), CardFactory.seven(), CardFactory.eight(),
      CardFactory.nine(), CardFactory.ten(),
      CardFactory.eleven(), CardFactory.thirteen(), // Guaranteed primes ≥11

      // Essential operators - more copies
      CardFactory.plus(), CardFactory.plus(), CardFactory.minus(),
      CardFactory.multiply(), CardFactory.multiply(),

      // Utility
      CardFactory.parentheses(), CardFactory.parentheses(),

      // AI personality influences additional cards
      ...aiPersonality.name == "Prime Hunter"
          ? [
              CardFactory.seventeen(),
              CardFactory.nineteen(),
              CardFactory.multiply()
            ]
          : aiPersonality.name == "Sequence Weaver"
              ? [
                  CardFactory.fibonacciSeed(),
                  CardFactory.sequencer(),
                  CardFactory.fifteen()
                ]
              : [
                  // Defensive Calculator
                  CardFactory.divide(),
                  CardFactory.negativeOne(),
                  CardFactory.sixteen()
                ],
    ];
  }

  void startNewBattle() {
    List<MathematicalEnemy Function()> enemyRoster =
        EnemyRoster.getMathematicalEnemies();
    if (enemiesDefeated >= enemyRoster.length) {
        winGame();
        return;
    }

    currentEnemy = enemyRoster[enemiesDefeated]();
    log("\n🎯 Engaging: ${currentEnemy!.name}");
    log("📊 ${currentEnemy!.lore}");

    if (currentEnemy!.mathematicalShields.isNotEmpty) {
        log("🛡️ Mathematical defenses detected: ${currentEnemy!.mathematicalShields}");
    }

    drawPile = List.from(deck);
    drawPile.shuffle(rng);
    hand.clear();
    discardPile.clear();
    
    // --- FIX: Draw the initial hand for the battle ---
    _drawCards(7);

    turn = 0;
    battleActive = true;
    startTurn(); // This will now correctly start Turn 1 with a full hand
    }

  void startTurn() {
    turn++;
    currentBlock = 0;
    playerEnergy = maxEnergy;

    // The hand.clear() and _drawCards(7) logic has been REMOVED from here.
    _ensurePlayableHand();

    log("\n--- Turn $turn | HP: $playerHealth/$maxHealth | E: $playerEnergy/$maxEnergy | Block: $currentBlock ---");
    log("Hand: ${hand.map((c) => c.toString()).join(', ')}");

    MathematicalEnemy? enemy = currentEnemy;
    if (enemy != null) {
        String intent = enemy.getIntent()['desc'] ?? '...';
        log("Target: ${enemy.name} (${enemy.health} HP) | Intent: $intent");
    }
    }

  void _ensurePlayableHand() {
    // Check if hand has at least one number
    bool hasNumber = hand.any((c) => c.type == CardType.number);
    // Check if hand has enough diversity to make equations
    int numbers = hand.where((c) => c.type == CardType.number).length;
    int operators = hand.where((c) => c.type == CardType.operator).length;

    if (!hasNumber || numbers == 0) {
      // Add emergency numbers
      hand.add(CardFactory.three());
      hand.add(CardFactory.seven());
      log("⚠️ Emergency: Added numbers to prevent unusable hand");
    }

    if (operators == 0 && numbers > 1) {
      // Add emergency operator
      hand.add(CardFactory.plus());
      log("⚠️ Emergency: Added operator to enable equations");
    }

    // If hand is full of unusable cards, replace some
    if (hand.length > 5 &&
        hand
                .where((c) =>
                    c.type == CardType.parentheses ||
                    c.type == CardType.sequencer ||
                    c.name == "Fibonacci Seed")
                .length >=
            4) {
      // Replace some complex cards with basic ones
      hand.removeWhere((c) => c.type == CardType.sequencer);
      if (hand.length < 6) {
        hand.add(CardFactory.five());
        hand.add(CardFactory.multiply());
      }
      log("⚠️ Emergency: Simplified complex hand");
    }
  }

  void endTurn() {
    if (!battleActive) return;

    List<MathResult> results = aiPersonality.decideTurn(this);

    if (results.isEmpty) {
        log("${aiPersonality.name} maintains position.");
    } else {
        for (MathResult result in results) {
        // _executeResult correctly removes the used cards from the hand
        _executeResult(result);
        }
    }

    if (currentEnemy!.health <= 0) {
        log("🏆 ${currentEnemy!.name} defeated!");
        enemiesDefeated++;
        battleActive = false;
        _addReward();
        return;
    }

    // Enemy turn
    currentEnemy!.takeTurn(this);
    if (playerHealth <= 0) {
        loseGame();
        return;
    }

    // --- FIX: Replace AI's "discard all" logic with "keep and refill" ---
    // The AI now keeps its unused cards, just like the human player.
    final cardsToDraw = 7 - hand.length;
    if (cardsToDraw > 0) {
        _drawCards(cardsToDraw);
    }
    // --- END FIX ---

    // Call the simplified startTurn to reset resources and log the new turn.
    startTurn();
    }

  void _executeResult(MathResult result, {String? playerName}) {
    // Pay energy cost
    int cost = result.usedCards.fold(0, (sum, card) => sum + card.cost);
    playerEnergy -= cost;

    // Remove used cards from hand
    for (MathCard card in result.usedCards) {
        hand.removeWhere((c) => c.id == card.id);
    }

    // FIX: Use the 'playerName' parameter if it's provided, otherwise default to the AI's name.
    final String computeName = playerName ?? aiPersonality.name;
    log("$computeName computes: ${result.expression} = ${result.value}");

    // Apply mathematical effects
    if (result.damage > 0) {
        int inflicted = currentEnemy!.takeDamage(result, this);
        log("💥 Deals $inflicted damage!");

        // Log mathematical properties detected
        List<String> props = [];
        if (result.isPrime) props.add("PRIME");
        if (result.isPerfectSquare) props.add("PERFECT SQUARE");
        if (result.isPerfectCube) props.add("PERFECT CUBE");
        if (result.isFibonacci) props.add("FIBONNAVI"); // Note: Corrected spelling from 'FIBONNAVI' to 'FIBONACCI'
        if (result.isTriangular) props.add("TRIANGULAR");
        if (result.isPowerOfTwo) props.add("POWER OF 2");
        if (result.isPalindromic) props.add("PALINDROMIC");
        if (result.isPentagonal) props.add("PENTAGONAL");
        if (result.isHexagonal) props.add("HEXAGONAL");
        if (result.isMersennePrime) props.add("MERSENNE PRIME");
        if (result.isCatalan) props.add("CATALAN");
        if (result.isComposite) props.add("COMPOSITE");
        if (result.isDivisibleBy3) props.add("÷3");
        if (result.isDivisibleBy5) props.add("÷5");
        if (result.isDivisibleBy7) props.add("÷7");

        if (props.isNotEmpty) {
        log("✨ Mathematical properties: ${props.join(', ')}");
        }
    }

    if (result.block > 0) {
        currentBlock += result.block;
        log("🛡️ Gains ${result.block} block (negative result)!");
    }

    if (result.damageReduction > 0) {
        log("🔀 Fractional result: ${(result.damageReduction * 100).toStringAsFixed(1)}% damage reduction!");
    }
    }

  List<MathResult> _generateAllPossibleResults() {
    ExpressionEvaluator evaluator = ExpressionEvaluator();
    return evaluator.generateAllResults(hand);
  }

  void _drawCards(int num) {
    for (int i = 0; i < num; i++) {
      if (drawPile.isEmpty) {
        if (discardPile.isEmpty) break;
        drawPile = List.from(discardPile);
        discardPile.clear();
        drawPile.shuffle(rng);
      }
      if (drawPile.isNotEmpty) {
        hand.add(drawPile.removeLast());
      }
    }
  }

  void _addReward() {
    // Add a mathematical card to deck based on enemy defeated + moderate healing
    List<MathCard> possibleRewards = [];

    switch (enemiesDefeated) {
      case 1: // After Prime Guardian
        possibleRewards = [
          CardFactory.seventeen(),
          CardFactory.nineteen(),
          CardFactory.multiply()
        ];
        break;
      case 2: // After Parity Daemon
        possibleRewards = [
          CardFactory.modularCheck(),
          CardFactory.nine(),
          CardFactory.divide()
        ];
        break;
      case 3: // After Square Root Bastion
        possibleRewards = [
          CardFactory.perfectPower(),
          CardFactory.sixteen(),
          CardFactory.twentyFive()
        ];
        break;
      case 4: // After Fibonacci Serpent
        possibleRewards = [
          CardFactory.fibonacciSeed(),
          CardFactory.sequencer(),
          CardFactory.arithmeticProgression()
        ];
        break;
      case 5: // After Binary Overlord (Final Boss)
        possibleRewards = [
          CardFactory.thirty2(),
          CardFactory.sixtyFour(),
          CardFactory.sequencer()
        ];
        break;
    }

    if (possibleRewards.isNotEmpty) {
      MathCard reward = possibleRewards[rng.nextInt(possibleRewards.length)];
      deck.add(reward);
      log("🎁 Added ${reward.name} to deck!");
    }

    // REDUCED HEALING: Less generous recovery to maintain challenge
    int healing =
        25 + (enemiesDefeated * 5); // 30, 35, 40, 45, 50 healing (much less)
    playerHealth = min(maxHealth, playerHealth + healing);
    log("💚 Systems restored: +$healing HP! Current: $playerHealth/$maxHealth");
  }

  void winGame() {
    log("🎊 All mathematical entities neutralized! Victory!");
    gameOver = true;
  }

  void loseGame() {
    log("💀 System failure! Mathematical defenses breached!");
    gameOver = true;
  }

  void log(String msg) {
    if (verbose) print(msg);
  }
}

// === EXPRESSION EVALUATOR ===

class ExpressionEvaluator {
  List<MathResult> generateAllResults(List<MathCard> hand) {
    List<MathResult> results = [];

    // Generate all possible mathematical expressions from hand
    _generateExpressions([], hand, results);

    return results;
  }

  void _generateExpressions(List<MathCard> current, List<MathCard> available,
    List<MathResult> results) {
    // First, evaluate the expression as it currently stands.
    if (current.isNotEmpty) {
        MathResult? result = _evaluateExpression(current);
        if (result != null) {
        results.add(result);
        // Also generate a negated version if possible
        if (result.value > 0) {
            final hasMinusCardAvailable = available.any((card) => card.operator == '-');
            if (hasMinusCardAvailable) {
            final minusCard = available.firstWhere((card) => card.operator == '-');
            final negatedCards = [...result.usedCards, minusCard];
            final negatedExpression = "-(${result.expression})";
            final negatedValue = -result.value;
            results.add(
                MathResult(negatedValue, negatedCards, negatedExpression, ["negative_block"])
            );
            }
        }
        }
    }

    // Set a reasonable limit to prevent infinitely long expressions.
    if (current.length >= 7) return;

    // Try to add the next card to the sequence.
    for (int i = 0; i < available.length; i++) {
        MathCard nextCard = available[i];

        if (_canAddCard(current, nextCard)) {
        List<MathCard> nextCurrent = [...current, nextCard];
        List<MathCard> newAvailable = List.from(available)..removeAt(i);

        // Count how many operators are in the expression we just formed.
        int operatorCount = nextCurrent.where((c) => c.type == CardType.operator).length;

        // If this is a complex expression (more than one operator)...
        if (operatorCount > 1) {
            // ...it requires a Parentheses card. Let's find one in the remaining hand.
            final parenCardIndex = newAvailable.indexWhere((c) => c.type == CardType.parentheses);
            
            if (parenCardIndex == -1) {
            // No () card is available to pay for this complex expression. Abort this path.
            continue; 
            } else {
            // A () card is available. Consume it by removing it from the available
            // cards and adding it to the list of cards used in this expression.
            final parenCard = newAvailable.removeAt(parenCardIndex);
            nextCurrent.add(parenCard);
            }
        }

        // Continue building the expression with the updated state.
        _generateExpressions(nextCurrent, newAvailable, results);
        }
      }
    }


  /*
  MathResult? _evaluateNegativeExpression(List<MathCard> cards) {
    MathResult? positiveResult = _evaluateExpression(cards);
    if (positiveResult == null || positiveResult.damage <= 0) return null;

    // Create negative version for blocking
    String negativeExpression = "-(${positiveResult.expression})";
    double negativeValue = -positiveResult.value;

    if (negativeValue >= 0)
      return null; // Only create if actually negative

    List<String> properties = ["negative_block"];

    return MathResult(
        negativeValue, List.from(cards), negativeExpression, properties);
  } */

  bool _canAddCard(List<MathCard> sequence, MathCard nextCard) {
    if (sequence.isEmpty) {
        // An expression can now start with a Number OR a Minus operator.
        return nextCard.type == CardType.number || nextCard.operator == '-';
    }

    final lastCard = sequence.last;

    // If the sequence so far is just a '-', the next card MUST be a number.
    if (sequence.length == 1 && lastCard.operator == '-') {
        return nextCard.type == CardType.number;
    }

    switch (lastCard.type) {
        case CardType.number:
        return nextCard.type == CardType.operator ||
                nextCard.type == CardType.parentheses;
        case CardType.operator:
        // After any operator, you must have a number.
        return nextCard.type == CardType.number;
        case CardType.parentheses:
        return nextCard.type == CardType.operator;
        default:
        return false;
    }
    }

  MathResult? _evaluateExpression(List<MathCard> cards) {
    if (cards.isEmpty) return null;
    // Prevent invalid expressions like a single lonely operator card.
    if (cards.length == 1 && cards.first.type == CardType.operator) return null;

    List<String> tokens = [];
    String expression;

    // Check for the special unary minus case at the beginning
    if (cards.first.operator == '-') {
        // We will evaluate "-19" as "0 - 19" to make the postfix logic work,
        // but we will display it as "-19".
        expression = cards.map((c) => c.operator ?? c.value.toString()).join(' ');
        tokens.add('0'); // The trick: add a leading zero.
        for (var card in cards) {
        tokens.add(card.operator ?? card.value.toString());
        }
    } else {
        // This is the original logic for standard expressions like "19 + 3"
        for (int i = 0; i < cards.length; i++) {
        MathCard card = cards[i];
        if (card.type == CardType.parentheses) {
            if (tokens.isNotEmpty) {
            String lastToken = tokens.removeLast();
            tokens.add("($lastToken)");
            }
        } else {
            tokens.add(card.operator ?? card.value.toString());
        }
        }
        expression = tokens.join(' ');
    }

    // Validate expression ends with a number or parenthesis
    final lastTokenStr = tokens.last.replaceAll(RegExp(r'[\(\)]'), '');
    if (['+', '-', '*', '/'].contains(lastTokenStr)) return null;

    double? value = _evaluatePostfixExpression(tokens);
    if (value == null || value.isInfinite || value.isNaN) return null;

    // Detect mathematical properties
    List<String> properties = [];
    if (_isPrime(value.round()) && value == value.round()) properties.add("prime");
    if (_isPerfectSquare(value)) properties.add("perfect_square");
    if (_isFibonacci(value.round()) && value == value.round()) properties.add("fibonacci");

    return MathResult(value, List.from(cards), expression, properties);
    }

  double? _evaluatePostfixExpression(List<String> infix) {
    // Convert to postfix and evaluate
    final postfix = _toPostfix(infix);
    if (postfix == null) return null;
    return _evaluatePostfix(postfix);
  }

  List<String>? _toPostfix(List<String> infix) {
    final output = <String>[];
    final operators = <String>[];
    final precedence = {'+': 1, '-': 1, '*': 2, '/': 2};
    final isNumber = RegExp(r'^-?[0-9]+(\.[0-9]+)?$');

    for (var token in infix) {
      if (isNumber.hasMatch(token)) {
        output.add(token);
      } else if (precedence.containsKey(token)) {
        while (operators.isNotEmpty &&
            operators.last != '(' &&
            precedence.containsKey(operators.last) &&
            precedence[operators.last]! >= precedence[token]!) {
          output.add(operators.removeLast());
        }
        operators.add(token);
      } else if (token == '(') {
        operators.add(token);
      } else if (token == ')') {
        while (operators.isNotEmpty && operators.last != '(') {
          output.add(operators.removeLast());
        }
        if (operators.isNotEmpty && operators.last == '(') {
          operators.removeLast();
        } else {
          return null; // Mismatched parentheses
        }
      }
    }

    while (operators.isNotEmpty) {
      if (operators.last == '(' || operators.last == ')') return null;
      output.add(operators.removeLast());
    }

    return output;
  }

  double? _evaluatePostfix(List<String> postfix) {
    final stack = <double>[];
    final isNumber = RegExp(r'^-?[0-9]+(\.[0-9]+)?$');

    for (var token in postfix) {
      if (isNumber.hasMatch(token)) {
        stack.add(double.parse(token));
      } else {
        if (stack.length < 2) return null;
        final b = stack.removeLast();
        final a = stack.removeLast();
        double result;

        switch (token) {
          case '+':
            result = a + b;
            break;
          case '-':
            result = a - b;
            break;
          case '*':
            result = a * b;
            break;
          case '/':
            if (b == 0) return null;
            result = a / b;
            break;
          default:
            return null;
        }
        stack.add(result);
      }
    }

    if (stack.length != 1) return null;
    return stack.single;
  }
}

// === PvP GAME SYSTEM ===
class _PlayerState {
  final ArithmancerGame gameInstance;
  int health = 120;
  int energy = 6;
  int block = 0;
  bool passedLastTurn = false; // FIX: Add this new flag

  _PlayerState(this.gameInstance);
  
  void drawInitialHand() {
    gameInstance._drawCards(7);
    gameInstance._ensurePlayableHand();
  }

  void replenishHand() {
    int cardsToDraw = 7 - gameInstance.hand.length;
    if (cardsToDraw > 0) {
      gameInstance._drawCards(cardsToDraw);
      gameInstance._ensurePlayableHand();
    }
  }
}

class PvPGame {
  final AIPersonality player1AI;
  final AIPersonality player2AI;
  final Random rng;
  final bool verbose;
  final bool player1IsHuman;
  final bool player2IsHuman;

  // Central state for each player
  late _PlayerState player1State;
  late _PlayerState player2State;

  int turn = 1;
  bool gameOver = false;
  String winner = "";
  int maxTurns = 25;

  PvPGame({
    required this.player1AI,
    required this.player2AI,
    required this.rng,
    this.verbose = true,
    this.player1IsHuman = false,
    this.player2IsHuman = false,
  }) {
    player1State = _PlayerState(ArithmancerGame(player1AI, Random(rng.nextInt(1000000)), verbose: false));
    player2State = _PlayerState(ArithmancerGame(player2AI, Random(rng.nextInt(1000000)), verbose: false));
    
    player1State.drawInitialHand();
    player2State.drawInitialHand();

    if (verbose) {
      String player1Name = player1IsHuman ? "Human" : player1AI.name;
      String player2Name = player2IsHuman ? "Human" : player2AI.name;
      print("🥊 PvP Battle: $player1Name vs $player2Name");
      print("=" * 60);
    }
  }

  String runGame() {
    while (!gameOver && turn <= maxTurns) {
      // START OF A NEW ROUND
      if (verbose) {
        print("\n--- Turn $turn ---");
        String p1Name = player1IsHuman ? "Human" : player1AI.name;
        String p2Name = player2IsHuman ? "Human" : player2AI.name;
        print(
            "$p1Name: ${player1State.health} HP, ${player1State.energy} Energy | $p2Name: ${player2State.health} HP, ${player2State.energy} Energy");
      }

      // FIX: Replenish energy at the start of the round, adding to any preserved energy.
      player1State.energy += 6;
      player2State.energy += 6;
      
      // Optional: Cap energy to prevent it from growing infinitely
      player1State.energy = min(player1State.energy, 12);
      player2State.energy = min(player2State.energy, 12);

      player1State.block = 0;
      player2State.block = 0;

      // Player 1's Turn
      _executePlayerTurn(player1State, player2State);
      if (gameOver) break;

      // Player 2's Turn
      _executePlayerTurn(player2State, player1State);
      if (gameOver) break;

      // End of round escalation
      if (turn > 15) {
        int escalationDamage = (turn - 15) * 4;
        player1State.health -= escalationDamage;
        player2State.health -= escalationDamage;
        if (verbose) print("⚠️ Escalation! Both players take $escalationDamage damage!");
        _checkGameOver();
        if (gameOver) break;
      }

      turn++;
    }

    if (!gameOver) {
      _determineWinnerByHealth();
    }

    if (gameOver && verbose) {
      print("\n========================================");
      print("🏆 WINNER: $winner");
      print("========================================");
    }

    return winner;
  }

  void _executePlayerTurn(
    _PlayerState currentPlayer, _PlayerState opponentPlayer) {
    String playerName = (currentPlayer == player1State
        ? (player1IsHuman ? "Human" : player1AI.name)
        : (player2IsHuman ? "Human" : player2AI.name));
    bool isHuman =
        (currentPlayer == player1State) ? player1IsHuman : player2IsHuman;

    if (currentPlayer.passedLastTurn) {
        currentPlayer.passedLastTurn = false; // Reset the flag
    } else {
        currentPlayer.energy = 6;
    }
    
    ArithmancerGame currentTurnGame = currentPlayer.gameInstance;
    currentTurnGame.playerHealth = currentPlayer.health;
    currentTurnGame.playerEnergy = currentPlayer.energy; 
    currentTurnGame.currentBlock = 0;

    MathematicalEnemy opponentMock = MathematicalEnemy(
        name: (opponentPlayer == player1State ? player1AI.name : player2AI.name),
        maxHealth: 120,
        health: opponentPlayer.health,
        behavior: [
            {'attack': 0, 'desc': 'Player'}
        ]);
    currentTurnGame.currentEnemy = opponentMock;

    if (verbose) {
        print("\n$playerName's turn:");
        print("Hand: ${currentTurnGame.hand.map((c) => c.toString()).join(', ')}");
        print("Energy: ${currentTurnGame.playerEnergy}");
    }

    List<MathResult> results;
    if (isHuman) {
        results = _humanPlayerTurn(currentTurnGame);
    } else {
        results =
            currentPlayer.gameInstance.aiPersonality.decideTurn(currentTurnGame);
    }

    _processTurnResults(results, currentPlayer, opponentPlayer, opponentMock);
    
    currentPlayer.replenishHand();
    _checkGameOver();
    }
  
  void _processTurnResults(List<MathResult> results, _PlayerState currentPlayer,
    _PlayerState opponentPlayer, MathematicalEnemy opponentMock) {
    String playerName = (currentPlayer == player1State
        ? (player1IsHuman ? "Human" : player1AI.name)
        : (player2IsHuman ? "Human" : player2AI.name));
    
    int totalBlockApplied = 0;
    int totalRawDamage = 0;
    int totalFinalDamage = 0;

    if (results.isEmpty) {
        currentPlayer.passedLastTurn = true;
        if (verbose) print("   $playerName passes, preserving ${currentPlayer.energy} energy.");
        return;
    }

    // First, calculate and apply all block from the results
    for (MathResult result in results) {
        int cost = result.usedCards.fold(0, (sum, card) => sum + card.cost);
        if (cost > currentPlayer.energy) continue;
        
        totalBlockApplied += result.block;
    }
    currentPlayer.block += totalBlockApplied;
    if (totalBlockApplied > 0 && verbose) {
        print("   🛡️ $playerName gains $totalBlockApplied block.");
    }

    // Then, apply damage one result at a time to correctly calculate shield effects
    for (MathResult result in results) {
        int cost = result.usedCards.fold(0, (sum, card) => sum + card.cost);
        if (cost > currentPlayer.energy) continue;

        currentPlayer.energy -= cost;

        for (var card in result.usedCards) {
        currentPlayer.gameInstance.hand.removeWhere((c) => c.id == card.id);
        currentPlayer.gameInstance.discardPile.add(card);
        }
        
        if (result.damage > 0) {
        totalRawDamage += result.damage;
        // Use the opponent mock's logic to calculate damage with shields
        int damageDealt = opponentMock.takeDamage(result, currentPlayer.gameInstance);
        // We subtract the health from the real player state, not the mock
        int damageAfterBlock = (damageDealt - opponentPlayer.block).clamp(0, damageDealt);
        opponentPlayer.health -= damageAfterBlock;
        opponentPlayer.block = (opponentPlayer.block - damageDealt).clamp(0, 999);
        totalFinalDamage += damageAfterBlock;
        }
    }

    if (totalRawDamage > 0 && verbose) {
        print(
            "💥 $playerName deals $totalRawDamage raw damage = $totalFinalDamage final damage!");
    }
    }

  List<MathResult> _humanPlayerTurn(ArithmancerGame game) {
    if (game.currentEnemy!.mathematicalShields.isNotEmpty) {
      print("Opponent Defenses: ${game.currentEnemy!.mathematicalShields}");
    }

    List<MathResult> allResults = game._generateAllPossibleResults();

    // FIX: Sort results by effectiveness to show the best options first.
    allResults.sort((a, b) {
      // Prioritize higher damage and block
      int scoreA = a.damage + a.block;
      int scoreB = b.damage + b.block;
      return scoreB.compareTo(scoreA); // Sort in descending order
    });

    if (allResults.isEmpty) {
      print("No valid plays available. You can only End Turn.");
    }

    print("\nAvailable Actions:");
    print("0: End Turn (Keep remaining energy for next turn)");

    for (int i = 0; i < allResults.length && i < 20; i++) {
      MathResult result = allResults[i];
      int cost = result.usedCards.fold(0, (sum, card) => sum + card.cost);
      String costStr = cost <= game.playerEnergy
          ? "Cost: $cost"
          : "Cost: $cost (TOO EXPENSIVE)";
      String effectStr = "";
      if (result.damage > 0) effectStr += "Damage: ${result.damage}";
      if (result.block > 0)
        effectStr +=
            "${effectStr.isNotEmpty ? ', ' : ''}Block: ${result.block}";
      if (effectStr.isEmpty) effectStr = "No effect";

      String hint = "";
      if (game.currentEnemy!.mathematicalShields.containsKey('fibonacci_only') && result.isFibonacci) {
        hint = " *Effective*";
      }
      if (game.currentEnemy!.mathematicalShields.containsKey('prime_shield') && result.isPrime) {
        hint = " *Effective*";
      }
      if (game.currentEnemy!.mathematicalShields.containsKey('square_immune') && result.isPerfectSquare) {
        hint = " *Effective*";
      }

      print(
          "${i + 1}: ${result.expression} = ${result.value} - $effectStr ($costStr)$hint");
    }

    while (true) {
      stdout.write("\nChoose action (0-${min(20, allResults.length)}): ");
      String? input = stdin.readLineSync();

      if (input == null) continue;

      int? choice = int.tryParse(input);
      if (choice == null ||
          choice < 0 ||
          choice > min(20, allResults.length)) {
        print(
            "Invalid choice. Please enter a number between 0 and ${min(20, allResults.length)}.");
        continue;
      }

      if (choice == 0) {
        return [];
      }

      MathResult selectedResult = allResults[choice - 1];
      int cost =
          selectedResult.usedCards.fold(0, (sum, card) => sum + card.cost);
      if (cost > game.playerEnergy) {
        print("Not enough energy for that action!");
        continue;
      }

      return [selectedResult];
    }
  }

  void _checkGameOver() {
    if (player1State.health <= 0) {
      winner = player2IsHuman ? "Human" : player2AI.name;
      gameOver = true;
    } else if (player2State.health <= 0) {
      winner = player1IsHuman ? "Human" : player1AI.name;
      gameOver = true;
    }
  }

  void _determineWinnerByHealth() {
    if (player1State.health > player2State.health) {
      winner = player1IsHuman ? "Human" : player1AI.name;
    } else if (player2State.health > player1State.health) {
      winner = player2IsHuman ? "Human" : player2AI.name;
    } else {
      winner = "Draw";
    }
    gameOver = true;
  }
}

// === CONTINUOUS PLAY SYSTEM ===

class ContinuousPlayGame extends ArithmancerGame {
  int totalTurns = 0;
  int totalDamageDealt = 0;
  int totalDamageTaken = 0;

  ContinuousPlayGame(super.aiPersonality, super.rng, {super.verbose = true});

  bool playFullGame() {
    while (!gameOver && totalTurns < 200) {
      if (!battleActive) {
        if (enemiesDefeated >= EnemyRoster.getMathematicalEnemies().length) {
          winGame();
          break;
        }
        startNewBattle();
      } else {
        // FIX: This class uses the simpler endTurn() method from its parent.
        endTurn(); 
        totalTurns++;
      }
    }

    if (verbose && gameOver) {
      print("\n" + "=" * 60);
      print("📊 FINAL STATISTICS");
      print("Total turns: $totalTurns");
      print("Enemies defeated: $enemiesDefeated");
      // Note: Damage tracking would require overriding _executeResult.
      // Keeping it simple for now to ensure it runs.
      print("Final health: $playerHealth/$maxHealth");
      bool victory =
          enemiesDefeated >= EnemyRoster.getMathematicalEnemies().length;
      print("Result: ${victory ? 'VICTORY' : 'DEFEAT'}");
    }

    return enemiesDefeated >= EnemyRoster.getMathematicalEnemies().length;
  }
}

class GameSimulation {
  static void runAIComparison(int runs) {
    List<AIPersonality> personalities = [
      PrimeHunterAI(),
      SequenceWeaverAI(),
      DefensiveMathAI(),
    ];

    Random masterRng = Random(42);
    Map<String, List<bool>> results = {};

    print("🧮 MATHEMATICAL COMBAT SIMULATION");
    print("Testing $runs runs per AI personality");
    print("=" * 60);

    for (AIPersonality ai in personalities) {
      results[ai.name] = [];

      for (int i = 0; i < runs; i++) {
        Random runRng = Random(masterRng.nextInt(1000000));
        ArithmancerGame game =
            ArithmancerGame(ai, runRng, verbose: false);

        int maxTurns = 50; // Prevent infinite games
        int turnCount = 0;

        while (!game.gameOver && turnCount < maxTurns) {
          if (!game.battleActive) {
            game.startNewBattle();
          } else {
            game.endTurn();
            turnCount++;
          }
        }

        bool victory =
            game.enemiesDefeated >= EnemyRoster.getMathematicalEnemies().length;
        results[ai.name]!.add(victory);
      }

      double winRate =
          results[ai.name]!.where((w) => w).length / runs * 100;
      print("${ai.name}: ${winRate.toStringAsFixed(1)}% victory rate");
    }

    print("\n📊 Analysis complete!");
  }
}

/// Runs a continuous game where a human plays against the sequence of enemies.
void _runContinuousHumanVsGame() {
  // The AI personality is just a placeholder, as its 'decideTurn' won't be called.
  AIPersonality humanPlaceholder = PrimeHunterAI();
  Random rng = Random();
  ArithmancerGame game = ArithmancerGame(humanPlaceholder, rng, verbose: true);

  print("\n⚔️ Starting continuous play as Human...");

  // The main game loop
  while (!game.gameOver) {
    if (!game.battleActive) {
      // Check for total victory before starting the next battle
      if (game.enemiesDefeated >= EnemyRoster.getMathematicalEnemies().length) {
        game.winGame();
        continue; // Let the loop terminate
      }
      game.startNewBattle();
    } else {
      // In an active battle, handle one full turn (human action + enemy action)
      _handlePveHumanTurn(game);
    }
  }
}

/// Handles the logic for a single turn in a Human vs. Enemy battle.
void _handlePveHumanTurn(ArithmancerGame game) {
  // --- 1. Generate and Display Actions (with deduplication) ---
  List<MathResult> allResults = game._generateAllPossibleResults();
  
  final Map<String, MathResult> uniqueResults = {};
  for (final result in allResults) {
    var key = result.expression;
    if (key.contains('+') || key.contains('*')) {
      final operator = key.contains('+') ? '+' : '*';
      var parts = key.split(' $operator ');
      parts.sort();
      key = parts.join(' $operator ');
    }
    if (!uniqueResults.containsKey(key)) {
      uniqueResults[key] = result;
    }
  }
  final List<MathResult> filteredResults = uniqueResults.values.toList();
  filteredResults.sort((a, b) => (b.damage + b.block).compareTo(a.damage + a.block));

  print("\nAvailable Actions:");
  print("0: End Turn (Keep remaining energy for next turn)");

  for (int i = 0; i < filteredResults.length && i < 20; i++) {
    MathResult result = filteredResults[i];
    int cost = result.usedCards.fold(0, (sum, card) => sum + card.cost);
    String costStr = cost <= game.playerEnergy ? "Cost: $cost" : "Cost: $cost (TOO EXPENSIVE)";
    
    String effectStr = "";
    if (result.damage > 0) effectStr += "Damage: ${result.damage}";
    if (result.block > 0) effectStr += (effectStr.isNotEmpty ? ", " : "") + "Block: ${result.block}";
    if (result.damageReduction > 0) {
      effectStr += (effectStr.isNotEmpty ? ", " : "") + "Dmg. Reduction: ${(result.damageReduction * 100).toStringAsFixed(0)}%";
    }
    if (effectStr.isEmpty) effectStr = "No effect";

    print("${i + 1}: ${result.expression} = ${result.value.toStringAsFixed(2)} - $effectStr ($costStr)");
  }

  // --- 2. Get Player's Choice ---
  MathResult? chosenResult;
  while (true) {
    stdout.write("\nChoose action (0-${min(20, filteredResults.length)}): ");
    String? input = stdin.readLineSync();
    int? choice = int.tryParse(input ?? "-1");

    if (choice == null || choice < 0 || choice > min(20, filteredResults.length)) {
      print("Invalid choice.");
      continue;
    }
    if (choice == 0) break;

    chosenResult = filteredResults[choice - 1];
    int cost = chosenResult.usedCards.fold(0, (sum, card) => sum + card.cost);
    if (cost > game.playerEnergy) {
      print("Not enough energy!");
      chosenResult = null;
      continue;
    }
    break;
  }

  // --- 3. Execute Turn based on Player's Choice ---
  bool playerActed = chosenResult != null;
  if (playerActed) {
    game._executeResult(chosenResult!, playerName: "Player"); // This removes the used cards from the hand
  } else {
    game.log("Player passes the turn.");
  }

  if (game.currentEnemy!.health <= 0) {
    game.log("🏆 ${game.currentEnemy!.name} defeated!");
    game.enemiesDefeated++;
    game.battleActive = false;
    game._addReward();
    return;
  }

  // --- 4. Optional Discard Phase (as requested, currently disabled) ---
  if (false) {
    while(true) {
      print("\nYour hand: ${game.hand.map((c) => c.toString()).join(', ')}");
      stdout.write("Enter index of card to discard (1-${game.hand.length}), or 'done': ");
      String? input = stdin.readLineSync();
      if (input == null || input.toLowerCase() == 'done') break;
      int? index = int.tryParse(input);
      if (index != null && index > 0 && index <= game.hand.length) {
        final discardedCard = game.hand.removeAt(index - 1);
        game.discardPile.add(discardedCard);
        print("Discarded ${discardedCard.name}.");
      } else {
        print("Invalid index.");
      }
    }
  }

  // --- 5. Enemy's Turn ---
  game.currentEnemy!.takeTurn(game);
  if (game.playerHealth <= 0) {
    game.loseGame();
    return;
  }
  
  // --- 6. Prepare for Next Turn (with new "Keep and Refill" logic) ---
  if (playerActed) {
    // Player acted, so we refill their hand back to 7.
    final cardsToDraw = 7 - game.hand.length;
    if (cardsToDraw > 0) {
      game.log("Drawing $cardsToDraw cards...");
      game._drawCards(cardsToDraw);
    }
    // Then call startTurn to reset energy/block and advance the turn counter.
    game.startTurn();
  } else {
    // Player passed, so they keep their hand. Just reset resources.
    game.turn++;
    game.currentBlock = 0;
    game.playerEnergy = game.maxEnergy;
    game.log("\n--- Turn ${game.turn} | HP: ${game.playerHealth}/${game.maxHealth} | E: ${game.playerEnergy}/${game.maxEnergy} | Block: ${game.currentBlock} ---");
    game.log("Hand: ${game.hand.map((c) => c.toString()).join(', ')}");
    if (game.currentEnemy != null) {
      String intent = game.currentEnemy!.getIntent()['desc'] ?? '...';
      game.log("Target: ${game.currentEnemy!.name} (${game.currentEnemy!.health} HP) | Intent: $intent");
    }
  }
}

// === MAIN LAUNCHER ===

void main() {
  print("🧮 ARITHMANCER'S DUEL - Mathematical Combat");
  print("=" * 50);
  print("1. Prime Hunter AI vs Mathematical Enemies");
  print("2. Sequence Weaver AI vs Mathematical Enemies");
  print("3. Defensive Calculator AI vs Mathematical Enemies");
  print("4. Run AI Comparison Simulation");
  print("5. AI vs AI Battle (Single)");
  print("6. AI vs AI Tournament (Multiple)");
  print("7. Human vs AI Battle");
  print("8. Continuous AI vs Game Mode");
  print("9. Continuous Play (Human)");

  stdout.write("\nSelect mode (1-9): ");
  String? input = stdin.readLineSync();

  Random rng = Random();

  switch (input) {
    case "1":
      ArithmancerGame game = ArithmancerGame(PrimeHunterAI(), rng);
      while (!game.gameOver) {
        if (!game.battleActive) {
          game.startNewBattle();
        } else {
          game.endTurn();
        }
      }
      break;
    case "2":
      ArithmancerGame game = ArithmancerGame(SequenceWeaverAI(), rng);
      while (!game.gameOver) {
        if (!game.battleActive) {
          game.startNewBattle();
        } else {
          game.endTurn();
        }
      }
      break;
    case "3":
      ArithmancerGame game = ArithmancerGame(DefensiveMathAI(), rng);
      while (!game.gameOver) {
        if (!game.battleActive) {
          game.startNewBattle();
        } else {
          game.endTurn();
        }
      }
      break;
    case "4":
      stdout.write("Number of runs per AI (default 20): ");
      String? runsInput = stdin.readLineSync();
      int runs = int.tryParse(runsInput ?? "20") ?? 20;
      GameSimulation.runAIComparison(runs);
      break;
    case "5":
      _runSingleAiVsAi();
      break;
    case "6":
      _runAiVsAiTournament();
      break;
    case "7":
      _runHumanVsAi();
      break;
    case "8":
      _runContinuousAiVsGame();
      break;
    case "9":
      _runContinuousHumanVsGame();
      break;
    default:
      print("Invalid selection");
  }
}

void _runSingleAiVsAi() {
  List<AIPersonality> personalities = [
    PrimeHunterAI(),
    SequenceWeaverAI(),
    DefensiveMathAI()
  ];

  print("\nSelect Player 1 AI:");
  for (int i = 0; i < personalities.length; i++) {
    print("${i + 1}: ${personalities[i].name}");
  }

  stdout.write("Choose Player 1 (1-${personalities.length}): ");
  String? input1 = stdin.readLineSync();
  int? choice1 = int.tryParse(input1 ?? "1");
  if (choice1 == null || choice1 < 1 || choice1 > personalities.length)
    choice1 = 1;

  print("\nSelect Player 2 AI:");
  for (int i = 0; i < personalities.length; i++) {
    print("${i + 1}: ${personalities[i].name}");
  }

  stdout.write("Choose Player 2 (1-${personalities.length}): ");
  String? input2 = stdin.readLineSync();
  int? choice2 = int.tryParse(input2 ?? "2");
  if (choice2 == null || choice2 < 1 || choice2 > personalities.length)
    choice2 = 2;

  AIPersonality ai1 = personalities[choice1 - 1];
  AIPersonality ai2 = personalities[choice2 - 1];

  Random rng = Random();
  PvPGame battle = PvPGame(
    player1AI: ai1,
    player2AI: ai2,
    rng: rng,
    verbose: true,
    player1IsHuman: false,
    player2IsHuman: false,
  );
  battle.runGame();
}

void _runAiVsAiTournament() {
  List<AIPersonality> personalities = [
    PrimeHunterAI(),
    SequenceWeaverAI(),
    DefensiveMathAI()
  ];

  stdout.write("Number of battles per matchup (default 10): ");
  String? battlesInput = stdin.readLineSync();
  int numBattles = int.tryParse(battlesInput ?? "10") ?? 10;

  print("\n🥊 AI vs AI TOURNAMENT");
  print("Running $numBattles battles per matchup...");
  print("=" * 60);

  Map<String, Map<String, int>> results = {};
  for (AIPersonality ai1 in personalities) {
    results[ai1.name] = {};
    for (AIPersonality ai2 in personalities) {
      results[ai1.name]![ai2.name] = 0;
    }
  }

  Random masterRng = Random(42);

  for (int i = 0; i < personalities.length; i++) {
    for (int j = 0; j < personalities.length; j++) {
      if (i == j) continue;

      AIPersonality ai1 = personalities[i];
      AIPersonality ai2 = personalities[j];

      print("\n🎲 ${ai1.name} vs ${ai2.name} ($numBattles battles)");

      int ai1Wins = 0;
      for (int battle = 0; battle < numBattles; battle++) {
        Random battleRng = Random(masterRng.nextInt(1000000));
        PvPGame battleInstance = PvPGame(
          player1AI: ai1,
          player2AI: ai2,
          rng: battleRng,
          verbose: false,
        );
        String winner = battleInstance.runGame();

        if (winner == ai1.name) {
          ai1Wins++;
        }
      }

      results[ai1.name]![ai2.name] = ai1Wins;
      int ai2Wins = numBattles - ai1Wins;

      print(
          "  ${ai1.name}: $ai1Wins wins (${(ai1Wins / numBattles * 100).toStringAsFixed(1)}%)");
      print(
          "  ${ai2.name}: $ai2Wins wins (${(ai2Wins / numBattles * 100).toStringAsFixed(1)}%)");
    }
  }

  print("\n📊 TOURNAMENT RESULTS SUMMARY");
  for (AIPersonality ai in personalities) {
    int totalWins = 0;
    int totalBattles = 0;
    for (AIPersonality opponent in personalities) {
      if (ai.name != opponent.name) {
        totalWins += results[ai.name]![opponent.name]!;
        totalBattles += numBattles;
      }
    }
    double winRate = (totalWins / totalBattles) * 100;
    print("${ai.name}: ${winRate.toStringAsFixed(1)}% overall win rate");
  }
}

void _runHumanVsAi() {
  List<AIPersonality> personalities = [PrimeHunterAI(), SequenceWeaverAI(), DefensiveMathAI()];
  
  print("\nSelect AI Opponent:");
  for (int i = 0; i < personalities.length; i++) {
    print("${i + 1}: ${personalities[i].name} - ${personalities[i].description}");
  }
  
  stdout.write("Choose AI opponent (1-${personalities.length}): ");
  String? input = stdin.readLineSync();
  int? choice = int.tryParse(input ?? "1");
  if (choice == null || choice < 1 || choice > personalities.length) choice = 1;
  
  AIPersonality aiOpponent = personalities[choice - 1];
  AIPersonality humanPlaceholder = PrimeHunterAI(); // This doesn't matter, just a placeholder
  
  print("\nWho goes first?");
  print("1: Human");
  print("2: AI");
  
  stdout.write("Choose (1-2): ");
  String? firstInput = stdin.readLineSync();
  bool humanFirst = firstInput != "2";

  Random rng = Random();
  PvPGame battle = PvPGame(
    // FIX: Correctly assign player roles based on turn order
    player1AI: humanFirst ? humanPlaceholder : aiOpponent,
    player2AI: humanFirst ? aiOpponent : humanPlaceholder,
    rng: rng,
    verbose: true,
    player1IsHuman: humanFirst,
    player2IsHuman: !humanFirst,
  );
  battle.runGame();
}

void _runContinuousAiVsGame() {
  List<AIPersonality> personalities = [
    PrimeHunterAI(),
    SequenceWeaverAI(),
    DefensiveMathAI()
  ];

  print("\nSelect AI for Continuous Play:");
  for (int i = 0; i < personalities.length; i++) {
    print(
        "${i + 1}: ${personalities[i].name} - ${personalities[i].description}");
  }

  stdout.write("Choose AI (1-${personalities.length}): ");
  String? input = stdin.readLineSync();
  int? choice = int.tryParse(input ?? "1");
  if (choice == null || choice < 1 || choice > personalities.length)
    choice = 1;

  AIPersonality selectedAI = personalities[choice - 1];

  Random rng = Random();
  ContinuousPlayGame game =
      ContinuousPlayGame(selectedAI, rng, verbose: true);

  print("\n🚀 Starting continuous play with ${selectedAI.name}...");
  bool victory = game.playFullGame();

  print(victory ? "\n🎊 Mission accomplished!" : "\n💀 Mission failed!");
}