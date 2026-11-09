// ignore_for_file: unused_element
import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../screens/arithmancer_duel_game.dart';
import 'space_background.dart';

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
