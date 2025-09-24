import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_math_academy/core/services/debug_provider.dart';

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../../achievements/screens/achievements_screen.dart';
import '../../games/providers/game_provider.dart';
import '../../games/widgets/space_background.dart';
import '../widgets/animated_logo.dart';
import '../widgets/grade_selector.dart';
import '../widgets/stats_card.dart';
import '../../games/screens/game_menu_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../games/widgets/debug_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();

  void _showDebugPanel(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => DebugPanel(),
    );
  }
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _debugTapCount = 0;
  Timer? _debugResetTimer;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _debugResetTimer?.cancel();
    super.dispose();
  }

  void _navigateToGameMenu() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GameMenuScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeader(),
                // A bit of spacing to ensure header doesn't touch the main content.
                const SizedBox(height: 16), 
                Expanded(
                  // FIX: The Center widget was removed.
                  // Expanded now directly constrains its child, forcing the
                  // landscape Row to fit the available width and preventing the overflow.
                  child: isLandscape
                      ? _buildLandscapeLayout()
                      : _buildPortraitLayout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        GestureDetector(
            onTap: () {
            _debugResetTimer?.cancel();

            setState(() {
                _debugTapCount++;
            });

            if (_debugTapCount >= 7) {
                context.read<DebugProvider>().enableDebugMenu();
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Debug Mode Enabled! 🕵️'),
                    backgroundColor: SpaceTheme.alienGreen,
                ),
                );
                setState(() {
                _debugTapCount = 0;
                });
            } else {
                _debugResetTimer = Timer(const Duration(seconds: 2), () {
                setState(() {
                    _debugTapCount = 0;
                });
                });
            }
            },
            child: FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
                S.of(context)!.appTitle,
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 24),
            ),
            ),
        ),
        
        IconButton(
            onPressed: _navigateToSettings,
            icon: const Icon(
            Icons.settings,
            color: Colors.white,
            size: 28,
            ),
            style: IconButton.styleFrom(
            backgroundColor: SpaceTheme.deepSpace.withOpacity(0.8),
            padding: const EdgeInsets.all(12),
            ),
        ),
        ],
    );
  }

  Widget _buildLandscapeLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 800 || screenHeight < 500;
    
    return Row(
      children: [
        // LEFT SIDE - Better flex distribution
        Expanded(
          flex: isSmallScreen ? 4 : 5, // More space on larger screens
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedLogo(size: isSmallScreen ? 80 : 180), // Larger logo on big screens
              ),
              // Show welcome text on larger screens
              if (!isSmallScreen) ...[
                const SizedBox(height: 24),
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      S.of(context)!.welcome,
                      style: SpaceTheme.headlineStyle.copyWith(fontSize: 28),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              SizedBox(height: isSmallScreen ? 8 : 32),
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const CompactGradeSelector(),
                ),
              ),
              SizedBox(height: isSmallScreen ? 8 : 32),
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildStartButton(isSmallScreen),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(width: isSmallScreen ? 6 : 32), // More spacing on larger screens
        
        // RIGHT SIDE - Adjust flex for larger screens
        Expanded(
          flex: isSmallScreen ? 3 : 4, // Better ratio for larger screens
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: CompactStatsCard(isSmallScreen: isSmallScreen),
                ),
              ),
              SizedBox(height: isSmallScreen ? 4 : 20), // More spacing on larger screens
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: CompactAchievementsPreview(isSmallScreen: isSmallScreen),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
        children: [
        FadeTransition(
            opacity: _fadeAnimation,
            child: const AnimatedLogo(),
        ),
        const SizedBox(height: 16),
        SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
                S.of(context)!.welcome,
                style: SpaceTheme.headlineStyle.copyWith(fontSize: 24),
                textAlign: TextAlign.center,
            ),
            ),
        ),

        const Spacer(),

        SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
            opacity: _fadeAnimation,
            child: const CompactStatsCard(),
            ),
        ),
        const SizedBox(height: 16),
        SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
            opacity: _fadeAnimation,
            child: const CompactAchievementsPreview(),
            ),
        ),
        const SizedBox(height: 16),
        SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
            opacity: _fadeAnimation,
            child: const CompactGradeSelector(),
            ),
        ),

        const Spacer(),

        SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildStartButton(false),
            ),
        ),
        ],
    );
    }

  Widget _buildStartButton(bool isSmallScreen) {
    return Container(
      // REMOVED: The fixed 'height' property which prevented the button from growing.
      constraints: BoxConstraints(
        maxWidth: isSmallScreen ? 180 : 300,
        minHeight: isSmallScreen ? 48 : 60, // Use minHeight to ensure a good minimum size.
      ),
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 30),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.starYellow.withOpacity(0.4),
            blurRadius: isSmallScreen ? 10 : 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 30),
          onTap: _navigateToGameMenu,
          child: Padding(
            // Added vertical padding to ensure the button looks good with one or two lines.
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12.0 : 24.0,
              vertical: isSmallScreen ? 8.0 : 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.rocket_launch,
                  color: Colors.white,
                  size: isSmallScreen ? 16 : 24,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Flexible(
                  child: Text(
                    S.of(context)!.startAdventure,
                    textAlign: TextAlign.center, // Center the text for a cleaner look.
                    style: SpaceTheme.buttonStyle.copyWith(
                        fontSize: isSmallScreen ? 12 : 16),
                    // REMOVED: maxLines and overflow properties to allow text wrapping.
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Updated AnimatedLogo with size parameter
class AnimatedLogo extends StatefulWidget {
  final double size;
  
  const AnimatedLogo({super.key, this.size = 150});

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD700),
                  Color(0xFFFF6B35),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.rocket_launch,
              color: Colors.white,
              size: widget.size * 0.4,
            ),
          ),
        );
      },
    );
  }
}

