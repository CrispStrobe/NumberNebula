// lib/features/missions/screens/mission_streak_screen.dart
//
// Shows the task list for the active mission. Each task is a game to play.
// Completing a task reveals a letter. All letters → codeword puzzle.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../../games/providers/game_provider.dart';
import '../../games/widgets/space_background.dart';
import '../data/game_pool.dart';
import '../models/mission.dart';
import '../providers/mission_provider.dart';
import 'codeword_puzzle_screen.dart';

class MissionStreakScreen extends StatelessWidget {
  const MissionStreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final missionProvider = context.watch<MissionProvider>();
    final state = missionProvider.state;

    if (state == null) {
      return Scaffold(
        body: SpaceBackground(
          child: Center(child: Text(s.missionHubStart, style: SpaceTheme.bodyStyle)),
        ),
      );
    }

    final mission = state.mission;

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.missionStreakTitle,
                          style: SpaceTheme.titleStyle),
                    ),
                    // Progress badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: SpaceTheme.alienGreen),
                      ),
                      child: Text(
                        '${mission.completedCount} / ${mission.tasks.length}',
                        style: SpaceTheme.titleStyle.copyWith(
                          fontSize: 14,
                          color: SpaceTheme.alienGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Letter preview bar
              _buildLetterBar(context, state),

              // Task list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: mission.tasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskTile(context, index, state, missionProvider);
                  },
                ),
              ),

              // Solve codeword button (when all tasks done)
              if (mission.allTasksDone)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CodewordPuzzleScreen(
                          codeword: mission.codeword,
                          earnedLetters: state.earnedLetters,
                          grade: mission.grade,
                          level: mission.level,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.password, size: 24),
                    label: Text(s.missionSolveCodeword),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpaceTheme.starYellow,
                      foregroundColor: SpaceTheme.spaceBlue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      textStyle: SpaceTheme.buttonStyle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
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

  Widget _buildLetterBar(BuildContext context, MissionState state) {
    final mission = state.mission;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: SpaceTheme.starYellow.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(mission.tasks.length, (i) {
          final task = mission.tasks[i];
          final revealed = task.completed;

          return Container(
            width: 28,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: revealed
                  ? SpaceTheme.starYellow.withValues(alpha: 0.2)
                  : SpaceTheme.deepSpace.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: revealed
                    ? SpaceTheme.starYellow
                    : SpaceTheme.moonSilver.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                revealed ? task.letter : '?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: revealed
                      ? SpaceTheme.starYellow
                      : SpaceTheme.moonSilver.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTaskTile(BuildContext context, int index,
      MissionState state, MissionProvider provider) {
    final task = state.mission.tasks[index];
    final isNext = index == state.nextTaskIndex;
    final icon = gameIcons[task.gameType] ?? Icons.games;

    Color tileColor;
    Color borderColor;
    if (task.completed) {
      tileColor = SpaceTheme.alienGreen.withValues(alpha: 0.15);
      borderColor = SpaceTheme.alienGreen;
    } else if (isNext) {
      tileColor = SpaceTheme.starYellow.withValues(alpha: 0.15);
      borderColor = SpaceTheme.starYellow;
    } else {
      tileColor = SpaceTheme.deepSpace.withValues(alpha: 0.5);
      borderColor = SpaceTheme.moonSilver.withValues(alpha: 0.3);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isNext ? () => _launchTask(context, index, provider) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: isNext ? 2 : 1),
            ),
            child: Row(
              children: [
                // Task number
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.completed
                        ? SpaceTheme.alienGreen
                        : isNext
                            ? SpaceTheme.starYellow
                            : SpaceTheme.deepSpace,
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: task.completed
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isNext
                                  ? SpaceTheme.spaceBlue
                                  : SpaceTheme.moonSilver,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Game icon
                Icon(icon,
                    color: task.completed
                        ? SpaceTheme.alienGreen
                        : isNext
                            ? SpaceTheme.starYellow
                            : SpaceTheme.moonSilver,
                    size: 24),
                const SizedBox(width: 12),

                // Game name
                Expanded(
                  child: Text(
                    task.gameType.replaceAll('_', ' ').toUpperCase(),
                    style: SpaceTheme.bodyStyle.copyWith(
                      fontSize: 13,
                      color: task.completed
                          ? SpaceTheme.alienGreen
                          : isNext
                              ? Colors.white
                              : SpaceTheme.moonSilver,
                      fontWeight: isNext ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Earned letter
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: task.completed
                        ? SpaceTheme.starYellow.withValues(alpha: 0.2)
                        : Colors.transparent,
                    border: Border.all(
                      color: task.completed
                          ? SpaceTheme.starYellow
                          : SpaceTheme.moonSilver.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      task.completed ? task.letter : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: task.completed
                            ? SpaceTheme.starYellow
                            : SpaceTheme.moonSilver.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),

                // Play arrow for next task
                if (isNext) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.play_circle_fill,
                      color: SpaceTheme.starYellow, size: 28),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchTask(BuildContext context, int index,
      MissionProvider provider) async {
    final task = provider.state!.mission.tasks[index];
    final builder = gameBuilders[task.gameType];
    if (builder == null) return;

    // Launch the game
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => builder(task.grade, task.level)),
    );

    // After game pops, check if player won
    if (!context.mounted) return;
    final stars = context.read<GameProvider>().lastStars;
    if (stars > 0) {
      HapticFeedback.lightImpact();
      await provider.completeTask(index);
    }
  }
}
