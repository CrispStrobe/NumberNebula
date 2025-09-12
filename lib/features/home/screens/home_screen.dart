import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../../games/providers/game_provider.dart';
import '../../games/widgets/space_background.dart';
import '../widgets/animated_logo.dart';
import '../widgets/grade_selector.dart';
import '../widgets/stats_card.dart';
import '../../games/screens/game_menu_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
          ),
        ),
      ),
    );
  }
  
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Left side - Logo and welcome
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: const AnimatedLogo(),
              ),
              
              const SizedBox(height: 30),
              
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context)!.welcome,
                        style: SpaceTheme.headlineStyle.copyWith(fontSize: 36),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Text(
                        'Explore the universe of mathematics with fun space-themed games!',
                        style: SpaceTheme.bodyStyle.copyWith(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 40),
        
        // Right side - Controls and stats
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stats row
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Row(
                    children: [
                      Expanded(child: StatsCard()),
                      SizedBox(width: 20),
                      Expanded(child: AchievementsPreview()),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Grade selector
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const GradeSelector(),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Start button
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildStartButton(),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo
        FadeTransition(
          opacity: _fadeAnimation,
          child: const AnimatedLogo(),
        ),
        
        const SizedBox(height: 30),
        
        // Welcome text
        SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              S.of(context)!.welcome,
              style: SpaceTheme.headlineStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Stats
        SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: const StatsCard(),
          ),
        ),
        
        const SizedBox(height: 30),
        
        // Grade selector
        SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: const GradeSelector(),
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Start button
        SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildStartButton(),
          ),
        ),
        
        const Spacer(),
      ],
    );
  }
  
  Widget _buildStartButton() {
    return Container(
      width: 300,
      height: 80,
      decoration: BoxDecoration(
        gradient: SpaceTheme.starGradient,
        borderRadius: BorderRadius.circular(40),
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
          borderRadius: BorderRadius.circular(40),
          onTap: _navigateToGameMenu,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.rocket_launch,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 16),
              Text(
                S.of(context)!.startAdventure,
                style: SpaceTheme.buttonStyle.copyWith(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AchievementsPreview extends StatelessWidget {
  const AchievementsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final achievements = gameProvider.achievements.take(3).toList();
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: SpaceTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: SpaceTheme.starYellow,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    S.of(context)!.achievements,
                    style: SpaceTheme.titleStyle.copyWith(fontSize: 18),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              if (achievements.isEmpty)
                Text(
                  'Start playing to earn achievements!',
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 14),
                )
              else
                Column(
                  children: achievements.map((achievement) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            achievement.icon,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  achievement.title,
                                  style: SpaceTheme.bodyStyle.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  achievement.description,
                                  style: SpaceTheme.bodyStyle.copyWith(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
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