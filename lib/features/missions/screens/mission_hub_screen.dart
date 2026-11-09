// lib/features/missions/screens/mission_hub_screen.dart
//
// Entry point for missions: start a new mission or resume an active one.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../../games/providers/game_provider.dart';
import '../../games/widgets/space_background.dart';
import '../providers/mission_provider.dart';
import 'mission_streak_screen.dart';

class MissionHubScreen extends StatelessWidget {
  const MissionHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final missionProvider = context.watch<MissionProvider>();
    final hasActive = missionProvider.hasActiveMission;

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.missionHubTitle,
                      style: SpaceTheme.headlineStyle,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mission icon
                        Icon(
                          hasActive ? Icons.rocket_launch : Icons.explore,
                          size: 80,
                          color: SpaceTheme.starYellow,
                        ),
                        const SizedBox(height: 24),

                        Text(
                          hasActive
                              ? s.missionHubResume
                              : s.missionHubStart,
                          style: SpaceTheme.titleStyle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasActive
                              ? s.missionHubResumeDesc(
                                  missionProvider.state!.mission.completedCount,
                                  missionProvider.state!.mission.tasks.length,
                                )
                              : s.missionHubStartDesc,
                          style: SpaceTheme.bodyStyle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        if (hasActive) ...[
                          // Resume active mission
                          ElevatedButton.icon(
                            onPressed: () => _navigateToStreak(context),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(s.missionHubContinue),
                            style: SpaceTheme.primaryButtonStyle,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () =>
                                _confirmAbandon(context, missionProvider),
                            child: Text(
                              s.missionHubAbandon,
                              style: const TextStyle(
                                  color: SpaceTheme.rocketRed),
                            ),
                          ),
                        ] else ...[
                          // Start new mission
                          ElevatedButton.icon(
                            onPressed: () =>
                                _startNewMission(context, missionProvider),
                            icon: const Icon(Icons.rocket_launch),
                            label: Text(s.missionHubNewMission),
                            style: SpaceTheme.primaryButtonStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startNewMission(
      BuildContext context, MissionProvider provider) async {
    final gp = context.read<GameProvider>();
    final locale = Localizations.localeOf(context).languageCode;
    final grade = gp.effectiveGrade;
    // Fallback level for games the player has never opened.
    final level = gp.score > 0 ? ((gp.score / 500) + 1).clamp(1, 20).toInt() : 1;

    await provider.startMission(
      grade: grade,
      level: level,
      locale: locale,
      // Each task runs at the level the player has actually reached in that
      // game, so a mission never throws them at level 1 content they've long
      // outgrown — or level 12 content they've never seen.
      gameProgress: gp.gameProgress,
    );

    if (context.mounted) {
      _navigateToStreak(context);
    }
  }

  void _navigateToStreak(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MissionStreakScreen()),
    );
  }

  void _confirmAbandon(
      BuildContext context, MissionProvider provider) {
    final s = S.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: SpaceTheme.cardDecoration.copyWith(
            border: Border.all(color: SpaceTheme.rocketRed, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.missionHubAbandonConfirm,
                  style: SpaceTheme.titleStyle,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: SpaceTheme.secondaryButtonStyle,
                    child: Text(s.goBack),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await provider.abandonMission();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpaceTheme.rocketRed,
                    ),
                    child: Text(s.missionHubAbandon),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
