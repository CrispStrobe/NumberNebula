import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../../../shared/utils/arithmancer.dart';

enum GameMode {
  vsPrograms,  // Human vs AI programs (enemies)
  vsPlayers,   // Human vs AI players
  ladder,      // Mixed: 3 programs, 1 player, repeat
}

class ArithmancerDuelGame extends StatefulWidget {
  final int grade;
  final int level;
  final GameMode gameMode;

  const ArithmancerDuelGame({
    super.key,
    required this.grade,
    required this.level,
    this.gameMode = GameMode.vsPrograms,
  });

  @override
  State<ArithmancerDuelGame> createState() => _ArithmancerDuelGameState();
}

class _ArithmancerDuelGameState extends State<ArithmancerDuelGame>
    with TickerProviderStateMixin {
  
  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _combatController;
  late AnimationController _particleController;
  late AnimationController _shakeController;
  late AnimationController _cardGlowController;
  late AnimationController _energyTransferController;
  late AnimationController _damageController;
  late AnimationController _drawController;
  late AnimationController _discardController;
  late AnimationController _shieldController;
  late AnimationController _bonusController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _cardGlowAnimation;
  late Animation<double> _energyTransferAnimation;
  late Animation<double> _damageAnimation;
  late Animation<double> _drawAnimation;
  late Animation<double> _discardAnimation;
  late Animation<double> _shieldAnimation;
  late Animation<double> _bonusAnimation;

  // Game State
  late ArithmancerGame _game;
  PvPGame? _pvpGame;
  List<MathCard> _handCards = [];
  List<MathCard> _battlefieldCards = [];
  List<MathCard> _deckCards = [];
  List<MathCard> _discardCards = [];
  
  // Opponent State (for PvP)
  List<MathCard> _opponentHand = [];
  List<MathCard> _opponentBattlefield = [];
  bool _isOpponentTurn = false;
  
  // Current Opponent
  MathematicalEnemy? _currentEnemy;
  AIPersonality? _currentAIOpponent;
  
  // UI State
  bool _isCalculating = false;
  String _lastExpression = "";
  int _lastDamage = 0;
  List<String> _lastProperties = [];
  bool _showingResult = false;
  bool _isDraggingCard = false;
  
  // Game Mode State
  int _ladderProgress = 0;
  int _totalLadderSteps = 12; // (3 programs + 1 player) * 3
  int _enemiesDefeated = 0;
  
  // Visual Effects
  List<CombatParticle> _particles = [];
  List<EnergyOrb> _energyOrbs = [];
  List<ShieldEffect> _shieldEffects = [];
  List<BonusEffect> _bonusEffects = [];
  String _statusMessage = "";
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeGame();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );

    _combatController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..addListener(_updateEffects)..repeat();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut)
    );

    _cardGlowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _cardGlowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _cardGlowController, curve: Curves.easeInOut)
    );

    _energyTransferController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _energyTransferAnimation = CurvedAnimation(
      parent: _energyTransferController, 
      curve: Curves.easeInOut
    );

    _damageController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _damageAnimation = CurvedAnimation(
      parent: _damageController, 
      curve: Curves.elasticOut
    );

    _drawController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _drawAnimation = CurvedAnimation(
      parent: _drawController, 
      curve: Curves.easeOut
    );

    _discardController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _discardAnimation = CurvedAnimation(
      parent: _discardController, 
      curve: Curves.easeIn
    );

    _shieldController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    
    _shieldAnimation = CurvedAnimation(
      parent: _shieldController, 
      curve: Curves.easeInOut
    );

    _bonusController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _bonusAnimation = CurvedAnimation(
      parent: _bonusController, 
      curve: Curves.elasticOut
    );
  }

  void _initializeGame() {
    final random = math.Random();
    
    switch (widget.gameMode) {
      case GameMode.vsPrograms:
        _initializeProgramMode(random);
        break;
      case GameMode.vsPlayers:
        _initializePlayerMode(random);
        break;
      case GameMode.ladder:
        _initializeLadderMode(random);
        break;
    }
  }

  void _initializeProgramMode(math.Random random) {
    final aiPersonality = _selectAIPersonality(widget.level % 3);
    _game = ArithmancerGame(aiPersonality, random, verbose: false);
    _game.startNewBattle();
    _syncGameState();
    _createShieldEffects();
    }


  void _initializePlayerMode(math.Random random) {
    final player1AI = PrimeHunterAI(); // Human placeholder
    final player2AI = _selectAIPersonality(widget.level % 3);
    _currentAIOpponent = player2AI;
    
    _pvpGame = PvPGame(
      player1AI: player1AI,
      player2AI: player2AI,
      rng: random,
      verbose: false,
      player1IsHuman: true,
      player2IsHuman: false,
    );
    _syncPvPState();
  }

  void _initializeLadderMode(math.Random random) {
    _ladderProgress = 0;
    if (_ladderProgress % 4 < 3) {
      // Program mode for first 3 steps of each cycle
      _initializeProgramMode(random);
    } else {
      // Player mode for 4th step
      _initializePlayerMode(random);
    }
  }

  AIPersonality _selectAIPersonality(int index) {
    switch (index % 3) {
        case 0: return PrimeHunterAI();
        case 1: return SequenceWeaverAI();
        default: return DefensiveMathAI();
    }
    }

  void _syncGameState() {
    if (_game.hand.length < 7) {
      _drawCardsFromDeck(7 - _game.hand.length);
    }
    
    setState(() {
      _handCards = List.from(_game.hand);
      _deckCards = List.from(_game.drawPile);
      _discardCards = List.from(_game.discardPile);
      _currentEnemy = _game.currentEnemy;
      _battlefieldCards.clear();
      _showingResult = false;

      // Remove Fibonacci Seed cards to simplify the game
      _handCards.removeWhere((card) => card.name.contains("Fibonacci"));
      _deckCards.removeWhere((card) => card.name.contains("Fibonacci"));
      _game.hand.removeWhere((card) => card.name.contains("Fibonacci"));
      _game.drawPile.removeWhere((card) => card.name.contains("Fibonacci"));

      // Ensure we have exactly 7 cards in hand (no more, no less)
      while (_handCards.length < 7 && _deckCards.isNotEmpty) {
        final card = _deckCards.removeLast();
        _handCards.add(card);
        _game.hand.add(card);
        _game.drawPile.remove(card);
      }
      // If we somehow have more than 7, trim to 7
      if (_handCards.length > 7) {
        final excess = _handCards.sublist(7);
        _handCards = _handCards.sublist(0, 7);
        _discardCards.addAll(excess);
        _game.discardPile.addAll(excess);
        for (final card in excess) {
          _game.hand.remove(card);
        }
      }
    });
  }

  void _syncPvPState() {
    if (_pvpGame == null) return;
    
    final playerState = _pvpGame!.player1State;
    final opponentState = _pvpGame!.player2State;
    
    setState(() {
      _handCards = List.from(playerState.gameInstance.hand);
      _deckCards = List.from(playerState.gameInstance.drawPile);
      _discardCards = List.from(playerState.gameInstance.discardPile);
      
      // Remove Fibonacci Seed cards to simplify the game
      _handCards.removeWhere((card) => card.name.contains("Fibonacci"));
      _deckCards.removeWhere((card) => card.name.contains("Fibonacci"));
      playerState.gameInstance.hand.removeWhere((card) => card.name.contains("Fibonacci"));
      playerState.gameInstance.drawPile.removeWhere((card) => card.name.contains("Fibonacci"));
      
      // Opponent hand is hidden - show card backs
      _opponentHand = List.generate(
        opponentState.gameInstance.hand.length, 
        (index) => MathCard(name: "Hidden", type: "Hidden")
      );
      
      _battlefieldCards.clear();
      _opponentBattlefield.clear();
      _showingResult = false;
      _isOpponentTurn = false;

      // Ensure exactly 7 cards in hand
      while (_handCards.length < 7 && _deckCards.isNotEmpty) {
        final card = _deckCards.removeLast();
        _handCards.add(card);
        playerState.gameInstance.hand.add(card);
        playerState.gameInstance.drawPile.remove(card);
      }
      if (_handCards.length > 7) {
        final excess = _handCards.sublist(7);
        _handCards = _handCards.sublist(0, 7);
        _discardCards.addAll(excess);
        playerState.gameInstance.discardPile.addAll(excess);
        for (final card in excess) {
          playerState.gameInstance.hand.remove(card);
        }
      }
    });
  }

  // Split parentheses cards into separate ( and ) cards
  List<MathCard> _splitParenthesesCards(List<MathCard> cards) {
    List<MathCard> result = [];
    
    for (final card in cards) {
      if (card.type == CardType.parentheses && card.name == "Parentheses") {
        // Split into two separate cards
        result.add(MathCard(
          name: "Open Parenthesis",
          type: CardType.parentheses,
          cost: card.cost,
        ));
        result.add(MathCard(
          name: "Close Parenthesis", 
          type: CardType.parentheses,
          cost: card.cost,
        ));
      } else {
        result.add(card);
      }
    }
    
    return result;
  }

  void _createShieldEffects() {
    _shieldEffects.clear();
    if (_currentEnemy?.mathematicalShields.isNotEmpty ?? false) {
      for (final shield in _currentEnemy!.mathematicalShields.keys) {
        _shieldEffects.add(ShieldEffect(type: shield));
      }
    }
  }

  void _drawCardsFromDeck(int count) {
    for (int i = 0; i < count; i++) {
      if (_deckCards.isNotEmpty) {
        final card = _deckCards.removeLast();
        _handCards.add(card);
        _game.hand.add(card);
        _game.drawPile.remove(card);
        
        // Animate card draw
        _drawController.forward(from: 0.0).then((_) {
          _drawController.reset();
        });
      } else if (_discardCards.isNotEmpty) {
        // Shuffle discard pile back into deck
        _deckCards.addAll(_discardCards);
        _discardCards.clear();
        _deckCards.shuffle();
        _game.drawPile.addAll(_deckCards);
        _game.discardPile.clear();
        
        // Draw the card
        if (_deckCards.isNotEmpty) {
          final card = _deckCards.removeLast();
          _handCards.add(card);
          _game.hand.add(card);
          _game.drawPile.remove(card);
        }
      }
    }
  }

  void _discardCardsToDiscard(List<MathCard> cards) {
    for (final card in cards) {
      _discardCards.add(card);
      _game.discardPile.add(card);
      
      // Animate card discard
      _discardController.forward(from: 0.0).then((_) {
        _discardController.reset();
      });
    }
  }

  void _executeBattlefield() async {
    if (_battlefieldCards.isEmpty || _isCalculating) return;
    
    // Check energy cost first
    final cost = _battlefieldCards.fold(0, (sum, card) => sum + card.cost);
    
    int currentEnergy;
    if (_pvpGame != null) {
      currentEnergy = _pvpGame!.player1State.energy;
    } else {
      currentEnergy = _game.playerEnergy;
    }
    
    if (cost > currentEnergy) {
      _showStatus(S.of(context)!.arithmancerNotEnoughEnergy);
      return;
    }

    setState(() {
      _isCalculating = true;
      _showingResult = false;
    });

    // Energy transfer animation - create orbs from energy counter to specific cards
    _createEnergyOrbs(cost, _battlefieldCards);
    _energyTransferController.forward(from: 0.0);

    await Future.delayed(const Duration(milliseconds: 400));

    // Calculate the mathematical result using the exact same evaluator as the CLI
    final evaluator = ExpressionEvaluator();
    final allResults = evaluator.generateAllResults(_battlefieldCards);
    
    // Find the result that uses exactly our battlefield cards
    MathResult? result;
    for (final r in allResults) {
      if (r.usedCards.length == _battlefieldCards.length) {
        final usedIds = r.usedCards.map((c) => c.id).toSet();
        final battlefieldIds = _battlefieldCards.map((c) => c.id).toSet();
        if (usedIds.containsAll(battlefieldIds) && battlefieldIds.containsAll(usedIds)) {
          result = r;
          break;
        }
      }
    }
    
    if (result == null) {
      _showStatus(S.of(context)!.arithmancerInvalidExpression);
      setState(() {
        _isCalculating = false;
      });
      _energyTransferController.reverse();
      return;
    }

    // Apply the result - using non-null result
    final nonNullResult = result;
    
    // Debug print the mathematical properties for troubleshooting
    // Enhanced debug logging for troubleshooting
    print("🔢 === DAMAGE CALCULATION DEBUG ===");
    print("🔢 Expression: ${nonNullResult.expression} = ${nonNullResult.value}");
    print("🔢 Raw damage: ${nonNullResult.damage}");
    print("🔢 Mathematical properties:");
    print("🔢   - isPrime: ${nonNullResult.isPrime}");
    print("🔢   - isPerfectSquare: ${nonNullResult.isPerfectSquare}");
    print("🔢   - isFibonacci: ${nonNullResult.isFibonacci}");
    print("🔢   - isPowerOfTwo: ${nonNullResult.isPowerOfTwo}");
    print("🔢   - isEven: ${nonNullResult.isEven}");
    print("🔢   - isOdd: ${nonNullResult.isOdd}");
    print("🔢 Block gained: ${nonNullResult.block}");

    if (_currentEnemy != null) {
    print("🔢 Enemy: ${_currentEnemy!.name}");
    print("🔢 Enemy health: ${_currentEnemy!.health}/${_currentEnemy!.maxHealth}");
    print("🔢 Enemy shields: ${_currentEnemy!.mathematicalShields}");
    
    // Check each shield type
    _currentEnemy!.mathematicalShields.forEach((shieldType, threshold) {
        print("🔢 Shield check - $shieldType: threshold=$threshold");
        switch (shieldType) {
        case 'prime_shield':
            print("🔢   - Value ${nonNullResult.value} is prime: ${nonNullResult.isPrime}");
            print("🔢   - Threshold check: ${nonNullResult.value} >= $threshold = ${nonNullResult.value >= threshold}");
            break;
        case 'square_immune':
            print("🔢   - Value ${nonNullResult.value} is perfect square: ${nonNullResult.isPerfectSquare}");
            break;
        case 'fibonacci_only':
            print("🔢   - Value ${nonNullResult.value} is fibonacci: ${nonNullResult.isFibonacci}");
            break;
        case 'power_of_two_only':
            print("🔢   - Value ${nonNullResult.value} is power of two: ${nonNullResult.isPowerOfTwo}");
            break;
        }
    });
    }

    if (_pvpGame != null) {
      _pvpGame!.player1State.energy -= cost;
    } else {
      _game.playerEnergy -= cost;
    }
    
    // Remove used cards from hand and discard them
    for (final card in nonNullResult.usedCards) {
      _handCards.removeWhere((c) => c.id == card.id);
      if (_pvpGame != null) {
        _pvpGame!.player1State.gameInstance.hand.removeWhere((c) => c.id == card.id);
      } else {
        _game.hand.removeWhere((c) => c.id == card.id);
      }
    }
    _discardCardsToDiscard(List.from(nonNullResult.usedCards));
    
    // Apply damage to opponent
    if (nonNullResult.damage > 0) {
      if (_pvpGame != null) {
        // PvP damage
        final actualDamage = math.max<int>(0, nonNullResult.damage - _pvpGame!.player2State.block);
        _pvpGame!.player2State.health -= actualDamage;
        _lastDamage = actualDamage;
        _pvpGame!.player2State.block = math.max<int>(0, _pvpGame!.player2State.block - nonNullResult.damage);
      } else {
        // Program mode damage
        final damageDealt = _currentEnemy!.takeDamage(nonNullResult, _game);
        _lastDamage = damageDealt;
      }
      
      // Add combat effects
      _addCombatParticles();
      _damageController.forward(from: 0.0);
      HapticFeedback.heavyImpact();
    } else {
      _lastDamage = 0;
    }
    
    // Apply block if negative result
    if (nonNullResult.block > 0) {
      if (_pvpGame != null) {
        _pvpGame!.player1State.block += nonNullResult.block;
      } else {
        _game.currentBlock += nonNullResult.block;
      }
    }

    // Create visual bonus effects for mathematical properties
    _createBonusEffects(nonNullResult);
    
    setState(() {
      _lastExpression = nonNullResult.expression;
      _lastProperties = _getPropertyStrings(nonNullResult);
      _showingResult = true;
      _isCalculating = false;
      _battlefieldCards.clear();
    });

    // Draw cards back to 7
    _drawCardsFromDeck(7 - _handCards.length);

    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (_pvpGame != null) {
      _handlePvPResult();
    } else {
      _handleProgramResult();
    }
  }

  void _createBonusEffects(MathResult result) {
    _bonusEffects.clear();
    if (result.isPrime) _bonusEffects.add(BonusEffect(type: "PRIME", value: "x3", color: Colors.cyan));
    if (result.isPerfectSquare) _bonusEffects.add(BonusEffect(type: "SQUARE", value: "x2", color: Colors.purple));
    if (result.isFibonacci) _bonusEffects.add(BonusEffect(type: "FIBONACCI", value: "x1.7", color: Colors.orange));
    if (result.isPowerOfTwo) _bonusEffects.add(BonusEffect(type: "BINARY", value: "x1.6", color: Colors.lightBlue));
    
    if (_bonusEffects.isNotEmpty) {
      _bonusController.forward(from: 0.0);
    }
  }

  void _handleProgramResult() {
    if (_currentEnemy!.health <= 0) {
      _handleEnemyDefeated();
    } else {
      _handleEnemyTurn();
    }
  }

  void _handlePvPResult() {
    if (_pvpGame!.player2State.health <= 0) {
      _handlePvPVictory();
    } else {
      _handleOpponentTurn();
    }
  }

  void _handleOpponentTurn() async {
    setState(() {
      _isOpponentTurn = true;
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    // AI opponent plays
    final opponentResults = _currentAIOpponent!.decideTurn(_pvpGame!.player2State.gameInstance);
    
    if (opponentResults.isNotEmpty) {
      final result = opponentResults.first;
      
      // Apply opponent's result
      final damage = result.damage;
      if (damage > 0) {
        final actualDamage = math.max<int>(0, damage - _pvpGame!.player1State.block);
        _pvpGame!.player1State.health -= actualDamage;
        _pvpGame!.player1State.block = math.max<int>(0, _pvpGame!.player1State.block - damage);
        
        _addEnemyAttackParticles();
        _shakeController.forward(from: 0.0);
        _showStatus(S.of(context)!.arithmancerEnemyAttack(damage));
      }
    }

    await Future.delayed(const Duration(milliseconds: 1500));

    if (_pvpGame!.player1State.health <= 0) {
      _handleDefeat();
    } else {
      setState(() {
        _isOpponentTurn = false;
      });
      _syncPvPState();
    }
  }

  void _handlePvPVictory() {
    final baseScore = 300 * widget.grade;
    context.read<GameProvider>().addScore(baseScore);
    
    if (widget.gameMode == GameMode.ladder) {
      _ladderProgress++;
      if (_ladderProgress >= _totalLadderSteps) {
        // Ladder complete
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildLadderCompleteDialog(baseScore),
        );
      } else {
        // Next ladder step
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildLadderStepDialog(),
        );
      }
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildVictoryDialog(baseScore),
      );
    }
  }

  void _createEnergyOrbs(int cost, List<MathCard> targetCards) {
    _energyOrbs.clear();
    for (int i = 0; i < cost; i++) {
      // Find the target card for this energy orb
      final targetCardIndex = i % targetCards.length;
      _energyOrbs.add(EnergyOrb(
        startTime: i * 0.1,
        targetCardIndex: targetCardIndex,
      ));
    }
  }

  void _addCombatParticles() {
    final random = math.Random();
    for (int i = 0; i < 30; i++) {
      _particles.add(CombatParticle.damage(random));
    }
    for (int i = 0; i < 15; i++) {
      _particles.add(CombatParticle.explosion(random));
    }
  }

  List<String> _getPropertyStrings(MathResult result) {
    List<String> properties = [];
    final l10n = S.of(context)!;
    
    if (result.isPrime) properties.add(l10n.arithmancerPropertyPrime);
    if (result.isPerfectSquare) properties.add(l10n.arithmancerPropertySquare);
    if (result.isFibonacci) properties.add(l10n.arithmancerPropertyFibonacci);
    if (result.isEven) properties.add(l10n.arithmancerPropertyEven);
    if (result.isOdd) properties.add(l10n.arithmancerPropertyOdd);
    if (result.isPowerOfTwo) properties.add(l10n.arithmancerPropertyPowerOfTwo);
    
    return properties;
  }

  void _handleEnemyDefeated() {
    _enemiesDefeated++; // Increment our counter
    _game.enemiesDefeated = _enemiesDefeated; // Sync with game instance
    
    final baseScore = 200 * widget.grade;
    final bonusScore = (_game.playerHealth / _game.maxHealth * 100).round();
    context.read<GameProvider>().addScore(baseScore + bonusScore);
    
    if (widget.gameMode == GameMode.ladder) {
        _ladderProgress++;
        if (_ladderProgress >= _totalLadderSteps) {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildLadderCompleteDialog(baseScore + bonusScore),
        );
        } else {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildLadderStepDialog(),
        );
        }
    } else {
        showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildVictoryDialog(baseScore + bonusScore),
        );
    }
    }

  void _advanceToNextEnemy() {
    final random = math.Random();
    
    if (widget.gameMode == GameMode.ladder) {
        // Ladder mode: cycle through pattern
        if (_ladderProgress % 4 < 3) {
        // Program mode - preserve enemy progress
        final aiPersonality = _selectAIPersonality(_enemiesDefeated);
        _game = ArithmancerGame(aiPersonality, random, verbose: false);
        _game.enemiesDefeated = _enemiesDefeated; // Preserve progress
        _game.startNewBattle();
        _syncGameState();
        _createShieldEffects();
        } else {
        // Player mode for 4th step
        _initializePlayerMode(random);
        }
    } else if (widget.gameMode == GameMode.vsPrograms) {
        // Continue with existing game instance to preserve progress
        _game.startNewBattle();
        _syncGameState();
        _createShieldEffects();
    } else {
        // vs Players mode - new AI player
        _initializePlayerMode(random);
    }
    }

  void _handleEnemyTurn() {
    _shakeController.forward(from: 0.0);
    
    final intent = _currentEnemy!.getIntent();
    final damage = intent['attack'] ?? 0;
    
    if (damage > 0) {
      final actualDamage = math.max<int>(0, damage - _game.currentBlock);
      _game.playerHealth -= actualDamage;
      _showStatus(S.of(context)!.arithmancerEnemyAttack(damage));
      
      // Add enemy attack effects
      _addEnemyAttackParticles();
      HapticFeedback.vibrate();
      
      if (_game.playerHealth <= 0) {
        _handleDefeat();
        return;
      }
    }

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _game.startTurn();
        _syncGameState();
      }
    });
  }

  void _addEnemyAttackParticles() {
    final random = math.Random();
    for (int i = 0; i < 25; i++) {
      _particles.add(CombatParticle.enemyAttack(random));
    }
  }

  void _handleDefeat() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildDefeatDialog(),
    );
  }

  void _updateEffects() {
    setState(() {
      _particles.removeWhere((p) => p.update());
      _energyOrbs.removeWhere((orb) => orb.update(_energyTransferAnimation.value));
      _shieldEffects.forEach((shield) => shield.update(_shieldAnimation.value));
      _bonusEffects.forEach((bonus) => bonus.update(_bonusAnimation.value));
    });
  }

  void _showStatus(String message) {
    setState(() {
      _statusMessage = message;
    });
    
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _statusMessage = "";
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Row(
                      children: [
                        // Left side - Deck pile
                        SizedBox(
                          width: 100,
                          child: _buildDeckArea(),
                        ),
                        // Center - Main game area
                        Expanded(
                          child: Column(
                            children: [
                              // Opponent area - increased height to prevent overflow  
                                SizedBox(
                                height: 100, // Increased from 80 to 100
                                child: _buildOpponentArea(),
                                ),
                                // Battlefield - increased height to prevent overflow
                                SizedBox(
                                height: 160, // Increased from 140 to 160  
                                child: _buildBattlefield(),
                                ),
                                // Player stats - increased height to prevent overflow
                                SizedBox(
                                height: 100, // Increased
                                child: _buildPlayerArea(),
                                ),
                              // Hand area - takes remaining space
                              Expanded(
                                child: _buildHandArea(),
                              ),
                            ],
                          ),
                        ),
                        // Right side - Discard pile
                        SizedBox(
                          width: 100,
                          child: _buildDiscardArea(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Visual effects overlay
              ..._particles.map((p) => p.buildWidget()),
              ..._energyOrbs.map((orb) => orb.buildWidget()),
              ..._shieldEffects.map((shield) => shield.buildWidget()),
              ..._bonusEffects.map((bonus) => bonus.buildWidget()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [SpaceTheme.deepSpace.withOpacity(0.9), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 16),
          Text(
            _getGameModeTitle(),
            style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
          ),
          const Spacer(),
          if (widget.gameMode == GameMode.ladder)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SpaceTheme.starYellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: SpaceTheme.starYellow),
              ),
              child: Text(
                "${_ladderProgress + 1}/$_totalLadderSteps",
                style: SpaceTheme.titleStyle.copyWith(fontSize: 14, color: SpaceTheme.starYellow),
              ),
            ),
        ],
      ),
    );
  }

  String _getGameModeTitle() {
    switch (widget.gameMode) {
      case GameMode.vsPrograms:
        return "NEURAL BREACH";
      case GameMode.vsPlayers:
        return "AI COMBAT DUEL";
      case GameMode.ladder:
        return "NEURAL LADDER";
    }
  }

  Widget _buildDeckArea() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTronDeckPile(_deckCards.length),
          const SizedBox(height: 8),
          Text(
            "DECK",
            style: SpaceTheme.titleStyle.copyWith(
              fontSize: 10,
              color: SpaceTheme.alienGreen,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscardArea() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DragTarget<MathCard>(
            onWillAccept: (card) => card != null && !_isOpponentTurn,
            onAccept: (card) {
                HapticFeedback.lightImpact();
                setState(() {
                // Handle parentheses halves specially
                if (card.name == "Open Parenthesis" || card.name == "Close Parenthesis") {
                    // Find the original parentheses card and mark it as fully used
                    for (var handCard in _handCards) {
                    if (handCard.type == CardType.parentheses && handCard.name == "Parentheses") {
                        // Remove the entire parentheses card from hand and discard it
                        _handCards.remove(handCard);
                        _discardCards.add(handCard);
                        _game.hand.remove(handCard);
                        _game.discardPile.add(handCard);
                        break;
                    }
                    }
                } else {
                    // Regular card handling
                    _handCards.remove(card);
                    _discardCards.add(card);
                    _game.hand.remove(card);
                    _game.discardPile.add(card);
                }
                });
            },
            builder: (context, candidateData, rejectedData) {
                return _buildTronDiscardPile(_discardCards.length, isTarget: candidateData.isNotEmpty);
            },
            ),
          const SizedBox(height: 8),
          Text(
            "USED",
            style: SpaceTheme.titleStyle.copyWith(
              fontSize: 10,
              color: SpaceTheme.nebulaPurple,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentArea() {
    if (_pvpGame != null) {
      return _buildAIPlayerArea();
    } else {
      return _buildEnemyArea();
    }
  }

  Widget _buildAIPlayerArea() {
    if (_pvpGame == null || _currentAIOpponent == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(8),
      child: AnimatedBuilder(
        animation: _damageAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              math.sin(_damageAnimation.value * math.pi * 4) * 2,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SpaceTheme.rocketRed.withOpacity(0.1),
                    SpaceTheme.deepSpace.withOpacity(0.9),
                    SpaceTheme.rocketRed.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SpaceTheme.rocketRed, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.rocketRed.withOpacity(0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // AI Avatar
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [SpaceTheme.rocketRed, SpaceTheme.deepSpace],
                            ),
                            border: Border.all(color: SpaceTheme.rocketRed, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: SpaceTheme.rocketRed.withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.psychology,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentAIOpponent!.name.toUpperCase(),
                          style: SpaceTheme.headlineStyle.copyWith(
                            fontSize: 16,
                            color: SpaceTheme.rocketRed,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildCompactHealthBar(_pvpGame!.player2State.health, 120, SpaceTheme.rocketRed),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      _buildCompactStat("E", "${_pvpGame!.player2State.energy}", SpaceTheme.starYellow),
                      const SizedBox(height: 4),
                      _buildCompactStat("S", "${_pvpGame!.player2State.block}", SpaceTheme.alienGreen),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnemyArea() {
    if (_currentEnemy == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(2), // Further reduced from 4
      child: AnimatedBuilder(
        animation: _damageAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              math.sin(_damageAnimation.value * math.pi * 4) * 2,
              0,
            ),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(6), // Further reduced from 8
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        SpaceTheme.rocketRed.withOpacity(0.1),
                        SpaceTheme.deepSpace.withOpacity(0.9),
                        SpaceTheme.rocketRed.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SpaceTheme.rocketRed, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: SpaceTheme.rocketRed.withOpacity(0.6),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Enemy Avatar
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 35, // Further reduced from 40
                              height: 35, // Further reduced from 40
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [SpaceTheme.rocketRed, SpaceTheme.deepSpace],
                                ),
                                border: Border.all(color: SpaceTheme.rocketRed, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: SpaceTheme.rocketRed.withOpacity(0.8),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.smart_toy,
                                color: Colors.white,
                                size: 18, // Further reduced from 20
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8), // Further reduced from 12
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentEnemy!.name.toUpperCase(),
                              style: SpaceTheme.headlineStyle.copyWith(
                                fontSize: 12, // Further reduced from 14
                                color: SpaceTheme.rocketRed,
                                letterSpacing: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1), // Further reduced from 2
                            _buildCompactHealthBar(_currentEnemy!.health, _currentEnemy!.maxHealth, SpaceTheme.rocketRed),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Shield visual effects overlaid on top
                ..._shieldEffects.map((shield) => shield.buildWidget()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2), // Further reduced from 4
      child: Container(
        padding: const EdgeInsets.all(6), // Further reduced from 8
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              SpaceTheme.alienGreen.withOpacity(0.1),
              SpaceTheme.deepSpace.withOpacity(0.9),
              SpaceTheme.alienGreen.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SpaceTheme.alienGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: SpaceTheme.alienGreen.withOpacity(0.6),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 25, // Further reduced from 30
              height: 25, // Further reduced from 30
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [SpaceTheme.alienGreen, SpaceTheme.deepSpace],
                ),
                border: Border.all(color: SpaceTheme.alienGreen, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.alienGreen.withOpacity(0.8),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 12, // Further reduced from 15
              ),
            ),
            const SizedBox(width: 6), // Further reduced from 8
            Expanded(
              child: _buildCompactHealthBar(
                _pvpGame?.player1State.health ?? _game.playerHealth,
                _pvpGame?.player1State.health ?? _game.maxHealth,
                SpaceTheme.alienGreen,
              ),
            ),
            const SizedBox(width: 6), // Further reduced from 8
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCompactStat(
                  "E", 
                  "${_pvpGame?.player1State.energy ?? _game.playerEnergy}", 
                  SpaceTheme.starYellow
                ),
                const SizedBox(height: 1), // Further reduced from 2
                _buildCompactStat(
                  "S", 
                  "${_pvpGame?.player1State.block ?? _game.currentBlock}", 
                  SpaceTheme.alienGreen
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattlefield() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // Battle zone with TRON styling
          Expanded(
            child: DragTarget<MathCard>(
              onWillAccept: (card) {
                setState(() => _isDraggingCard = true);
                return card != null && !_isOpponentTurn;
              },
              onLeave: (card) {
                setState(() => _isDraggingCard = false);
              },
              onAccept: (card) {
                HapticFeedback.lightImpact();
                setState(() {
                  _battlefieldCards.add(card);
                  
                  // Special handling for parentheses halves - DON'T remove the original card
                  if (card.name == "Open Parenthesis" || card.name == "Close Parenthesis") {
                    // Find the original parentheses card and mark which half was used
                    for (var handCard in _handCards) {
                      if (handCard.type == CardType.parentheses && handCard.name == "Parentheses") {
                        if (card.name == "Open Parenthesis") {
                          handCard.properties['open_used'] = true;
                        } else {
                          handCard.properties['close_used'] = true;
                        }
                        break;
                      }
                    }
                  } else {
                    // Regular cards get removed from hand
                    _handCards.remove(card);
                  }
                  
                  _isDraggingCard = false;
                });
              },
              builder: (context, candidateData, rejectedData) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isDraggingCard 
                          ? [
                              SpaceTheme.starYellow.withOpacity(0.3),
                              SpaceTheme.alienGreen.withOpacity(0.2),
                              SpaceTheme.starYellow.withOpacity(0.3),
                            ]
                          : [
                              SpaceTheme.deepSpace.withOpacity(0.4),
                              SpaceTheme.nebulaPurple.withOpacity(0.2),
                              SpaceTheme.deepSpace.withOpacity(0.4),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isDraggingCard ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple,
                      width: 2,
                    ),
                    boxShadow: _isDraggingCard ? [
                      BoxShadow(
                        color: SpaceTheme.starYellow.withOpacity(0.7),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ] : [],
                  ),
                  child: Stack(
                    children: [
                      // Battlefield grid pattern
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: CustomPaint(
                            painter: TronGridPainter(),
                            size: const Size(400, 200), // Fixed size
                          ),
                        ),
                      ),
                      // Battlefield content
                      Positioned.fill(
                        child: _battlefieldCards.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isOpponentTurn ? Icons.hourglass_empty : Icons.memory,
                                      color: Colors.white30,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _isOpponentTurn 
                                          ? "OPPONENT PROCESSING..."
                                          : "DEPLOY COMBAT SEQUENCE",
                                      style: SpaceTheme.bodyStyle.copyWith(
                                        color: Colors.white30,
                                        fontSize: 12,
                                        letterSpacing: 1.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _battlefieldCards.asMap().entries.map((entry) {
                                          return GestureDetector(
                                                onTap: () {
                                                    if (!_isOpponentTurn) {
                                                    HapticFeedback.lightImpact();
                                                    setState(() {
                                                        final card = _battlefieldCards.removeAt(entry.key);
                                                        
                                                        // Special handling for parentheses halves
                                                        if (card.name == "Open Parenthesis" || card.name == "Close Parenthesis") {
                                                        // Find if there's already a parentheses card in hand that this belongs to
                                                        bool foundParenthesesCard = false;
                                                        for (var handCard in _handCards) {
                                                            if (handCard.type == CardType.parentheses && handCard.name == "Parentheses") {
                                                            // Reset the used flags
                                                            handCard.properties.remove('open_used');
                                                            handCard.properties.remove('close_used');
                                                            foundParenthesesCard = true;
                                                            break;
                                                            }
                                                        }
                                                        
                                                        // If no parentheses card found, add a new one
                                                        if (!foundParenthesesCard) {
                                                            _handCards.add(MathCard(
                                                            name: "Parentheses",
                                                            type: CardType.parentheses,
                                                            cost: 1,
                                                            ));
                                                        }
                                                        } else {
                                                        // Regular card - just add back to hand
                                                        _handCards.add(card);
                                                        }
                                                    });
                                                    }
                                                },
                                                child: _buildBattlefieldCard(entry.value),
                                              ); // GestureDetector
                                        }).toList(),
                                      ),
                                    ),
                                    // Execute button with TRON styling
                                    if (_battlefieldCards.isNotEmpty && !_isOpponentTurn)
                                      Container(
                                        margin: const EdgeInsets.only(left: 12),
                                        child: _buildTronExecuteButton(),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                      // Result overlay with enhanced visuals
                      if (_showingResult)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  SpaceTheme.alienGreen.withOpacity(0.9),
                                  SpaceTheme.cosmicPink.withOpacity(0.7),
                                  SpaceTheme.starYellow.withOpacity(0.9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: SpaceTheme.alienGreen.withOpacity(0.7),
                                  blurRadius: 20,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _lastExpression,
                                    style: SpaceTheme.headlineStyle.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(color: Colors.black, blurRadius: 3),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "DAMAGE: $_lastDamage",
                                    style: SpaceTheme.headlineStyle.copyWith(
                                      fontSize: 24,
                                      color: SpaceTheme.starYellow,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(color: SpaceTheme.starYellow, blurRadius: 8),
                                      ],
                                    ),
                                  ),
                                  if (_lastProperties.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: _lastProperties.map((prop) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: SpaceTheme.starYellow),
                                        ),
                                        child: Text(
                                          prop.toUpperCase(),
                                          style: SpaceTheme.bodyStyle.copyWith(
                                            fontSize: 10,
                                            color: SpaceTheme.starYellow,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Status message with TRON styling
          if (_statusMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SpaceTheme.starYellow.withOpacity(0.3),
                    SpaceTheme.deepSpace.withOpacity(0.9),
                    SpaceTheme.starYellow.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SpaceTheme.starYellow),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.starYellow.withOpacity(0.6),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                _statusMessage.toUpperCase(),
                style: SpaceTheme.bodyStyle.copyWith(
                  color: SpaceTheme.starYellow,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHandArea() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              SpaceTheme.nebulaPurple.withOpacity(0.2),
              SpaceTheme.deepSpace.withOpacity(0.8),
              SpaceTheme.nebulaPurple.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
        ),
        child: Column(
          children: [
            Text(
              "NEURAL ARSENAL",
              style: SpaceTheme.titleStyle.copyWith(
                fontSize: 14,
                color: SpaceTheme.nebulaPurple,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate optimal card dimensions
                  final cardWidth = (constraints.maxWidth - (6 * 8)) / 7; // 7 cards with 8px spacing
                  final cardHeight = constraints.maxHeight - 16; // Leave some padding
                  
      // Hand area uses exact card count, no dynamic generation
      List<Widget> handSlots = [];
      for (int i = 0; i < 7; i++) {
        if (i < _handCards.length) {
          final card = _handCards[i];
          handSlots.add(
            Container(
              width: cardWidth,
              height: cardHeight,
              margin: EdgeInsets.only(right: i < 6 ? 8 : 0),
              child: _buildDraggableCard(card, i),
            ),
          );
        } else {
          handSlots.add(
            Container(
              width: cardWidth,
              height: cardHeight,
              margin: EdgeInsets.only(right: i < 6 ? 8 : 0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12, width: 1),
              ),
              child: Center(
                child: Icon(
                  Icons.add,
                  color: Colors.white12,
                  size: 20,
                ),
              ),
            ),
          );
        }
      }
      
      return Row(children: handSlots);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHealthBar(int current, int max, Color color) {
    final percentage = (current / max).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "HEALTH",
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 8,
                color: Colors.white70,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              "$current",
              style: SpaceTheme.headlineStyle.copyWith(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: color, blurRadius: 6),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.6)],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.8),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: SpaceTheme.bodyStyle.copyWith(
            fontSize: 8,
            color: Colors.white70,
            letterSpacing: 1.0,
          ),
        ),
        Text(
          value,
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: color, blurRadius: 6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTronExecuteButton() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            SpaceTheme.starYellow,
            SpaceTheme.planetOrange,
            SpaceTheme.starYellow.withOpacity(0.8),
          ],
        ),
        border: Border.all(color: SpaceTheme.starYellow, width: 3),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.starYellow.withOpacity(0.8),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isCalculating ? null : _executeBattlefield,
          customBorder: const CircleBorder(),
          child: Center(
            child: _isCalculating
                ? SizedBox(
                    width: 25,
                    height: 25,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow,
                        color: Colors.black,
                        size: 24,
                      ),
                      Text(
                        "EXEC",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTronDeckPile(int count) {
    return GestureDetector(
      onTap: () {
        if (count > 0) {
          _drawCardsFromDeck(1);
          setState(() {});
        }
      },
      child: AnimatedBuilder(
        animation: _drawAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_drawAnimation.value * 0.1),
            child: Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [SpaceTheme.alienGreen, SpaceTheme.cosmicPink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SpaceTheme.alienGreen, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.alienGreen.withOpacity(0.7),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.style,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count.toString(),
                    style: SpaceTheme.headlineStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTronDiscardPile(int count, {bool isTarget = false}) {
    return AnimatedBuilder(
      animation: _discardAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_discardAnimation.value * 0.1),
          child: Container(
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isTarget 
                    ? [SpaceTheme.starYellow, SpaceTheme.nebulaPurple]
                    : [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isTarget ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple, 
                width: isTarget ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isTarget ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple).withOpacity(0.5),
                  blurRadius: isTarget ? 15 : 8,
                  spreadRadius: isTarget ? 3 : 1,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isTarget ? Icons.delete : Icons.delete_outline,
                  color: isTarget ? Colors.white : Colors.white54,
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  count.toString(),
                  style: SpaceTheme.titleStyle.copyWith(
                    fontSize: 12,
                    color: isTarget ? Colors.white : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBattlefieldCard(MathCard card) {
    return Container(
      width: 45,
      height: 65,
      decoration: BoxDecoration(
        gradient: _getCardGradient(card),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _getCardBorderColor(card), width: 2),
        boxShadow: [
          BoxShadow(
            color: _getCardBorderColor(card).withOpacity(0.6),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              _getCardDisplayText(card),
              style: SpaceTheme.headlineStyle.copyWith(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: _getCardBorderColor(card),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SpaceTheme.starYellow),
              ),
              child: Text(
                "${card.cost}",
                style: TextStyle(
                  color: SpaceTheme.starYellow,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableCard(MathCard card, int handIndex) {
    // Special handling for parentheses card - show as two draggable halves in ONE slot
    if (card.type == CardType.parentheses && card.name == "Parentheses") {
      return Row(
        children: [
          Expanded(
            child: Draggable<MathCard>(
              data: MathCard(
                id: "${card.id}_open", // Unique ID for tracking
                name: "Open Parenthesis",
                type: CardType.parentheses,
                cost: 1,
              ),
              feedback: Material(
                color: Colors.transparent,
                child: Transform.scale(
                  scale: 1.2,
                  child: SizedBox(
                    width: 40,
                    height: 120,
                    child: _buildHalfCard("(", card),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: _buildHalfCard("(", card),
              ),
              onDragStarted: () {
                // Mark that we're dragging from this parentheses card
                setState(() {
                  card.properties['dragging_open'] = true;
                });
              },
              onDragEnd: (details) {
                setState(() {
                  card.properties.remove('dragging_open');
                });
              },
              child: _buildHalfCard("(", card),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Draggable<MathCard>(
              data: MathCard(
                id: "${card.id}_close", // Unique ID for tracking
                name: "Close Parenthesis",
                type: CardType.parentheses,
                cost: 1,
              ),
              feedback: Material(
                color: Colors.transparent,
                child: Transform.scale(
                  scale: 1.2,
                  child: SizedBox(
                    width: 40,
                    height: 120,
                    child: _buildHalfCard(")", card),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: _buildHalfCard(")", card),
              ),
              onDragStarted: () {
                setState(() {
                  card.properties['dragging_close'] = true;
                });
              },
              onDragEnd: (details) {
                setState(() {
                  card.properties.remove('dragging_close');
                });
              },
              child: _buildHalfCard(")", card),
            ),
          ),
        ],
      );
    }
    
    // Regular card dragging
    return Draggable<MathCard>(
      data: card,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.2,
          child: SizedBox(
            width: 80,
            height: 120,
            child: _buildCard(card, isBeingDragged: true),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCard(card),
      ),
      child: _buildCard(card, handIndex: handIndex),
    );
  }

  Widget _buildCard(MathCard card, {bool isBeingDragged = false, int? handIndex}) {
    return AnimatedBuilder(
      animation: _cardGlowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: _getCardGradient(card),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getCardBorderColor(card).withOpacity(
                isBeingDragged ? 1.0 : _cardGlowAnimation.value
              ),
              width: isBeingDragged ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getCardBorderColor(card).withOpacity(
                  isBeingDragged ? 0.9 : _cardGlowAnimation.value * 0.6
                ),
                blurRadius: isBeingDragged ? 15 : 8,
                spreadRadius: isBeingDragged ? 3 : 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              // TRON-style background pattern
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CustomPaint(
                    painter: CardPatternPainter(color: _getCardBorderColor(card)),
                    size: const Size(80, 120), // Fixed size
                  ),
                ),
              ),
              // Card content
              Center(
                child: Text(
                  _getCardDisplayText(card),
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: isBeingDragged ? 24 : 22, // Increased from 20:18
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: _getCardBorderColor(card),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              // Energy cost with enhanced visibility
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 24, // Increased from 20
                  height: 24, // Increased from 20
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange],
                    ),
                    border: Border.all(color: Colors.black, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: SpaceTheme.starYellow.withOpacity(0.8),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "${card.cost}",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: isBeingDragged ? 12 : 11, // Increased from 10:9
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHalfCard(String symbol, MathCard originalCard) {
    // Check if this half has been used
    bool isUsed = (symbol == "(" && originalCard.properties['open_used'] == true) ||
                  (symbol == ")" && originalCard.properties['close_used'] == true);
    
    return AnimatedBuilder(
      animation: _cardGlowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: _getCardGradient(originalCard),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getCardBorderColor(originalCard).withOpacity(
                isUsed ? 0.3 : _cardGlowAnimation.value
              ),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getCardBorderColor(originalCard).withOpacity(
                  isUsed ? 0.2 : _cardGlowAnimation.value * 0.6
                ),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              // TRON-style background pattern
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CustomPaint(
                    painter: CardPatternPainter(color: _getCardBorderColor(originalCard)),
                    size: const Size(40, 120),
                  ),
                ),
              ),
              // Card content
              Center(
                child: Text(
                  isUsed ? "✓" : symbol, // Show checkmark if used
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: isUsed ? 24 : 32,
                    color: isUsed ? Colors.white54 : Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: _getCardBorderColor(originalCard),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              // Energy cost (only show on left half and if not used)
              if (symbol == "(" && !isUsed)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange],
                      ),
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        "1", // Each half costs 1
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _getCardDisplayText(MathCard card) {
    // Handle the split parentheses cards
    if (card.type == CardType.parentheses) {
      if (card.name == "Open Parenthesis") {
        return "(";
      } else if (card.name == "Close Parenthesis") {
        return ")";
      } else if (card.name == "Parentheses") {
        return "( )"; // This will be handled specially in _buildDraggableCard
      }
    }
    return card.toString();
  }

  LinearGradient _getCardGradient(MathCard card) {
    switch (card.type) {
      case CardType.number:
        return const LinearGradient(
          colors: [SpaceTheme.alienGreen, SpaceTheme.cosmicPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardType.operator:
        return const LinearGradient(
          colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardType.parentheses:
        return const LinearGradient(
          colors: [SpaceTheme.nebulaPurple, SpaceTheme.cosmicPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getCardBorderColor(MathCard card) {
    switch (card.type) {
      case CardType.number:
        return SpaceTheme.alienGreen;
      case CardType.operator:
        return SpaceTheme.starYellow;
      case CardType.parentheses:
        return SpaceTheme.cosmicPink;
      default:
        return SpaceTheme.nebulaPurple;
    }
  }

  // Dialog methods remain the same as before...
  Widget _buildVictoryDialog(int score) {
    return AlertDialog(
      backgroundColor: SpaceTheme.deepSpace.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: SpaceTheme.alienGreen, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.military_tech, color: SpaceTheme.starYellow, size: 30),
          const SizedBox(width: 10),
          Text(
            S.of(context)!.arithmancerVictoryTitle,
            style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.alienGreen),
          ),
        ],
      ),
      content: Text(
        S.of(context)!.arithmancerVictoryDesc(score),
        style: SpaceTheme.bodyStyle,
      ),
      actions: [
        TextButton(
            onPressed: () {
            Navigator.of(context).pop();
            _advanceToNextEnemy(); // Use new method
            },
            child: Text(
            S.of(context)!.arithmancerNextChallenge,
            style: const TextStyle(color: SpaceTheme.alienGreen),
            ),
        ),
        TextButton(
            onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
            },
            child: Text(
            S.of(context)!.arithmancerReturnToBridge,
            style: const TextStyle(color: SpaceTheme.starYellow),
            ),
        ),
        ],
    );
  }

  Widget _buildLadderStepDialog() {
    return AlertDialog(
      backgroundColor: SpaceTheme.deepSpace.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: SpaceTheme.starYellow, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.trending_up, color: SpaceTheme.starYellow, size: 30),
          const SizedBox(width: 10),
          Text(
            "Ladder Progress",
            style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.starYellow),
          ),
        ],
      ),
      content: Text(
        "Step ${_ladderProgress + 1} of $_totalLadderSteps complete! Continue climbing the neural ladder.",
        style: SpaceTheme.bodyStyle,
      ),
      actions: [
        TextButton(
            onPressed: () {
            Navigator.of(context).pop();
            _advanceToNextEnemy(); // Use new method
            },
            child: Text(
            "Continue Ladder",
            style: const TextStyle(color: SpaceTheme.starYellow),
            ),
        ),
        ],
    );
  }

  Widget _buildLadderCompleteDialog(int score) {
    return AlertDialog(
      backgroundColor: SpaceTheme.deepSpace.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: SpaceTheme.alienGreen, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.emoji_events, color: SpaceTheme.starYellow, size: 30),
          const SizedBox(width: 10),
          Text(
            "Ladder Champion!",
            style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.alienGreen),
          ),
        ],
      ),
      content: Text(
        "Congratulations! You've conquered the entire neural ladder and earned $score points!",
        style: SpaceTheme.bodyStyle,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          child: Text(
            S.of(context)!.arithmancerReturnToBridge,
            style: const TextStyle(color: SpaceTheme.starYellow),
          ),
        ),
      ],
    );
  }

  Widget _buildDefeatDialog() {
    return AlertDialog(
      backgroundColor: SpaceTheme.deepSpace.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: SpaceTheme.rocketRed, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.warning, color: SpaceTheme.rocketRed, size: 30),
          const SizedBox(width: 10),
          Text(
            S.of(context)!.arithmancerDefeatTitle,
            style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.rocketRed),
          ),
        ],
      ),
      content: Text(
        S.of(context)!.arithmancerDefeatDesc,
        style: SpaceTheme.bodyStyle,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _initializeGame();
          },
          child: Text(
            S.of(context)!.arithmancerTryAgain,
            style: const TextStyle(color: SpaceTheme.alienGreen),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          child: Text(
            S.of(context)!.arithmancerReturnToBridge,
            style: const TextStyle(color: SpaceTheme.starYellow),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _combatController.dispose();
    _particleController.dispose();
    _shakeController.dispose();
    _cardGlowController.dispose();
    _energyTransferController.dispose();
    _damageController.dispose();
    _drawController.dispose();
    _discardController.dispose();
    _shieldController.dispose();
    _bonusController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }
}

// Enhanced visual effects classes
class CombatParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double life;
  final double maxLife;
  final String type;

  CombatParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.life,
    required this.type,
  }) : maxLife = life;

  factory CombatParticle.damage(math.Random random) {
    return CombatParticle(
      position: Offset(
        300 + random.nextDouble() * 100,
        200 + random.nextDouble() * 50,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 300,
        -random.nextDouble() * 200,
      ),
      color: [Colors.red, Colors.orange, Colors.yellow][random.nextInt(3)],
      size: 3 + random.nextDouble() * 5,
      life: 0.8 + random.nextDouble() * 0.7,
      type: 'damage',
    );
  }

  factory CombatParticle.explosion(math.Random random) {
    return CombatParticle(
      position: Offset(
        300 + random.nextDouble() * 100,
        200 + random.nextDouble() * 50,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 150,
        -random.nextDouble() * 100,
      ),
      color: [Colors.white, Colors.cyan, Colors.lightBlueAccent][random.nextInt(3)],
      size: 2 + random.nextDouble() * 4,
      life: 1.0 + random.nextDouble() * 0.5,
      type: 'explosion',
    );
  }

  factory CombatParticle.enemyAttack(math.Random random) {
    return CombatParticle(
      position: Offset(
        100 + random.nextDouble() * 200,
        100 + random.nextDouble() * 100,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 200,
        random.nextDouble() * 150,
      ),
      color: [Colors.purple, Colors.deepPurple, Colors.indigo][random.nextInt(3)],
      size: 2 + random.nextDouble() * 3,
      life: 0.6 + random.nextDouble() * 0.4,
      type: 'enemy_attack',
    );
  }

  bool update() {
    position += velocity * 0.016;
    velocity *= 0.96;
    life -= 0.016;
    return life <= 0;
  }

  Widget buildWidget() {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity((life / maxLife).clamp(0.0, 1.0)),
          shape: BoxShape.circle,
          boxShadow: type == 'explosion'
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: size * 2,
                  )
                ]
              : null,
        ),
      ),
    );
  }
}

// Enhanced energy orb with card targeting
class EnergyOrb {
  final double startTime;
  final int targetCardIndex;
  late Offset position;
  late Offset startPosition;
  late Offset endPosition;
  double life = 1.0;

  EnergyOrb({required this.startTime, required this.targetCardIndex}) {
    startPosition = const Offset(400, 400); // Player energy stat position
    // Target a specific card position in battlefield
    endPosition = Offset(
      200 + (targetCardIndex * 60.0),
      280,
    );
    position = startPosition;
  }

  bool update(double animationProgress) {
    final adjustedProgress = ((animationProgress - startTime) / (1.0 - startTime)).clamp(0.0, 1.0);
    
    if (adjustedProgress > 0) {
      position = Offset.lerp(startPosition, endPosition, adjustedProgress)!;
      life = 1.0 - adjustedProgress;
    }
    
    return adjustedProgress >= 1.0;
  }

  Widget buildWidget() {
    return Positioned(
      left: position.dx - 8,
      top: position.dy - 8,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: SpaceTheme.starYellow.withOpacity(life),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: SpaceTheme.starYellow.withOpacity(life * 0.8),
              blurRadius: 12,
              spreadRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}

// Shield effect visualization
class ShieldEffect {
  final String type;
  late Color color;
  late String symbol;
  double rotation = 0.0;

  ShieldEffect({required this.type}) {
    switch (type) {
      case 'prime_shield':
        color = Colors.cyan;
        symbol = "PRIME";
        break;
      case 'fibonacci_only':
        color = Colors.orange;
        symbol = "FIB";
        break;
      case 'square_immune':
        color = Colors.purple;
        symbol = "SQR";
        break;
      case 'power_of_two_only':
        color = Colors.lightBlue;
        symbol = "2^N";
        break;
      default:
        color = Colors.white;
        symbol = "???";
    }
  }

  void update(double animationValue) {
    rotation = animationValue * 2 * math.pi;
  }

  Widget buildWidget() {
    return Positioned(
      top: 20,
      right: 20,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.3),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.7),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              symbol,
              style: TextStyle(
                color: color,
                fontSize: 6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Bonus effect visualization
class BonusEffect {
  final String type;
  final String value;
  final Color color;
  double scale = 0.0;
  double opacity = 1.0;

  BonusEffect({required this.type, required this.value, required this.color});

  void update(double animationValue) {
    scale = animationValue;
    opacity = 1.0 - (animationValue * 0.5);
  }

  Widget buildWidget() {
    return Positioned(
      top: 100,
      left: 50,
      child: Transform.scale(
        scale: scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(opacity * 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(opacity * 0.7),
                blurRadius: 15,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Text(
            "$type $value",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// TRON-style grid painter
class TronGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SpaceTheme.nebulaPurple.withOpacity(0.2)
      ..strokeWidth = 1;

    // Draw grid pattern
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Card pattern painter
class CardPatternPainter extends CustomPainter {
  final Color color;

  CardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = 1;

    // Draw circuit-like patterns
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.2), paint);
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.8), paint);
    canvas.drawLine(Offset(size.width * 0.2, 0), Offset(size.width * 0.2, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.8, 0), Offset(size.width * 0.8, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}