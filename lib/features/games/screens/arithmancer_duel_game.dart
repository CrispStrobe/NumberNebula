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
  late AnimationController _cardGlowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _cardGlowAnimation;

  // Game State
  late ArithmancerGame _game;
  List<MathCard> _handCards = [];
  List<MathCard> _battlefieldCards = [];
  MathematicalEnemy? _currentEnemy;
  
  // UI State
  bool _isCalculating = false;
  String _lastExpression = "";
  int _lastDamage = 0;
  List<String> _lastProperties = [];
  bool _showingResult = false;
  bool _isDraggingCard = false;
  
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

    _cardGlowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _cardGlowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _cardGlowController, curve: Curves.easeInOut)
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
      _battlefieldCards.clear();
      _showingResult = false;
    });
  }

  void _executeBattlefield() async {
    if (_battlefieldCards.isEmpty || _isCalculating) return;
    
    setState(() {
      _isCalculating = true;
      _showingResult = false;
    });

    // Calculate the mathematical result using the correct API
    final evaluator = ExpressionEvaluator();
    final allResults = evaluator.generateAllResults(_battlefieldCards);
    
    // Find the result that uses exactly our battlefield cards
    MathResult? result;
    for (final r in allResults) {
      if (r.usedCards.length == _battlefieldCards.length) {
        // Check if it uses the same cards (by comparing IDs)
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
      return;
    }

    // Check if player has enough energy
    final cost = _battlefieldCards.fold(0, (sum, card) => sum + card.cost);
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
    
    // Remove used cards from hand (they're already removed from _battlefieldCards)
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
      _battlefieldCards.clear(); // Cards are consumed
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
              _buildCompactHeader(),
              Expanded(
                child: Column(
                  children: [
                    _buildEnemyArea(),
                    _buildBattlefield(),
                    Expanded(child: _buildHandArea()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
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
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            S.of(context)!.arithmancerGameTitle,
            style: SpaceTheme.headlineStyle.copyWith(fontSize: 18),
          ),
          const Spacer(),
          _buildCompactStat(Icons.favorite, "${_game.playerHealth}", SpaceTheme.rocketRed),
          const SizedBox(width: 16),
          _buildCompactStat(Icons.flash_on, "${_game.playerEnergy}", SpaceTheme.starYellow),
          const SizedBox(width: 16),
          _buildCompactStat(Icons.shield, "${_game.currentBlock}", SpaceTheme.alienGreen),
        ],
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: SpaceTheme.titleStyle.copyWith(color: color, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildEnemyArea() {
    if (_currentEnemy == null) return const SizedBox.shrink();

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [SpaceTheme.rocketRed.withOpacity(0.2), SpaceTheme.deepSpace.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.rocketRed.withOpacity(0.5), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentEnemy!.name,
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 16, color: SpaceTheme.rocketRed),
                ),
                const SizedBox(height: 4),
                // Health bar
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: SpaceTheme.deepSpace,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (_currentEnemy!.health / _currentEnemy!.maxHealth).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [SpaceTheme.rocketRed, SpaceTheme.planetOrange],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${_currentEnemy!.health}/${_currentEnemy!.maxHealth} HP",
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 10),
                ),
                // Shields
                if (_currentEnemy!.mathematicalShields.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: _currentEnemy!.mathematicalShields.keys.take(2).map((shield) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: SpaceTheme.alienGreen.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getShieldName(shield),
                          style: SpaceTheme.bodyStyle.copyWith(
                            fontSize: 8,
                            color: SpaceTheme.alienGreen,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _pulseAnimation,
            child: Icon(
              Icons.smart_toy,
              size: 40,
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

  Widget _buildBattlefield() {
    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Battle zone
          Expanded(
            child: DragTarget<MathCard>(
              onWillAccept: (card) {
                setState(() => _isDraggingCard = true);
                return card != null;
              },
              onLeave: (card) {
                setState(() => _isDraggingCard = false);
              },
              onAccept: (card) {
                HapticFeedback.lightImpact();
                setState(() {
                  _battlefieldCards.add(card);
                  _handCards.remove(card);
                  _isDraggingCard = false;
                });
              },
              builder: (context, candidateData, rejectedData) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isDraggingCard 
                          ? [SpaceTheme.starYellow.withOpacity(0.3), SpaceTheme.alienGreen.withOpacity(0.3)]
                          : [SpaceTheme.deepSpace.withOpacity(0.6), SpaceTheme.nebulaPurple.withOpacity(0.3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isDraggingCard ? SpaceTheme.starYellow : SpaceTheme.nebulaPurple,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Battlefield cards
                      Positioned.fill(
                        child: _battlefieldCards.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.ads_click,
                                      color: Colors.white38,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      S.of(context)!.arithmancerDragCards,
                                      style: SpaceTheme.bodyStyle.copyWith(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _battlefieldCards.asMap().entries.map((entry) {
                                          return GestureDetector(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              setState(() {
                                                final card = _battlefieldCards.removeAt(entry.key);
                                                _handCards.add(card);
                                              });
                                            },
                                            child: _buildBattlefieldCard(entry.value),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    // Execute button
                                    if (_battlefieldCards.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        child: ElevatedButton(
                                          onPressed: _isCalculating ? null : _executeBattlefield,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: SpaceTheme.starYellow,
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          ),
                                          child: _isCalculating
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                                  ),
                                                )
                                              : Text(
                                                  S.of(context)!.arithmancerExecute,
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                        ),
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
                                  SpaceTheme.alienGreen.withOpacity(0.8),
                                  SpaceTheme.cosmicPink.withOpacity(0.8)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "$_lastExpression = $_lastDamage",
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
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Status message
          if (_statusMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: SpaceTheme.deepSpace.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage,
                style: SpaceTheme.bodyStyle.copyWith(
                  color: SpaceTheme.starYellow,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBattlefieldCard(MathCard card) {
    return Container(
      width: 50,
      height: 70,
      decoration: BoxDecoration(
        gradient: _getCardGradient(card),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getCardBorderColor(card), width: 2),
        boxShadow: [
          BoxShadow(
            color: _getCardBorderColor(card).withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.toString(),
            style: SpaceTheme.headlineStyle.copyWith(
              fontSize: 16,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: _getCardBorderColor(card),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${card.cost}E",
              style: const TextStyle(
                color: SpaceTheme.starYellow,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            S.of(context)!.arithmancerHand,
            style: SpaceTheme.titleStyle.copyWith(fontSize: 16),
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
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: _handCards.length,
                    itemBuilder: (context, index) {
                      final card = _handCards[index];
                      return _buildDraggableCard(card);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableCard(MathCard card) {
    return Draggable<MathCard>(
      data: card,
      feedback: Transform.scale(
        scale: 1.2,
        child: _buildCard(card, isBeingDragged: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildCard(card),
      ),
      child: _buildCard(card),
    );
  }

  Widget _buildCard(MathCard card, {bool isBeingDragged = false}) {
    return AnimatedBuilder(
      animation: _cardGlowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: _getCardGradient(card),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getCardBorderColor(card).withOpacity(
                isBeingDragged ? 1.0 : _cardGlowAnimation.value
              ),
              width: isBeingDragged ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getCardBorderColor(card).withOpacity(
                  isBeingDragged ? 0.8 : _cardGlowAnimation.value * 0.5
                ),
                blurRadius: isBeingDragged ? 20 : 10,
                spreadRadius: isBeingDragged ? 4 : 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                card.toString(),
                style: SpaceTheme.headlineStyle.copyWith(
                  fontSize: isBeingDragged ? 24 : 20,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: _getCardBorderColor(card),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${card.cost}E",
                  style: TextStyle(
                    color: SpaceTheme.starYellow,
                    fontSize: isBeingDragged ? 12 : 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
    _cardGlowController.dispose();
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