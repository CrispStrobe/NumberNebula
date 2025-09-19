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

class ArithmancerDuelGame extends StatefulWidget {
  final int grade;
  final int level;

  const ArithmancerDuelGame({
    super.key,
    required this.grade,
    required this.level,
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
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  // Game State
  late ArithmancerGame _game;
  List<MathCard> _handCards = [];
  List<MathCard> _expressionCards = [];
  MathematicalEnemy? _currentEnemy;
  
  // UI State
  bool _isCalculating = false;
  String _lastExpression = "";
  int _lastDamage = 0;
  List<String> _lastProperties = [];
  bool _showingResult = false;
  
  // Visual Effects
  List<CombatParticle> _particles = [];
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
    )..addListener(_updateParticles)..repeat();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut)
    );
  }

  void _initializeGame() {
    final random = math.Random();
    AIPersonality aiPersonality;
    
    // Select AI based on level for variety
    switch (widget.level % 3) {
      case 0:
        aiPersonality = PrimeHunterAI();
        break;
      case 1:
        aiPersonality = SequenceWeaverAI();
        break;
      default:
        aiPersonality = DefensiveMathAI();
        break;
    }

    _game = ArithmancerGame(aiPersonality, random, verbose: false);
    _game.startNewBattle();
    _updateGameState();
  }

  void _updateGameState() {
    setState(() {
      _handCards = List.from(_game.hand);
      _currentEnemy = _game.currentEnemy;
      _expressionCards.clear();
      _showingResult = false;
    });
  }

  void _addCardToExpression(MathCard card) {
    HapticFeedback.lightImpact();
    
    setState(() {
      _expressionCards.add(card);
      _handCards.remove(card);
    });
  }

  void _removeCardFromExpression(int index) {
    HapticFeedback.lightImpact();
    
    setState(() {
      final card = _expressionCards.removeAt(index);
      _handCards.add(card);
    });
  }

  void _clearExpression() {
    setState(() {
      _handCards.addAll(_expressionCards);
      _expressionCards.clear();
    });
  }

  void _executeExpression() async {
    if (_expressionCards.isEmpty || _isCalculating) return;
    
    setState(() {
      _isCalculating = true;
      _showingResult = false;
    });

    // Calculate the mathematical result using the correct API
    final evaluator = ExpressionEvaluator();
    final allResults = evaluator.generateAllResults(_expressionCards);
    
    // Find the result that uses exactly our expression cards
    MathResult? result;
    for (final r in allResults) {
      if (r.usedCards.length == _expressionCards.length) {
        // Check if it uses the same cards (by comparing IDs)
        final usedIds = r.usedCards.map((c) => c.id).toSet();
        final expressionIds = _expressionCards.map((c) => c.id).toSet();
        if (usedIds.containsAll(expressionIds) && expressionIds.containsAll(usedIds)) {
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
      return;
    }

    // Check if player has enough energy
    final cost = _expressionCards.fold(0, (sum, card) => sum + card.cost);
    if (cost > _game.playerEnergy) {
      _showStatus(S.of(context)!.arithmancerNotEnoughEnergy);
      setState(() {
        _isCalculating = false;
      });
      return;
    }

    // At this point, result is definitely not null
    final nonNullResult = result; // This helps with null safety

    // Apply the result manually since _executeResult is private
    _game.playerEnergy -= cost;
    
    // Remove used cards from hand (they're already removed from _expressionCards)
    for (final card in nonNullResult.usedCards) {
      _game.hand.removeWhere((c) => c.id == card.id);
    }
    
    // Apply damage to enemy
    if (nonNullResult.damage > 0 && _currentEnemy != null) {
      final damageDealt = _currentEnemy!.takeDamage(nonNullResult, _game);
      _lastDamage = damageDealt;
    } else {
      _lastDamage = 0;
    }
    
    // Apply block if negative result
    if (nonNullResult.block > 0) {
      _game.currentBlock += nonNullResult.block;
    }
    
    setState(() {
      _lastExpression = nonNullResult.expression;
      _lastDamage = _lastDamage; // Use the damage we calculated above
      _lastProperties = _getPropertyStrings(nonNullResult);
      _showingResult = true;
      _isCalculating = false;
      _expressionCards.clear(); // Cards are consumed
    });

    // Visual effects
    if (nonNullResult.damage > 0) {
      _addDamageParticles();
      HapticFeedback.mediumImpact();
    }

    // Check if enemy is defeated
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (_currentEnemy!.health <= 0) {
      _handleEnemyDefeated();
    } else {
      // Enemy's turn
      _handleEnemyTurn();
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
    final baseScore = 200 * widget.grade;
    final bonusScore = (_game.playerHealth / _game.maxHealth * 100).round();
    context.read<GameProvider>().addScore(baseScore + bonusScore);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildVictoryDialog(baseScore + bonusScore),
    );
  }

  void _handleEnemyTurn() {
    _shakeController.forward(from: 0.0);
    
    final intent = _currentEnemy!.getIntent();
    final damage = intent['attack'] ?? 0;
    
    if (damage > 0) {
      final actualDamage = math.max<int>(0, damage - _game.currentBlock);
      _game.playerHealth -= actualDamage;
      _showStatus(S.of(context)!.arithmancerEnemyAttack(damage));
      
      if (_game.playerHealth <= 0) {
        _handleDefeat();
        return;
      }
    }

    // Start next turn
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _game.startTurn();
        _updateGameState();
      }
    });
  }

  void _handleDefeat() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildDefeatDialog(),
    );
  }

  void _addDamageParticles() {
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(CombatParticle.damage(random));
    }
  }

  void _updateParticles() {
    setState(() {
      _particles.removeWhere((p) => p.update());
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
          child: Column(
            children: [
              GameUI(
                title: S.of(context)!.arithmancerGameTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              _buildGameHeader(),
              Expanded(
                child: Column(
                  children: [
                    _buildEnemyArea(),
                    _buildExpressionArea(),
                    _buildHandArea(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: SpaceTheme.cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatWidget(
            icon: Icons.favorite,
            label: S.of(context)!.arithmancerHealth,
            value: "${_game.playerHealth}/${_game.maxHealth}",
            color: SpaceTheme.rocketRed,
          ),
          _buildStatWidget(
            icon: Icons.flash_on,
            label: S.of(context)!.arithmancerEnergy,
            value: "${_game.playerEnergy}/${_game.maxEnergy}",
            color: SpaceTheme.starYellow,
          ),
          _buildStatWidget(
            icon: Icons.shield,
            label: S.of(context)!.arithmancerBlock,
            value: "${_game.currentBlock}",
            color: SpaceTheme.alienGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStatWidget({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
        ),
        Text(
          value,
          style: SpaceTheme.titleStyle.copyWith(color: color, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildEnemyArea() {
    if (_currentEnemy == null) {
      return const SizedBox(height: 120);
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: SpaceTheme.cardDecoration.copyWith(
        border: Border.all(color: SpaceTheme.rocketRed, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentEnemy!.name,
                      style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.rocketRed),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentEnemy!.lore,
                      style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _pulseAnimation,
                child: Icon(
                  Icons.android,
                  size: 48,
                  color: SpaceTheme.rocketRed,
                ),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Health bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (_currentEnemy!.health / _currentEnemy!.maxHealth).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [SpaceTheme.rocketRed, SpaceTheme.planetOrange],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${_currentEnemy!.health}/${_currentEnemy!.maxHealth} HP",
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
          ),
          // Mathematical shields
          if (_currentEnemy!.mathematicalShields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _currentEnemy!.mathematicalShields.keys.map((shield) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SpaceTheme.alienGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SpaceTheme.alienGreen),
                  ),
                  child: Text(
                    _getShieldName(shield),
                    style: SpaceTheme.bodyStyle.copyWith(
                      fontSize: 10,
                      color: SpaceTheme.alienGreen,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _getShieldName(String shieldKey) {
    final l10n = S.of(context)!;
    switch (shieldKey) {
      case 'prime_shield': return l10n.arithmancerShieldPrime;
      case 'even_absorb': return l10n.arithmancerShieldEven;
      case 'odd_vulnerable': return l10n.arithmancerShieldOdd;
      case 'square_immune': return l10n.arithmancerShieldSquare;
      case 'fibonacci_only': return l10n.arithmancerShieldFibonacci;
      case 'power_of_two_only': return l10n.arithmancerShieldPowerOfTwo;
      default: return shieldKey;
    }
  }

  Widget _buildExpressionArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: SpaceTheme.cardDecoration,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.arithmancerExpression,
                style: SpaceTheme.titleStyle,
              ),
              Row(
                children: [
                  if (_expressionCards.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: SpaceTheme.rocketRed),
                      onPressed: _clearExpression,
                    ),
                  ElevatedButton(
                    onPressed: _expressionCards.isEmpty || _isCalculating 
                        ? null 
                        : _executeExpression,
                    style: SpaceTheme.primaryButtonStyle,
                    child: _isCalculating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(S.of(context)!.arithmancerExecute),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Expression builder
          Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SpaceTheme.nebulaPurple),
            ),
            child: _expressionCards.isEmpty
                ? Center(
                    child: Text(
                      S.of(context)!.arithmancerDragCards,
                      style: SpaceTheme.bodyStyle.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _expressionCards.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _removeCardFromExpression(index),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: _buildCard(_expressionCards[index], isInExpression: true),
                        ),
                      );
                    },
                  ),
          ),
          // Result display
          if (_showingResult) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SpaceTheme.alienGreen, SpaceTheme.cosmicPink],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    "$_lastExpression = ${_lastDamage}",
                    style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
                  ),
                  if (_lastProperties.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _lastProperties.join(" • "),
                      style: SpaceTheme.bodyStyle.copyWith(
                        fontSize: 12,
                        color: SpaceTheme.starYellow,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          // Status message
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: SpaceTheme.bodyStyle.copyWith(color: SpaceTheme.starYellow),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHandArea() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          children: [
            Text(
              S.of(context)!.arithmancerHand,
              style: SpaceTheme.titleStyle,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _handCards.isEmpty
                  ? Center(
                      child: Text(
                        S.of(context)!.arithmancerNoCards,
                        style: SpaceTheme.bodyStyle.copyWith(color: Colors.white54),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: _handCards.length,
                      itemBuilder: (context, index) {
                        final card = _handCards[index];
                        return GestureDetector(
                          onTap: () => _addCardToExpression(card),
                          child: _buildCard(card),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(MathCard card, {bool isInExpression = false}) {
    Color borderColor;
    Color backgroundColor;
    
    switch (card.type) {
      case CardType.number:
        borderColor = SpaceTheme.alienGreen;
        backgroundColor = SpaceTheme.alienGreen.withOpacity(0.2);
        break;
      case CardType.operator:
        borderColor = SpaceTheme.starYellow;
        backgroundColor = SpaceTheme.starYellow.withOpacity(0.2);
        break;
      case CardType.parentheses:
        borderColor = SpaceTheme.cosmicPink;
        backgroundColor = SpaceTheme.cosmicPink.withOpacity(0.2);
        break;
      default:
        borderColor = SpaceTheme.nebulaPurple;
        backgroundColor = SpaceTheme.nebulaPurple.withOpacity(0.2);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.toString(),
            style: SpaceTheme.headlineStyle.copyWith(
              fontSize: isInExpression ? 16 : 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "${card.cost}E",
              style: SpaceTheme.bodyStyle.copyWith(
                fontSize: 10,
                color: SpaceTheme.starYellow,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            _initializeGame();
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
    _statusTimer?.cancel();
    super.dispose();
  }
}

class CombatParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double life;
  final double maxLife;

  CombatParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.life,
  }) : maxLife = life;

  factory CombatParticle.damage(math.Random random) {
    return CombatParticle(
      position: Offset(
        200 + random.nextDouble() * 200,
        150 + random.nextDouble() * 100,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 200,
        -random.nextDouble() * 150,
      ),
      color: [Colors.red, Colors.orange, Colors.yellow][random.nextInt(3)],
      size: 2 + random.nextDouble() * 4,
      life: 0.5 + random.nextDouble() * 0.5,
    );
  }

  bool update() {
    position += velocity * 0.016;
    velocity *= 0.98;
    life -= 0.016;
    return life <= 0;
  }
}