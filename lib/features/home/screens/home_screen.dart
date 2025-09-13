import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../../achievements/screens/achievements_screen.dart'; // Re-use AchievementUIData
import '../../games/providers/game_provider.dart';
import '../../games/widgets/space_background.dart';
import '../widgets/animated_logo.dart';
import '../widgets/grade_selector.dart';
import '../widgets/stats_card.dart';
import '../../games/screens/game_menu_screen.dart';
import '../../settings/screens/settings_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
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
                // Header with settings button
                _buildHeader(),
                Expanded(
                  child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
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
        // App title or logo space
        FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            S.of(context)!.appTitle,
            style: SpaceTheme.headlineStyle.copyWith(fontSize: 24),
          ),
        ),
        
        // Settings button
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
    return Row(
        children: [
        // LEFT SIDE - Now wrapped in a SingleChildScrollView
        Expanded(
            flex: 3,
            child: SingleChildScrollView( // FIX: Allows this column to scroll if content is too tall
            child: Padding( // Add padding here for better spacing
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                  const SizedBox(height: 20), // Add top spacing
                  FadeTransition(
                  opacity: _fadeAnimation,
                  child: const AnimatedLogo(),
                  ),
                  const SizedBox(height: 24),
                  SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                      children: [
                          Text(
                          S.of(context)!.welcome,
                          style: SpaceTheme.headlineStyle.copyWith(fontSize: 28),
                          textAlign: TextAlign.center,
                          ),
                      ],
                      ),
                  ),
                  ),
                  const SizedBox(height: 32),
                  SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: const CompactGradeSelector(),
                  ),
                  ),
                  const SizedBox(height: 32),
                  SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildStartButton(),
                  ),
                  ),
                  const SizedBox(height: 20), // Add bottom spacing
              ],
              ),
            ),
            ),
        ),
        
        const SizedBox(width: 20),
        
        // RIGHT SIDE - Stats (remains the same)
        Expanded(
            flex: 2,
            child: Column( // Keep this column centered
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
            ],
            ),
        ),
        ],
    );
  }


  Widget _buildPortraitLayout() {
    return Column(
        children: [
        // Top section
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

        // Spacer will push content apart and absorb any extra vertical space
        const Spacer(),

        // Middle section of cards
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

        // Another Spacer to ensure the button is pushed to the bottom
        const Spacer(),

        // Bottom Button - This will now be anchored towards the bottom of the screen
        SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildStartButton(),
            ),
        ),
        ],
    );
    }


  Widget _buildStartButton() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: SpaceTheme.starYellow.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(35),
          onTap: _navigateToGameMenu,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.rocket_launch,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Text(
                  S.of(context)!.startAdventure,
                  style: SpaceTheme.buttonStyle.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// COMPACT Stats Card - Smaller version
class CompactStatsCard extends StatelessWidget {
  const CompactStatsCard({super.key});

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics,
                    color: Color(0xFFFFD700), // starYellow
                    size: 20, // Smaller icon
                  ),
                  const SizedBox(width: 8),
                  Text(
                    S.of(context)!.progress,
                    style: const TextStyle(
                      fontSize: 16, // Smaller text
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12), // Less spacing
              
              // Horizontal stats row instead of column
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompactStatItem(
                    icon: Icons.star,
                    value: gameProvider.score.toString(),
                    color: const Color(0xFFFFD700), // starYellow
                  ),
                  _buildCompactStatItem(
                    icon: Icons.trending_up,
                    value: gameProvider.level.toString(),
                    color: const Color(0xFF06FFA5), // alienGreen
                  ),
                  _buildCompactStatItem(
                    icon: Icons.emoji_events,
                    value: gameProvider.totalAchievements.toString(),
                    color: const Color(0xFFFF6B35), // planetOrange
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
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: color,
            size: 16,
          ),
        ),
        
        const SizedBox(height: 4),
        
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
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
                children: [3, 4, 5, 6].map((grade) {
                  final isSelected = gameProvider.grade == grade;
                  
                  return GestureDetector(
                    onTap: () => gameProvider.setGrade(grade),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 40, // Smaller size
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
                          grade.toString(),
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


// REFACTOR: This widget now fetches its own localized text based on IDs.
class CompactAchievementsPreview extends StatelessWidget {
  const CompactAchievementsPreview({super.key});

  // Helper method to get localized data for an achievement ID
  AchievementUIData _getAchievementUIData(BuildContext context, String id) {
    final s = S.of(context)!;
    switch (id) {
      case 'first_century':
        return AchievementUIData(title: s.achievementFirstCenturyTitle, description: s.achievementFirstCenturyDesc, icon: '💯');
      case 'score_master':
        return AchievementUIData(title: s.achievementScoreMasterTitle, description: s.achievementScoreMasterDesc, icon: '⭐');
      // Add other cases here if you want to show different achievements
      default:
        return AchievementUIData(title: s.achievementFirstCenturyTitle, description: s.achievementFirstCenturyDesc, icon: '💯');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        // We get the simple Achievement objects (with just IDs)
        final achievements = gameProvider.achievements.take(2).toList(); 

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A2D3E),
                Color(0xFF1E2235),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
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
                    Icons.emoji_events,
                    color: SpaceTheme.starYellow,
                    size: 18, // Smaller icon
                  ),
                  const SizedBox(width: 6),
                  Text(
                    S.of(context)!.achievements,
                    style: SpaceTheme.titleStyle.copyWith(fontSize: 14), // Smaller text
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (achievements.isEmpty)
                Text(
                  S.of(context)!.playToUnlock,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 11), // Smaller text
                  textAlign: TextAlign.center,
                )
              else
                Column(
                  children: achievements.map((achievement) {
                    // Look up the localized text using the ID
                    final uiData = _getAchievementUIData(context, achievement.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4), // Minimal spacing
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            uiData.icon, // Use the looked-up icon
                            style: const TextStyle(fontSize: 14), // Smaller emoji
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              uiData.title, // Use the looked-up title
                              style: SpaceTheme.bodyStyle.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 10, // Much smaller text
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