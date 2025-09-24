import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/space_theme.dart';
import '../providers/game_provider.dart';

class GameUI extends StatelessWidget {
  final String title;
  final int level;
  final int? timeLeft;
  final VoidCallback onBack;
  final Widget? customTitleWidget; 
  
  const GameUI({
    super.key,
    required this.title,
    required this.level,
    this.timeLeft,
    required this.onBack,
    this.customTitleWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
        children: [
          // Back Button
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 28,
            ),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.8),
              padding: const EdgeInsets.all(12),
            ),
          ),
          
          const SizedBox(width: 20),
          
          // Title Area
          Expanded(
            // FIX: Conditionally display the custom widget or the default title.
            // This ensures backward compatibility with other games.
            child: customTitleWidget ?? Text(
              title,
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          
          // Game Stats
          Row(
            children: [
              // Level
              _buildStatItem(
                icon: Icons.emoji_events,
                label: 'Level',
                value: level.toString(),
                color: const Color(0xFFFFD700), // starYellow
              ),
              
              const SizedBox(width: 20),
              
              // Score
              Consumer<GameProvider>(
                builder: (context, gameProvider, child) {
                  return _buildStatItem(
                    icon: Icons.star,
                    label: 'Score',
                    value: gameProvider.score.toString(),
                    color: const Color(0xFF06FFA5), // alienGreen
                  );
                },
              ),
              
              // Time (if provided)
              if (timeLeft != null) ...[
                const SizedBox(width: 20),
                _buildStatItem(
                  icon: Icons.timer,
                  label: 'Time',
                  value: _formatTime(timeLeft!),
                  color: timeLeft! > 10 
                      ? const Color(0xFFFF69B4) // cosmicPink
                      : const Color(0xFFE63946), // rocketRed
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}