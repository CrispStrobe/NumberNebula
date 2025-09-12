import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../../games/providers/game_provider.dart';
import '../../games/widgets/space_background.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late AnimationController _sparkleController;
  late List<Animation<Offset>> _achievementAnimations;
  late Animation<double> _sparkleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _sparkleAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_sparkleController);
    
    _achievementAnimations = List.generate(10, (index) {
      return Tween<Offset>(
        begin: Offset(1.0 + (index * 0.1), 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval(
          index * 0.05,
          0.5 + (index * 0.05),
          curve: Curves.easeOutBack,
        ),
      ));
    });
    
    _slideController.forward();
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildStats(),
              Expanded(
                child: _buildAchievementsList(),
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
                  S.of(context)!.achievements,
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 32),
                ),
                Text(
                  'Space Explorer Progress',
                  style: SpaceTheme.bodyStyle.copyWith(
                    color: SpaceTheme.starYellow,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          AnimatedBuilder(
            animation: _sparkleAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _sparkleAnimation.value,
                child: const Icon(
                  Icons.emoji_events,
                  color: SpaceTheme.starYellow,
                  size: 40,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildStats() {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final totalAchievements = _getAllPossibleAchievements().length;
        final unlockedAchievements = gameProvider.totalAchievements;
        final completionPercentage = totalAchievements > 0 
            ? (unlockedAchievements / totalAchievements * 100).round()
            : 0;
        
        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: SpaceTheme.cardDecoration,
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.star,
                  label: 'Unlocked',
                  value: '$unlockedAchievements / $totalAchievements',
                  color: SpaceTheme.starYellow,
                ),
              ),
              
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              
              Expanded(
                child: _buildStatItem(
                  icon: Icons.percent,
                  label: 'Complete',
                  value: '$completionPercentage%',
                  color: SpaceTheme.alienGreen,
                ),
              ),
              
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              
              Expanded(
                child: _buildStatItem(
                  icon: Icons.trending_up,
                  label: 'Progress',
                  value: _getProgressLevel(unlockedAchievements),
                  color: SpaceTheme.cosmicPink,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: SpaceTheme.titleStyle.copyWith(
            color: color,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: SpaceTheme.bodyStyle.copyWith(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
  
  Widget _buildAchievementsList() {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final allAchievements = _getAllPossibleAchievements();
        final unlockedIds = gameProvider.achievements.map((a) => a.id).toSet();
        
        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getCrossAxisCount(context),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: allAchievements.length,
          itemBuilder: (context, index) {
            final achievement = allAchievements[index];
            final isUnlocked = unlockedIds.contains(achievement.id);
            
            return SlideTransition(
              position: _achievementAnimations[index % _achievementAnimations.length],
              child: AchievementCard(
                achievement: achievement,
                isUnlocked: isUnlocked,
                sparkleAnimation: _sparkleAnimation,
              ),
            );
          },
        );
      },
    );
  }
  
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    return 2;
  }
  
  String _getProgressLevel(int achievementCount) {
    if (achievementCount < 3) return 'Rookie';
    if (achievementCount < 6) return 'Explorer';
    if (achievementCount < 10) return 'Veteran';
    if (achievementCount < 15) return 'Expert';
    return 'Legend';
  }
  
  List<Achievement> _getAllPossibleAchievements() {
    return [
      Achievement(
        id: 'first_century',
        title: 'First Century!',
        description: 'Score 100 points',
        icon: '💯',
        isUnlocked: false,
      ),
      Achievement(
        id: 'score_master',
        title: 'Score Master',
        description: 'Score 500 points',
        icon: '⭐',
        isUnlocked: false,
      ),
      Achievement(
        id: 'thousand_club',
        title: 'Thousand Club',
        description: 'Score 1000 points',
        icon: '🚀',
        isUnlocked: false,
      ),
      Achievement(
        id: 'level_explorer',
        title: 'Level Explorer',
        description: 'Reach level 5',
        icon: '🌟',
        isUnlocked: false,
      ),
      Achievement(
        id: 'space_commander',
        title: 'Space Commander',
        description: 'Reach level 10',
        icon: '👨‍🚀',
        isUnlocked: false,
      ),
      Achievement(
        id: 'triangle_wizard',
        title: 'Triangle Wizard',
        description: 'Complete 3 Magic Triangle levels',
        icon: '🔺',
        isUnlocked: false,
      ),
      Achievement(
        id: 'bubble_popper',
        title: 'Bubble Popper',
        description: 'Complete 3 Bubble Math levels',
        icon: '🫧',
        isUnlocked: false,
      ),
      Achievement(
        id: 'puzzle_solver',
        title: 'Puzzle Solver',
        description: 'Complete 3 Puzzle Math levels',
        icon: '🧩',
        isUnlocked: false,
      ),
      Achievement(
        id: 'all_rounder',
        title: 'All-Rounder',
        description: 'Play all game types',
        icon: '🎯',
        isUnlocked: false,
      ),
      Achievement(
        id: 'speed_demon',
        title: 'Speed Demon',
        description: 'Complete a level in under 30 seconds',
        icon: '⚡',
        isUnlocked: false,
      ),
      Achievement(
        id: 'perfectionist',
        title: 'Perfectionist',
        description: 'Complete a level without mistakes',
        icon: '💎',
        isUnlocked: false,
      ),
      Achievement(
        id: 'mathematician',
        title: 'Young Mathematician',
        description: 'Solve 100 math problems',
        icon: '🧮',
        isUnlocked: false,
      ),
    ];
  }
}

class AchievementCard extends StatefulWidget {
  final Achievement achievement;
  final bool isUnlocked;
  final Animation<double> sparkleAnimation;
  
  const AchievementCard({
    super.key,
    required this.achievement,
    required this.isUnlocked,
    required this.sparkleAnimation,
  });

  @override
  State<AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<AchievementCard>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  
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
  }
  
  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: widget.isUnlocked ? _showAchievementDetails : null,
            onTapDown: (_) => _hoverController.forward(),
            onTapUp: (_) => _hoverController.reverse(),
            onTapCancel: () => _hoverController.reverse(),
            child: Container(
              decoration: BoxDecoration(
                gradient: widget.isUnlocked
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          SpaceTheme.starYellow,
                          SpaceTheme.planetOrange,
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          SpaceTheme.deepSpace.withOpacity(0.8),
                          SpaceTheme.nebulaPurple.withOpacity(0.6),
                        ],
                      ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: widget.isUnlocked
                    ? [
                        BoxShadow(
                          color: SpaceTheme.starYellow.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Stack(
                children: [
                  // Sparkle effect for unlocked achievements
                  if (widget.isUnlocked)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: widget.sparkleAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: SparklePainter(
                              animation: widget.sparkleAnimation.value,
                            ),
                          );
                        },
                      ),
                    ),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: widget.isUnlocked
                                ? Colors.white.withOpacity(0.2)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: Text(
                              widget.achievement.icon,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Title
                        Text(
                          widget.achievement.title,
                          style: SpaceTheme.titleStyle.copyWith(
                            fontSize: 16,
                            color: widget.isUnlocked ? Colors.white : Colors.white60,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Description
                        Text(
                          widget.achievement.description,
                          style: SpaceTheme.bodyStyle.copyWith(
                            fontSize: 12,
                            color: widget.isUnlocked ? Colors.white : Colors.white54,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const Spacer(),
                        
                        // Status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isUnlocked
                                ? SpaceTheme.alienGreen
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.isUnlocked ? 'UNLOCKED' : 'LOCKED',
                            style: TextStyle(
                              color: widget.isUnlocked ? Colors.white : Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Lock overlay for locked achievements
                  if (!widget.isUnlocked)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lock,
                            color: Colors.white60,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _showAchievementDetails() {
    showDialog(
      context: context,
      builder: (context) => AchievementDialog(
        achievement: widget.achievement,
      ),
    );
  }
}

class AchievementDialog extends StatelessWidget {
  final Achievement achievement;
  
  const AchievementDialog({
    super.key,
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SpaceTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: SpaceTheme.starGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  achievement.icon,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              achievement.title,
              style: SpaceTheme.headlineStyle.copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            Text(
              achievement.description,
              style: SpaceTheme.bodyStyle.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: SpaceTheme.alienGreen,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'ACHIEVEMENT UNLOCKED!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: SpaceTheme.primaryButtonStyle,
              child: const Text('Continue Exploring'),
            ),
          ],
        ),
      ),
    );
  }
}

class SparklePainter extends CustomPainter {
  final double animation;
  
  SparklePainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent sparkles
    
    for (int i = 0; i < 8; i++) {
      final angle = (i * 2 * math.pi / 8) + animation;
      final radius = 20 + math.sin(animation + i) * 10;
      
      final x = size.width / 2 + math.cos(angle) * radius;
      final y = size.height / 2 + math.sin(angle) * radius;
      
      canvas.drawCircle(
        Offset(x, y),
        2 + math.sin(animation * 2 + i) * 1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SparklePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}