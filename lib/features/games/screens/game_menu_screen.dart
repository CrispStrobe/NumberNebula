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
import '../screens/planet_hopping_game.dart';
import '../widgets/debug_panel.dart';
import '../../settings/screens/settings_screen.dart';
import '../../achievements/screens/achievements_screen.dart';

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

  // Define the number of games
  static const int _gameCount = 6;
  
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
    _cardAnimations = List.generate(_gameCount, (index) {
      return Tween<Offset>(
        begin: const Offset(0, 1.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval(
          (index * 0.1).clamp(0.0, 1.0),
          (0.5 + (index * 0.1)).clamp(0.0, 1.0),
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

  void _showDebugPanel() {
    showDialog(
        context: context,
        builder: (context) => DebugPanel(
        onSettingsApplied: () {
            setState(() {});
        },
        ),
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToAchievements() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AchievementsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return ScaleTransition(
            scale: Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
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
              _buildHeader(),
              // FIX: Ensure the grid area is scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

          const SizedBox(width: 8),
          
          // Navigation buttons row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Achievements button
              IconButton(
                onPressed: _navigateToAchievements,
                icon: const Icon(Icons.emoji_events),
                color: SpaceTheme.starYellow,
                tooltip: S.of(context)!.achievements,
                style: IconButton.styleFrom(
                  backgroundColor: SpaceTheme.deepSpace.withOpacity(0.8),
                ),
              ),
              
              const SizedBox(width: 4),
              
              // Settings button
              IconButton(
                onPressed: _navigateToSettings,
                icon: const Icon(Icons.settings),
                color: SpaceTheme.moonSilver,
                tooltip: S.of(context)!.settings,
                style: IconButton.styleFrom(
                  backgroundColor: SpaceTheme.deepSpace.withOpacity(0.8),
                ),
              ),
              
              const SizedBox(width: 4),
              
              // DEBUG BUTTON
              IconButton(
                onPressed: _showDebugPanel,
                icon: const Icon(Icons.bug_report),
                color: SpaceTheme.moonSilver,
                tooltip: 'Debug Settings',
                style: IconButton.styleFrom(
                  backgroundColor: SpaceTheme.deepSpace.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildLandscapeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.1, // Adjusted for better fit
      ),
      itemCount: _gameCount,
      itemBuilder: (context, index) => _buildGameCard(index),
    );
  }

  // FIX: Use a 2-column GridView for portrait mode for a better look
  Widget _buildPortraitGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.9, // Taller cards for portrait
      ),
      itemCount: _gameCount,
      itemBuilder: (context, index) => _buildGameCard(index),
    );
  }
  
  Widget _buildGameCard(int index) {
    final gameProvider = context.read<GameProvider>();
    final games = [
      // Game 1
      GameInfo(
        title: S.of(context)!.magicTriangles,
        description: S.of(context)!.magicTrianglesDesc,
        icon: Icons.change_history,
        gradient: const LinearGradient(colors: [SpaceTheme.nebulaPurple, SpaceTheme.cosmicPink]),
        onTap: () => _navigateToGame(MagicTrianglesGame(grade: gameProvider.grade, level: gameProvider.level)),
      ),
      // Game 2
      GameInfo(
        title: S.of(context)!.bubbleMath,
        description: S.of(context)!.bubbleMathDesc,
        icon: Icons.bubble_chart,
        gradient: const LinearGradient(colors: [SpaceTheme.alienGreen, SpaceTheme.starYellow]),
        onTap: () => _navigateToGame(AsteroidMathGame(grade: gameProvider.grade, level: gameProvider.level)),
      ),
      // Game 3
      GameInfo(
        title: S.of(context)!.puzzleMath,
        description: S.of(context)!.puzzleMathDesc,
        icon: Icons.extension,
        gradient: const LinearGradient(colors: [SpaceTheme.planetOrange, SpaceTheme.rocketRed]),
        onTap: () => _navigateToGame(PuzzleMathGame(grade: gameProvider.grade, level: gameProvider.level)),
      ),
      // Game 4
      GameInfo(
        title: S.of(context)!.hyperdriveGates,
        description: S.of(context)!.hyperdriveGatesDesc,
        icon: Icons.rocket_launch,
        gradient: const LinearGradient(colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)]),
        onTap: () => _navigateToGame(HyperdriveGatesGame(grade: gameProvider.grade, level: gameProvider.level)),
      ),
      // Game 5
      GameInfo(
        title: S.of(context)!.planetHopping,
        description: S.of(context)!.planetHoppingDesc,
        icon: Icons.public,
        gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
        onTap: () => _navigateToGame(PlanetHoppingGame(grade: gameProvider.grade, level: gameProvider.level)),
      ),
      // Game 6 (Placeholder)
      GameInfo(
        title: "Galaxy Fractions", // Placeholder
        description: "Divide and conquer the galaxy by solving fraction problems!",
        icon: Icons.pie_chart,
        gradient: const LinearGradient(colors: [Colors.teal, Colors.cyan]),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Coming soon!", style: SpaceTheme.bodyStyle), backgroundColor: SpaceTheme.nebulaPurple),
        ),
      ),
    ];

    final game = games[index];
    
    // Ensure animation list is long enough
    if (index >= _cardAnimations.length) return const SizedBox.shrink();

    return SlideTransition(
      position: _cardAnimations[index],
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value * (index % 3 + 1) * 0.3),
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
              child: Container(
                // FIX: Removed fixed height to allow GridView to control size
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround, // Better spacing
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.game.icon, size: 28, color: Colors.white),
                      ),
                      Text(
                        widget.game.title,
                        style: SpaceTheme.headlineStyle.copyWith(fontSize: 16),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.game.description,
                        style: SpaceTheme.bodyStyle.copyWith(fontSize: 11),
                        textAlign: TextAlign.center,
                        maxLines: 3, // Allow more space for description
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow, color: Colors.white, size: 14),
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