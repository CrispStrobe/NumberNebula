// ignore_for_file: unused_element, unused_field
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../../../shared/utils/arithmancer.dart';

import '../constants/app_constants.dart';
import '../models/math_problem.dart';
import '../../../core/services/sri_service.dart'; 

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
  final List<MathCard> _battlefieldCards = [];
  List<MathCard> _deckCards = [];
  List<MathCard> _discardCards = [];
  
  // Opponent State (for PvP)
  List<MathCard> _opponentHand = [];
  final List<MathCard> _opponentBattlefield = [];
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
  final int _totalLadderSteps = 12; // (3 programs + 1 player) * 3
  int _enemiesDefeated = 0;
  
  // Visual Effects
  final List<CombatParticle> _particles = [];
  final List<EnergyOrb> _energyOrbs = [];
  final List<ShieldEffect> _shieldEffects = [];
  final List<BonusEffect> _bonusEffects = [];
  String _statusMessage = "";
  Timer? _statusTimer;

  // turn skip
  bool _canSkipTurn = false;
  int _accumulatedEnergy = 0;
  bool _showInstructions = false;

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
      _canSkipTurn = true; // Enable skip turn after sync

      // Apply accumulated energy
      if (_accumulatedEnergy > 0) {
        _game.playerEnergy += _accumulatedEnergy;
        _accumulatedEnergy = 0;
      }

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
      _canSkipTurn = true; // Enable skip turn
      
      // Apply accumulated energy
      if (_accumulatedEnergy > 0) {
        playerState.energy += _accumulatedEnergy;
        _accumulatedEnergy = 0;
      }
      
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
        if (!mounted) return;
        _showStatus(S.of(context)!.arithmancerInvalidExpression);
        setState(() => _isCalculating = false);
        _energyTransferController.reverse();
        return;
      }

    // Apply the result - using non-null result
    final nonNullResult = result;
    
    // Debug print the mathematical properties for troubleshooting
    // Enhanced debug logging for troubleshooting
    debugPrint("🔢 === DAMAGE CALCULATION DEBUG ===");
    if (nonNullResult.isChained) {
      debugPrint("🔢 CHAINED EXPRESSION: ${nonNullResult.expression}");
      debugPrint("🔢 Left: ${nonNullResult.leftResult!.expression} = ${nonNullResult.leftResult!.value}");
      debugPrint("🔢 Right: ${nonNullResult.rightResult!.expression} = ${nonNullResult.rightResult!.value}");
      debugPrint("🔢 Combined display value: ${nonNullResult.value}");
    } else {
      debugPrint("🔢 Expression: ${nonNullResult.expression} = ${nonNullResult.value}");
      debugPrint("🔢 Raw damage: ${nonNullResult.damage}");
    }

    if (_currentEnemy != null) {
      debugPrint("🔢 Enemy: ${_currentEnemy!.name}");
      debugPrint("🔢 Enemy health: ${_currentEnemy!.health}/${_currentEnemy!.maxHealth}");
      debugPrint("🔢 Enemy shields: ${_currentEnemy!.mathematicalShields}");
      
      // FIXED: Check shields for each side of chained results
      if (nonNullResult.isChained) {
        debugPrint("🔢 Checking LEFT side (${nonNullResult.leftResult!.value}):");
        _debugShieldCheck(nonNullResult.leftResult!, _currentEnemy!);
        debugPrint("🔢 Checking RIGHT side (${nonNullResult.rightResult!.value}):");
        _debugShieldCheck(nonNullResult.rightResult!, _currentEnemy!);
      } else {
        _debugShieldCheck(nonNullResult, _currentEnemy!);
      }
    }

    // TRACK ARITHMETIC: Extract and record all math problems from the expression
    final mathProblems = _extractMathProblemsFromExpression(result);
    debugPrint('[ARITHMANCER] Expression: ${result.expression}');
    debugPrint('[ARITHMANCER] Extracted ${mathProblems.length} math problems:');
    for (final p in mathProblems) {
      debugPrint('  - ${p.expression} = ${p.answer}');
    }

    if (!mounted) return;
    final sriService = context.read<SriService>();

    // Determine if this was a successful play based on damage dealt
    bool wasSuccessful = result.damage > 0;

    // Record each arithmetic operation with SRI
    for (final problem in mathProblems) {
      sriService.recordResponse(problem, wasSuccessful);
      debugPrint('[ARITHMANCER] Tracked arithmetic: ${problem.expression} = ${problem.answer}');
    }

    if (_currentEnemy != null) {
    debugPrint("🔢 Enemy: ${_currentEnemy!.name}");
    debugPrint("🔢 Enemy health: ${_currentEnemy!.health}/${_currentEnemy!.maxHealth}");
    debugPrint("🔢 Enemy shields: ${_currentEnemy!.mathematicalShields}");
    
    // Check each shield type
    _currentEnemy!.mathematicalShields.forEach((shieldType, threshold) {
        debugPrint("🔢 Shield check - $shieldType: threshold=$threshold");
        switch (shieldType) {
        case 'prime_shield':
            debugPrint("🔢   - Value ${nonNullResult.value} is prime: ${nonNullResult.isPrime}");
            debugPrint("🔢   - Threshold check: ${nonNullResult.value} >= $threshold = ${nonNullResult.value >= threshold}");
            break;
        case 'square_immune':
            debugPrint("🔢   - Value ${nonNullResult.value} is perfect square: ${nonNullResult.isPerfectSquare}");
            break;
        case 'fibonacci_only':
            debugPrint("🔢   - Value ${nonNullResult.value} is fibonacci: ${nonNullResult.isFibonacci}");
            break;
        case 'power_of_two_only':
            debugPrint("🔢   - Value ${nonNullResult.value} is power of two: ${nonNullResult.isPowerOfTwo}");
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
      final gameProvider = context.read<GameProvider>();
      _lastExpression = nonNullResult.expression
          .replaceAll('/', gameProvider.divisionSymbol)
          .replaceAll('*', gameProvider.multiplicationSymbol);
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

  void _debugShieldCheck(MathResult result, MathematicalEnemy enemy) {
    enemy.mathematicalShields.forEach((shieldType, threshold) {
      debugPrint("🔢 Shield check - $shieldType: threshold=$threshold");
      switch (shieldType) {
        case 'prime_shield':
          debugPrint("🔢   - Value ${result.value} is prime: ${result.isPrime}");
          debugPrint("🔢   - Threshold check: ${result.value} >= $threshold = ${result.value >= threshold}");
          break;
        case 'square_immune':
          debugPrint("🔢   - Value ${result.value} is perfect square: ${result.isPerfectSquare}");
          break;
        case 'fibonacci_only':
          debugPrint("🔢   - Value ${result.value} is fibonacci: ${result.isFibonacci}");
          break;
        case 'power_of_two_only':
          debugPrint("🔢   - Value ${result.value} is power of two: ${result.isPowerOfTwo}");
          break;
      }
    });
  }

  void _createBonusEffects(MathResult result) {
    _bonusEffects.clear();
    if (result.isPrime) _bonusEffects.add(BonusEffect(type: S.of(context)!.arithmancerBonusPrime, value: "", color: Colors.cyan));
    if (result.isPerfectSquare) _bonusEffects.add(BonusEffect(type: S.of(context)!.arithmancerBonusSquare, value: "", color: Colors.purple));
    if (result.isFibonacci) _bonusEffects.add(BonusEffect(type: S.of(context)!.arithmancerBonusFibonacci, value: "", color: Colors.orange));
    if (result.isPowerOfTwo) _bonusEffects.add(BonusEffect(type: S.of(context)!.arithmancerBonusBinary, value: "", color: Colors.lightBlue));
    
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
        if (mounted) {
          _showStatus(S.of(context)!.arithmancerEnemyAttack(damage));
        }
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
    // context.read<GameProvider>().addScore(baseScore);

    // Pattern recognition victory tracking
    // Arithmetic was already tracked during each _executeBattlefield() call
    context.read<GameProvider>().recordLevelWin(
      gameType: 'arithmancer_duel',
      scoreGained: baseScore,
      difficulty: widget.level,
      wasSuccessful: true,
      // NO mathProblem - this tracks pattern recognition only
      // Individual arithmetic operations were tracked in real-time
    );
    
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
    final totalScore = baseScore + bonusScore;

    // DUAL TRACKING: Pattern recognition victory (no mathProblem needed)
    // The arithmetic was already tracked during _executeBattlefield()
    context.read<GameProvider>().recordLevelWin(
      gameType: 'arithmancer_duel',
      scoreGained: totalScore,
      difficulty: widget.level,
      wasSuccessful: true,
      // NO mathProblem - arithmetic already tracked per-calculation
    );

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

    // Save current hand before advancing
    final currentHand = List<MathCard>.from(_handCards);
    
    if (widget.gameMode == GameMode.ladder) {
        // Ladder mode: cycle through pattern
        if (_ladderProgress % 4 < 3) {
        // Program mode - preserve enemy progress
        final aiPersonality = _selectAIPersonality(_enemiesDefeated);
        _game = ArithmancerGame(aiPersonality, random, verbose: false);
        _game.enemiesDefeated = _enemiesDefeated; // Preserve progress
        _game.startNewBattle();

        // Restore hand after battle start
        _game.hand = currentHand;

        _syncGameState();
        _createShieldEffects();
        } else {
        // Player mode for 4th step
        _initializePlayerMode(random);
        }
    } else if (widget.gameMode == GameMode.vsPrograms) {
        // Continue with existing game instance to preserve progress
        _game.startNewBattle();

        // Restore hand after battle start
        _game.hand = currentHand;

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
    // Track pattern recognition failure
    // Arithmetic tracking already happened during gameplay
    context.read<GameProvider>().recordLevelWin(
      gameType: 'arithmancer_duel',
      scoreGained: 0,
      difficulty: widget.level,
      wasSuccessful: false,
      // NO mathProblem - arithmetic was tracked per-calculation
    );
    
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
      for (var shield in _shieldEffects) {
        shield.update(_shieldAnimation.value);
      }
      for (var bonus in _bonusEffects) {
        bonus.update(_bonusAnimation.value);
      }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final sideBarWidth = screenWidth * 0.15; 

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
                          width: sideBarWidth,
                          child: _buildDeckArea(),
                        ),
                        // Center - Main game area
                        Expanded(
                          child: Column(
                            children: [
                              // --- FLEX VALUES REBALANCED FOR LARGER CARDS --- ✨

                              Expanded(
                                flex: 4, // OLD: 3 - Shrunk
                                child: _buildOpponentArea(),
                              ),
                              Expanded(
                                flex: 9, // OLD: 5 - Shrunk significantly
                                child: _buildBattlefield(),
                              ),
                              Expanded(
                                flex: 4, // OLD: 3 - Shrunk
                                child: _buildPlayerArea(),
                              ),
                              Expanded(
                                flex: 11, // OLD: 4 - Greatly expanded for larger cards
                                child: _buildHandArea(),
                              ),
                            ],
                          ),
                        ),
                        // Right side - Discard pile
                        SizedBox(
                          width: sideBarWidth,
                          child: _buildDiscardArea(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Visual effects overlay...
              ..._particles.map((p) => p.buildWidget()),
              ..._energyOrbs.map((orb) => orb.buildWidget()),
              ..._shieldEffects.map((shield) => shield.buildWidget()),
              // We use a Positioned Column to stack bonus effects vertically
              if (_bonusEffects.isNotEmpty)
                Positioned(
                  top: 40, // Starting position from the top of the screen
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _bonusEffects.map((bonus) {
                      return Padding(
                        // Add some spacing between each marker
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: bonus.buildWidget(),
                      );
                    }).toList(),
                  ),
                ),

                // info overlay
                if (_showInstructions)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.8),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [SpaceTheme.deepSpace, SpaceTheme.nebulaPurple.withValues(alpha: 0.3)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: SpaceTheme.alienGreen, width: 2),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      S.of(context)!.arithmancerGameplayGuide,
                                      style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.alienGreen),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () => setState(() => _showInstructions = false),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(S.of(context)!.arithmancerGuideBasics, style: SpaceTheme.bodyStyle),
                                const SizedBox(height: 12),
                                Text(S.of(context)!.arithmancerGuideCards, style: SpaceTheme.bodyStyle),
                                const SizedBox(height: 12),
                                Text(S.of(context)!.arithmancerGuideCombat, style: SpaceTheme.bodyStyle),
                                const SizedBox(height: 12),
                                Text(S.of(context)!.arithmancerGuideProperties, style: SpaceTheme.bodyStyle),
                                const SizedBox(height: 12),
                                Text(S.of(context)!.arithmancerGuideShields, style: SpaceTheme.bodyStyle),
                                const SizedBox(height: 12),
                                Text(S.of(context)!.arithmancerGuideDiscard, style: SpaceTheme.bodyStyle),
                                const SizedBox(height: 12),
                                Text(S.of(context)!.arithmancerGuideSkip, style: SpaceTheme.bodyStyle),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),


            ],
          ),
        ),
      ),
    );
  }

  String _getGameModeTitle() {
    switch (widget.gameMode) {
      case GameMode.vsPrograms:
        return S.of(context)!.arithmancerGameModeNeuralBreach;
      case GameMode.vsPlayers:
        return S.of(context)!.arithmancerGameModeAiDuel;
      case GameMode.ladder:
        return S.of(context)!.arithmancerGameModeNeuralLadder;
    }
  }

  String _getEnemyInstructions() {
    if (_currentEnemy == null && _currentAIOpponent == null) {
      return S.of(context)!.arithmancerInstructionsGeneral;
    }
    
    if (_pvpGame != null && _currentAIOpponent != null) {
      return S.of(context)!.arithmancerInstructionsAiPlayer(_currentAIOpponent!.name);
    }
    
    if (_currentEnemy != null) {
      // Get the dominant shield type to provide specific instructions
      String? dominantShield;
      if (_currentEnemy!.mathematicalShields.isNotEmpty) {
        dominantShield = _currentEnemy!.mathematicalShields.keys.first;
      }
      
      switch (dominantShield) {
        case 'prime_shield':
          return S.of(context)!.arithmancerInstructionsPrimeShield;
        case 'square_immune':
          return S.of(context)!.arithmancerInstructionsSquareImmune;
        case 'fibonacci_only':
          return S.of(context)!.arithmancerInstructionsFibonacciOnly;
        case 'power_of_two_only':
          return S.of(context)!.arithmancerInstructionsPowerOfTwoOnly;
        default:
          return S.of(context)!.arithmancerInstructionsGeneral;
      }
    }
    
    return S.of(context)!.arithmancerInstructionsGeneral;
  }

  void _skipTurn() {
    if (_isOpponentTurn || _isCalculating) return;
    
    HapticFeedback.lightImpact();
    
    setState(() {
      // Save current energy for next turn
      int currentEnergy = _pvpGame?.player1State.energy ?? _game.playerEnergy;
      _accumulatedEnergy += currentEnergy;
      
      // Clear battlefield cards back to hand
      for (final card in _battlefieldCards) {
        if (card.name == "Open Parenthesis" || card.name == "Close Parenthesis") {
          // Reset parentheses usage
          for (var handCard in _handCards) {
            if (handCard.type == CardType.parentheses && handCard.name == "Parentheses") {
              handCard.properties.remove('open_used');
              handCard.properties.remove('close_used');
              break;
            }
          }
        } else {
          _handCards.add(card);
        }
      }
      _battlefieldCards.clear();
      
      // Fill hand back to 7 cards
      _drawCardsFromDeck(7 - _handCards.length);
    });
    
    _showStatus(S.of(context)!.arithmancerTurnSkipped);
    
    // Handle enemy turn
    if (_pvpGame != null) {
      _handleOpponentTurn();
    } else {
      _handleEnemyTurn();
    }
  }

  List<MathProblem> _extractMathProblemsFromExpression(MathResult result) {
    List<MathProblem> problems = [];
    
    // FIXED: Use the preserved chain structure
    if (result.isChained) {
      // Process left side
      if (result.leftResult != null) {
        problems.addAll(_extractMathProblemsFromExpression(result.leftResult!));
      }
      // Process right side
      if (result.rightResult != null) {
        problems.addAll(_extractMathProblemsFromExpression(result.rightResult!));
      }
    } else {
      // Single expression - parse it
      final problem = _parseExpressionToProblem(result.expression, widget.grade);
      if (problem != null) problems.add(problem);
    }
    
    return problems;
  }

  MathProblem? _parseExpressionToProblem(String expression, int difficulty) {
    // Remove parentheses for simpler parsing
    expression = expression.replaceAll('(', '').replaceAll(')', '').trim();
    
    // Try to parse simple binary operations: "a op b"
    final operators = ['+', '-', '*', '/'];
    
    for (final opSymbol in operators) {
      if (expression.contains(' $opSymbol ')) {
        final parts = expression.split(' $opSymbol ');
        if (parts.length == 2) {
          final a = int.tryParse(parts[0].trim());
          final b = int.tryParse(parts[1].trim());
          
          if (a != null && b != null) {
            MathOperation operation;
            switch (opSymbol) {
              case '+':
                operation = MathOperation.addition;
                break;
              case '-':
                operation = MathOperation.subtraction;
                break;
              case '*':
                operation = MathOperation.multiplication;
                break;
              case '/':
                operation = MathOperation.division;
                break;
              default:
                return null;
            }
            
            // Calculate the answer
            int answer;
            switch (operation) {
              case MathOperation.addition:
                answer = a + b;
                break;
              case MathOperation.subtraction:
                answer = a - b;
                break;
              case MathOperation.multiplication:
                answer = a * b;
                break;
              case MathOperation.division:
                answer = b != 0 ? (a ~/ b) : 0;
                break;
            }
            
            return MathProblem(
              operandA: a,
              operandB: b,
              operation: operation,
              answer: answer,
              expression: expression,
              difficulty: difficulty,
            );
          }
        }
      }
    }
    
    return null; // Complex expression or single number - skip SRI tracking
  }

  Widget _buildHeader() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [SpaceTheme.deepSpace.withValues(alpha: 0.9), Colors.transparent],
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getGameModeTitle(),
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 16),
                ),
                Text(
                  _getEnemyInstructions(),
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 10, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Info button
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white, size: 20),
            onPressed: () => setState(() => _showInstructions = !_showInstructions),
          ),
          const SizedBox(width: 12), // ADD THIS SPACING
          if (widget.gameMode == GameMode.ladder)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SpaceTheme.starYellow.withValues(alpha: 0.2),
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

  Widget _buildDeckArea() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTronDeckPile(_deckCards.length),
          const SizedBox(height: 8),
          Text(
            S.of(context)!.arithmancerDeck,
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
            onWillAcceptWithDetails: (details) => !_isOpponentTurn,
            onAcceptWithDetails: (details) {
                final card = details.data;
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
            S.of(context)!.arithmancerUsed,
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
                    SpaceTheme.rocketRed.withValues(alpha: 0.1),
                    SpaceTheme.deepSpace.withValues(alpha: 0.9),
                    SpaceTheme.rocketRed.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SpaceTheme.rocketRed, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.rocketRed.withValues(alpha: 0.6),
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
                            gradient: const RadialGradient(
                              colors: [SpaceTheme.rocketRed, SpaceTheme.deepSpace],
                            ),
                            border: Border.all(color: SpaceTheme.rocketRed, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: SpaceTheme.rocketRed.withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
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
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SpaceTheme.rocketRed.withValues(alpha: 0.2),
            SpaceTheme.deepSpace.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.rocketRed, width: 2),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.rocketRed.withValues(alpha: 0.6),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          // Enemy Avatar
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SpaceTheme.rocketRed,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.black, size: 18),
          ),
          const SizedBox(width: 8),
          // Enemy Name (uses FittedBox to scale down if needed)
          SizedBox(
            height: 20,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                _currentEnemy!.name.toUpperCase(),
                style: SpaceTheme.headlineStyle.copyWith(
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Health Bar and Text combined
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120, // A fixed width for the health bar itself
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: SpaceTheme.rocketRed.withValues(alpha: 0.5)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: (_currentEnemy!.health / _currentEnemy!.maxHealth).clamp(0.0, 1.0),
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(SpaceTheme.rocketRed),
                  ),
                ),
              ),
              Text(
                "${_currentEnemy!.health}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
            ],
          ),
          // Shields will now be handled differently if needed,
          // as they would need to be placed in the Row or outside in the parent Stack.
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    final int currentHealth = _pvpGame?.player1State.health ?? _game.playerHealth;
    final int maxHealth = _pvpGame != null ? 120 : _game.maxHealth;
    final int currentEnergy = _pvpGame?.player1State.energy ?? _game.playerEnergy;
    final int currentBlock = _pvpGame?.player1State.block ?? _game.currentBlock;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SpaceTheme.alienGreen.withValues(alpha: 0.2),
            SpaceTheme.deepSpace.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.alienGreen, width: 2),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.alienGreen.withValues(alpha: 0.6),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          // Player Avatar
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SpaceTheme.alienGreen,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Icon(Icons.person, color: Colors.black, size: 18),
          ),
          const SizedBox(width: 8),
          // Health Bar and Text combined
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: SpaceTheme.alienGreen.withValues(alpha: 0.5)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      value: (currentHealth / maxHealth).clamp(0.0, 1.0),
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(SpaceTheme.alienGreen),
                    ),
                  ),
                ),
                Text(
                  "${S.of(context)!.arithmancerHealth}: $currentHealth",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Energy and Shield Stats
          _buildCompactStat("E", "$currentEnergy", SpaceTheme.starYellow),
          const SizedBox(width: 6),
          _buildCompactStat("S", "$currentBlock", SpaceTheme.nebulaPurple),
        ],
      ),
    );
  }

  Widget _buildBattlefield() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Stack( // Changed from Column to Stack
        children: [
          // Battle zone with TRON styling
          DragTarget<MathCard>(
            onWillAcceptWithDetails: (details) {
              setState(() => _isDraggingCard = true);
              return !_isOpponentTurn;
            },
            onLeave: (card) {
              setState(() => _isDraggingCard = false);
            },
            onAcceptWithDetails: (details) {
              final card = details.data;
              HapticFeedback.lightImpact();
              setState(() {
                _battlefieldCards.add(card);

                if (card.name == "Open Parenthesis" || card.name == "Close Parenthesis") {
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
                            SpaceTheme.starYellow.withValues(alpha: 0.3),
                            SpaceTheme.alienGreen.withValues(alpha: 0.2),
                            SpaceTheme.starYellow.withValues(alpha: 0.3),
                          ]
                        : [
                            SpaceTheme.deepSpace.withValues(alpha: 0.4),
                            SpaceTheme.nebulaPurple.withValues(alpha: 0.2),
                            SpaceTheme.deepSpace.withValues(alpha: 0.4),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isDraggingCard ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple,
                    width: 2,
                  ),
                  boxShadow: _isDraggingCard ? [
                    BoxShadow(
                      color: SpaceTheme.starYellow.withValues(alpha: 0.7),
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
                          size: const Size(400, 200),
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
                                    _isOpponentTurn ? Icons.hourglass_empty : Icons.skip_next,
                                    color: Colors.white30,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isOpponentTurn 
                                        ? S.of(context)!.arithmancerOpponentProcessing
                                        : S.of(context)!.arithmancerDragCards,
                                    style: SpaceTheme.bodyStyle.copyWith(
                                      color: Colors.white30,
                                      fontSize: 12,
                                      letterSpacing: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  // SKIP BUTTON when battlefield is empty
                                  if (!_isOpponentTurn && !_isCalculating)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: _buildTronSkipButton(),
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
                                                
                                                if (card.name == "Open Parenthesis" || card.name == "Close Parenthesis") {
                                                  bool foundParenthesesCard = false;
                                                  for (var handCard in _handCards) {
                                                    if (handCard.type == CardType.parentheses && handCard.name == "Parentheses") {
                                                      handCard.properties.remove('open_used');
                                                      handCard.properties.remove('close_used');
                                                      foundParenthesesCard = true;
                                                      break;
                                                    }
                                                  }
                                                  
                                                  if (!foundParenthesesCard) {
                                                    _handCards.add(MathCard(
                                                      name: "Parentheses",
                                                      type: CardType.parentheses,
                                                      cost: 1,
                                                    ));
                                                  }
                                                } else {
                                                  _handCards.add(card);
                                                }
                                              });
                                            }
                                          },
                                          child: _buildBattlefieldCard(entry.value),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  // EXECUTE BUTTON when battlefield has cards
                                  if (!_isOpponentTurn)
                                    Container(
                                      margin: const EdgeInsets.only(left: 12),
                                      child: _buildTronExecuteButton(),
                                    ),
                                ],
                              ),
                            ),
                    ),
                    // Result overlay
                    if (_showingResult)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                SpaceTheme.alienGreen.withValues(alpha: 0.9),
                                SpaceTheme.cosmicPink.withValues(alpha: 0.7),
                                SpaceTheme.starYellow.withValues(alpha: 0.9),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: SpaceTheme.alienGreen.withValues(alpha: 0.7),
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
                                      const Shadow(color: Colors.black, blurRadius: 3),
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
                                      const Shadow(color: SpaceTheme.starYellow, blurRadius: 8),
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
                                        color: Colors.black.withValues(alpha: 0.8),
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
          
          // Status message - absolutely positioned at bottom
          if (_statusMessage.isNotEmpty)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        SpaceTheme.starYellow.withValues(alpha: 0.3),
                        SpaceTheme.deepSpace.withValues(alpha: 0.9),
                        SpaceTheme.starYellow.withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SpaceTheme.starYellow),
                    boxShadow: [
                      BoxShadow(
                        color: SpaceTheme.starYellow.withValues(alpha: 0.6),
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
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTronSkipButton() {
    return Container(
      width: 80,  // Increased from 60
      height: 80, // Increased from 60
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            SpaceTheme.nebulaPurple,
            SpaceTheme.cosmicPink,
            SpaceTheme.nebulaPurple.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(color: SpaceTheme.nebulaPurple, width: 3),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.nebulaPurple.withValues(alpha: 0.8),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isCalculating ? null : _skipTurn,
          customBorder: const CircleBorder(),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Important for preventing overflow
              children: [
                const Icon(
                  Icons.skip_next,
                  color: Colors.white,
                  size: 28, // Slightly larger
                ),
                const SizedBox(height: 4),
                Flexible( // Wrap text in Flexible to prevent overflow
                  child: Text(
                    S.of(context)!.arithmancerSkipTurn,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9, // Slightly larger
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandArea() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.nebulaPurple.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            height: 28,
            alignment: Alignment.center,
            child: Text(
              S.of(context)!.arithmancerHand,
              style: SpaceTheme.titleStyle.copyWith(
                fontSize: 12,
                color: SpaceTheme.nebulaPurple,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - (6 * 6)) / 7;
                  final double cardHeight = constraints.maxHeight;

                  if (cardHeight <= 0) return const SizedBox.shrink();

                  List<Widget> handSlots = [];
                  for (int i = 0; i < 7; i++) {
                    if (i < _handCards.length) {
                      final card = _handCards[i];
                      handSlots.add(
                        Container(
                          width: cardWidth,
                          height: cardHeight,
                          margin: EdgeInsets.only(right: i < 6 ? 6 : 0),
                          child: _buildDraggableCard(card, i),
                        ),
                      );
                    } else {
                      handSlots.add(
                        Container(
                          width: cardWidth,
                          height: cardHeight,
                          margin: EdgeInsets.only(right: i < 6 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  }
                  return Row(children: handSlots);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHealthBar(int current, int max, Color color) {
    final percentage = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Constrains the Column's size to its children
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "HEALTH",
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 7, // CHANGED from 8
                color: Colors.white70,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              "$current",
              style: SpaceTheme.headlineStyle.copyWith(
                fontSize: 14, // CHANGED from 18
                color: color,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: color, blurRadius: 4), // Reduced blur
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2), // Unchanged, but feels right with smaller fonts
        Container(
          height: 5, // CHANGED from 6
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.8),
                    blurRadius: 3, // Reduced blur
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
      mainAxisSize: MainAxisSize.min, // Constrains the Column's size
      children: [
        Text(
          label,
          style: SpaceTheme.bodyStyle.copyWith(
            fontSize: 7, // CHANGED from 8
            color: Colors.white70,
            letterSpacing: 1.0,
          ),
        ),
        Text(
          value,
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: 12, // CHANGED from 16
            color: color,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: color, blurRadius: 4), // Reduced blur
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
            SpaceTheme.starYellow.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(color: SpaceTheme.starYellow, width: 3),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.starYellow.withValues(alpha: 0.8),
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
                ? const SizedBox(
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
                      const Icon(
                        Icons.play_arrow,
                        color: Colors.black,
                        size: 24,
                      ),
                      Text(
                        S.of(context)!.arithmancerExecute,
                        style: const TextStyle(
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
    // Removed GestureDetector wrapper because it is too easy if players can draw cards at will
    return AnimatedBuilder(
      animation: _drawAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_drawAnimation.value * 0.1),
          child: Container(
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [SpaceTheme.alienGreen, SpaceTheme.cosmicPink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SpaceTheme.alienGreen, width: 2),
              boxShadow: [
                BoxShadow(
                  color: SpaceTheme.alienGreen.withValues(alpha: 0.7),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
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
                  color: (isTarget ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple).withValues(alpha: 0.5),
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
            color: _getCardBorderColor(card).withValues(alpha: 0.6),
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
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SpaceTheme.starYellow),
              ),
              child: Text(
                "${card.cost}",
                style: const TextStyle(
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
              color: _getCardBorderColor(card).withValues(alpha: 
                isBeingDragged ? 1.0 : _cardGlowAnimation.value
              ),
              width: isBeingDragged ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getCardBorderColor(card).withValues(alpha: 
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
                    gradient: const RadialGradient(
                      colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange],
                    ),
                    border: Border.all(color: Colors.black, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: SpaceTheme.starYellow.withValues(alpha: 0.8),
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
              color: _getCardBorderColor(originalCard).withValues(alpha: 
                isUsed ? 0.3 : _cardGlowAnimation.value
              ),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getCardBorderColor(originalCard).withValues(alpha: 
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
                      gradient: const RadialGradient(
                        colors: [SpaceTheme.starYellow, SpaceTheme.planetOrange],
                      ),
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: const Center(
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
      backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.95),
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
      backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: SpaceTheme.starYellow, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.trending_up, color: SpaceTheme.starYellow, size: 30),
          const SizedBox(width: 10),
          Text(
            S.of(context)!.arithmancerLadderProgressTitle,
            style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.starYellow),
          ),
        ],
      ),
      content: Text(
        S.of(context)!.arithmancerLadderProgressDesc(_ladderProgress + 1, _totalLadderSteps),
        style: SpaceTheme.bodyStyle,
      ),
      actions: [
        TextButton(
            onPressed: () {
            Navigator.of(context).pop();
            _advanceToNextEnemy();
            },
            child: Text(
            S.of(context)!.arithmancerLadderContinue,
            style: const TextStyle(color: SpaceTheme.starYellow),
            ),
        ),
        ],
    );
  }

  Widget _buildLadderCompleteDialog(int score) {
    return AlertDialog(
      backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: SpaceTheme.alienGreen, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.emoji_events, color: SpaceTheme.starYellow, size: 30),
          const SizedBox(width: 10),
          Text(
            S.of(context)!.arithmancerLadderChampionTitle,
            style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.alienGreen),
          ),
        ],
      ),
      content: Text(
        S.of(context)!.arithmancerLadderChampionDesc(score),
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
      backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.95),
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
          color: color.withValues(alpha: (life / maxLife).clamp(0.0, 1.0)),
          shape: BoxShape.circle,
          boxShadow: type == 'explosion'
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
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
          color: SpaceTheme.starYellow.withValues(alpha: life),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: SpaceTheme.starYellow.withValues(alpha: life * 0.8),
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
        symbol = "PRM";
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
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.7),
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
// Bonus effect visualization (Corrected)
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

  // FIX: Removed the Positioned widget from this method.
  // It now only returns the visual representation of the marker.
  Widget buildWidget() {
    // The text to display, omitting the value if it's empty.
    final displayText = value.isEmpty ? type : "$type $value";

    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity * 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity * 0.7),
              blurRadius: 15,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Text(
          displayText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
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
      ..color = SpaceTheme.nebulaPurple.withValues(alpha: 0.2)
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
      ..color = color.withValues(alpha: 0.1)
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

class ArithmancerModeSelection extends StatelessWidget {
  final int grade;
  final int level;

  const ArithmancerModeSelection({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [SpaceTheme.deepSpace.withValues(alpha: 0.9), Colors.transparent],
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            S.of(context)!.arithmancerGameTitle,
                            style: SpaceTheme.headlineStyle.copyWith(fontSize: 20),
                          ),
                          Text(
                            S.of(context)!.arithmancerModeSelectionSubtitle,
                            style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Mode selection cards
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildModeCard(
                        context,
                        title: S.of(context)!.arithmancerGameModeNeuralBreach,
                        subtitle: S.of(context)!.arithmancerModeNeuralBreachDesc,
                        icon: Icons.memory,
                        color: SpaceTheme.alienGreen,
                        onTap: () => _startGame(context, GameMode.vsPrograms),
                      ),
                      const SizedBox(height: 16),
                      _buildModeCard(
                        context,
                        title: S.of(context)!.arithmancerGameModeAiDuel,
                        subtitle: S.of(context)!.arithmancerModeAiDuelDesc,
                        icon: Icons.psychology,
                        color: SpaceTheme.rocketRed,
                        onTap: () => _startGame(context, GameMode.vsPlayers),
                      ),
                      const SizedBox(height: 16),
                      _buildModeCard(
                        context,
                        title: S.of(context)!.arithmancerGameModeNeuralLadder,
                        subtitle: S.of(context)!.arithmancerModeNeuralLadderDesc,
                        icon: Icons.trending_up,
                        color: SpaceTheme.starYellow,
                        onTap: () => _startGame(context, GameMode.ladder),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 120,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  SpaceTheme.deepSpace.withValues(alpha: 0.9),
                  color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.3),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: SpaceTheme.headlineStyle.copyWith(
                          fontSize: 18,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: SpaceTheme.bodyStyle.copyWith(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context, GameMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArithmancerDuelGame(
          grade: grade,
          level: level,
          gameMode: mode,
        ),
      ),
    );
  }
}