// Updated CompactStatsCard with responsive sizing
class CompactStatsCard extends StatelessWidget {
  final bool isSmallScreen;
  
  const CompactStatsCard({super.key, this.isSmallScreen = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Container(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 20), // More padding on large screens
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A2D3E),
                Color(0xFF1E2235),
              ],
            ),
            borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 16), // Larger radius on big screens
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics,
                    color: Color(0xFFFFD700),
                    size: isSmallScreen ? 12 : 20, // Larger icon on big screens
                  ),
                  SizedBox(width: isSmallScreen ? 4 : 8),
                  Text(
                    S.of(context)!.progress,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 16, // Larger text on big screens
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: isSmallScreen ? 4 : 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompactStatItem(
                    icon: Icons.star,
                    value: gameProvider.score.toString(),
                    color: const Color(0xFFFFD700),
                  ),
                  _buildCompactStatItem(
                    icon: Icons.trending_up,
                    value: gameProvider.level.toString(),
                    color: const Color(0xFF06FFA5),
                  ),
                  _buildCompactStatItem(
                    icon: Icons.emoji_events,
                    value: gameProvider.totalAchievements.toString(),
                    color: const Color(0xFFFF6B35),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildCompactStatItem({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isSmallScreen ? 20 : 32, // Larger containers on big screens
          height: isSmallScreen ? 20 : 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(isSmallScreen ? 4 : 6),
          ),
          child: Icon(
            icon,
            color: color,
            size: isSmallScreen ? 10 : 16, // Larger icons on big screens
          ),
        ),
        
        const SizedBox(height: 4),
        
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 14, // Larger text on big screens
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// Updated CompactAchievementsPreview with responsive sizing
class CompactAchievementsPreview extends StatelessWidget {
  final bool isSmallScreen;
  
  const CompactAchievementsPreview({super.key, this.isSmallScreen = false});

  AchievementUIData _getAchievementUIData(BuildContext context, String id) {
    final s = S.of(context)!;
    switch (id) {
      case 'first_century':
        return AchievementUIData(title: s.achievementFirstCenturyTitle, description: s.achievementFirstCenturyDesc, icon: '💯');
      case 'score_master':
        return AchievementUIData(title: s.achievementScoreMasterTitle, description: s.achievementScoreMasterDesc, icon: '⭐');
      default:
        return AchievementUIData(title: s.achievementFirstCenturyTitle, description: s.achievementFirstCenturyDesc, icon: '💯');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final achievements = gameProvider.achievements.take(2).toList(); 

        return Container(
          padding: EdgeInsets.all(isSmallScreen ? 6 : 8), // Reduced padding
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A2D3E),
                Color(0xFF1E2235),
              ],
            ),
            borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // FIX: Prevent taking extra space
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: SpaceTheme.starYellow,
                    size: isSmallScreen ? 10 : 14, // Smaller icon
                  ),
                  SizedBox(width: isSmallScreen ? 2 : 4), // Less spacing
                  Text(
                    S.of(context)!.achievements,
                    style: SpaceTheme.titleStyle.copyWith(
                      fontSize: isSmallScreen ? 8 : 12 // Smaller text
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 2 : 4), // Less spacing
              if (achievements.isEmpty)
                Text(
                  S.of(context)!.playToUnlock,
                  style: SpaceTheme.bodyStyle.copyWith(
                    fontSize: isSmallScreen ? 6 : 9 // Smaller text
                  ),
                  textAlign: TextAlign.center,
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min, // FIX: Prevent taking extra space
                  children: achievements.map((achievement) {
                    final uiData = _getAchievementUIData(context, achievement.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2), // Minimal spacing
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min, // FIX: Prevent taking extra space
                        children: [
                          Text(
                            uiData.icon,
                            style: TextStyle(fontSize: isSmallScreen ? 8 : 10), // Smaller emoji
                          ),
                          const SizedBox(width: 2), // Minimal spacing
                          Flexible( // Use Flexible instead of Expanded
                            child: Text(
                              uiData.title,
                              style: SpaceTheme.bodyStyle.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 6 : 8, // Smaller text
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AchievementUIData {
  final String title;
  final String description;
  final String icon;

  AchievementUIData({
    required this.title,
    required this.description,
    required this.icon,
  });
}

// COMPACT Grade Selector - Smaller version  
class CompactGradeSelector extends StatelessWidget {
  const CompactGradeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16), // Reduced padding
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A2D3E),
                Color(0xFF1E2235),
              ],
            ),
            borderRadius: BorderRadius.circular(15), // Smaller radius
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.school,
                    color: Color(0xFFFFD700), // starYellow
                    size: 20, // Smaller icon
                  ),
                  const SizedBox(width: 8),
                  Text(
                    S.of(context)!.gradeN(gameProvider.grade), // Use gradeN for localization
                    style: const TextStyle(
                      fontSize: 16, // Smaller text
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12), // Less spacing
              
              // Compact grade selector row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [1, 2, 3, 4].map((level) {
                  final isSelected = gameProvider.grade == level;
                  
                  return GestureDetector(
                    onTap: () => gameProvider.setGrade(level),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700), // starYellow
                                  Color(0xFFFF6B35), // planetOrange
                                ],
                              )
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF1A1A2E), // deepSpace
                                  Color(0xFF16213E), // nebulaPurple
                                ],
                              ),
                        borderRadius: BorderRadius.circular(10), // Smaller radius
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFD700) // starYellow
                              : const Color(0xFFC0C0C0).withOpacity(0.3), // moonSilver
                          width: 1, // Thinner border
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          level.toString(),
                          style: TextStyle(
                            fontSize: 18, // Smaller font
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}