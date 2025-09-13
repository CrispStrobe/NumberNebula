import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../screens/magic_triangles_game.dart';
import '../screens/asteroid_math_game.dart';
import '../screens/puzzle_math_game.dart';
import '../screens/hyperdrive_gates_game.dart';
import '../screens/planet_hopping_game.dart'; // New import

class GameMenuScreen extends StatefulWidget {
  const GameMenuScreen({super.key});

  @override
  State<GameMenuScreen> createState() => _GameMenuScreenState();
}

class _GameMenuScreenState extends State<GameMenuScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _floatController;
  late List<Animation<Offset>> _cardAnimations;
  late Animation<double> _floatAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _floatAnimation = Tween<double>(
      begin: -10.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));
    
    // Create staggered animations for each game card (now 5 games)
    _cardAnimations = List.generate(5, (index) {
      return Tween<Offset>(
        begin: Offset(0, 1.0 + (index * 0.2)),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval(
          index * 0.12,
          0.4 + (index * 0.12),
          curve: Curves.elasticOut,
        ),
      ));
    });
    
    _slideController.forward();
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    _floatController.dispose();
    super.dispose();
  }
  
  void _navigateToGame(Widget gameScreen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => gameScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return ScaleTransition(
            scale: Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and title
              _buildHeader(),
              
              // Game cards
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: isLandscape ? _buildLandscapeGrid() : _buildPortraitGrid(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E2235),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 28,
            ),
            style: IconButton.styleFrom(
              backgroundColor: SpaceTheme.deepSpace.withOpacity(0.8),
              padding: const EdgeInsets.all(12),
            ),
          ),
          
          const SizedBox(width: 20),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.gameMenu,
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 32),
                ),
                
                Consumer<GameProvider>(
                  builder: (context, gameProvider, child) {
                    return Text(
                      'Grade ${gameProvider.grade} • Level ${gameProvider.level}',
                      style: SpaceTheme.bodyStyle.copyWith(
                        color: SpaceTheme.starYellow,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Quick stats
          Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: SpaceTheme.deepSpace.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: SpaceTheme.starYellow, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      gameProvider.score.toString(),
                      style: SpaceTheme.titleStyle.copyWith(
                        color: SpaceTheme.starYellow,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildLandscapeGrid() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.9,
      children: [
        _buildGameCard(0),
        _buildGameCard(1),
        _buildGameCard(2),
        _buildGameCard(3),
        _buildGameCard(4),
      ],
    );
  }
  
  Widget _buildPortraitGrid() {
    return ListView(
      children: [
        _buildGameCard(0),
        const SizedBox(height: 16),
        _buildGameCard(1),
        const SizedBox(height: 16),
        _buildGameCard(2),
        const SizedBox(height: 16),
        _buildGameCard(3),
        const SizedBox(height: 16),
        _buildGameCard(4),
        const SizedBox(height: 20),
      ],
    );
  }
  
  Widget _buildGameCard(int index) {
    final games = [
      GameInfo(
        title: "Cosmic Triangles",
        description: "Master the magic of space triangles! Each side must equal the cosmic number.",
        icon: Icons.change_history,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SpaceTheme.nebulaPurple, SpaceTheme.cosmicPink],
        ),
        onTap: () {
          final gameProvider = context.read<GameProvider>();
          _navigateToGame(MagicTrianglesGame(
            grade: gameProvider.grade,
            level: gameProvider.level,
          ));
        },
      ),
      GameInfo(
        title: "Asteroid Math Hunter",
        description: "Blast asteroids in the correct order! Navigate the dangerous asteroid field.",
        icon: Icons.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SpaceTheme.alienGreen, SpaceTheme.starYellow],
        ),
        onTap: () {
          final gameProvider = context.read<GameProvider>();
          _navigateToGame(AsteroidMathGame(
            grade: gameProvider.grade,
            level: gameProvider.level,
          ));
        },
      ),
      GameInfo(
        title: "Constellation Puzzle",
        description: "Rebuild the space constellations! Drag, rotate, and solve math to restore the cosmic images.",
        icon: Icons.extension,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SpaceTheme.planetOrange, SpaceTheme.rocketRed],
        ),
        onTap: () {
          final gameProvider = context.read<GameProvider>();
          _navigateToGame(PuzzleMathGame(
            grade: gameProvider.grade,
            level: gameProvider.level,
          ));
        },
      ),
      GameInfo(
        title: "Hyperdrive Gates",
        description: "Navigate through space gates! Fly through correct answers and avoid the wrong ones.",
        icon: Icons.flight_takeoff,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
        ),
        onTap: () {
          final gameProvider = context.read<GameProvider>();
          _navigateToGame(HyperdriveGatesGame(
            grade: gameProvider.grade,
            level: gameProvider.level,
          ));
        },
      ),
      GameInfo( // NEW PLANET HOPPING GAME
        title: "Planet Hopping",
        description: "Jump between planets using gravity! Visit planets in the correct mathematical sequence.",
        icon: Icons.public,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)], // Blue-purple gradient
        ),
        onTap: () {
          final gameProvider = context.read<GameProvider>();
          _navigateToGame(PlanetHoppingGame(
            grade: gameProvider.grade,
            level: gameProvider.level,
          ));
        },
      ),
    ];
    
    final game = games[index];
    
    return SlideTransition(
      position: _cardAnimations[index],
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value * (index + 1) * 0.25),
            child: GameCard(game: game),
          );
        },
      ),
    );
  }
}

class GameInfo {
  final String title;
  final String description;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  
  GameInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });
}

class GameCard extends StatefulWidget {
  final GameInfo game;
  
  const GameCard({
    super.key,
    required this.game,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  
  bool _isHovered = false;
  
  @override
  void initState() {
    super.initState();
    
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    ));
  }
  
  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }
  
  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    
    if (isHovered) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) => _onHover(true),
            onExit: (_) => _onHover(false),
            child: GestureDetector(
              onTap: widget.game.onTap,
              onTapDown: (_) => _onHover(true),
              onTapUp: (_) => _onHover(false),
              onTapCancel: () => _onHover(false),
              child: Container(
                height: 180, // Slightly reduced for 5 games
                decoration: BoxDecoration(
                  gradient: widget.game.gradient,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: widget.game.gradient.colors.first.withOpacity(_glowAnimation.value),
                      blurRadius: 25,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: CustomPaint(
                          painter: StarPatternPainter(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon
                          Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              widget.game.icon,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          
                          // Title
                          Text(
                            widget.game.title,
                            style: SpaceTheme.headlineStyle.copyWith(fontSize: 16),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 6),
                          
                          // Description
                          Text(
                            widget.game.description,
                            style: SpaceTheme.bodyStyle.copyWith(fontSize: 11),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 10),
                          
                          // Play button
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Launch',
                                  style: SpaceTheme.buttonStyle.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class StarPatternPainter extends CustomPainter {
  final Color color;
  
  StarPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent pattern
    
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = random.nextDouble() * 3 + 1;
      
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(StarPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}