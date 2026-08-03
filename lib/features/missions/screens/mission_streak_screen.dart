// lib/features/missions/screens/mission_streak_screen.dart
//
// Shows the task list for the active mission. Each task is a game to play.
// Clearing a task reveals its letters; all letters → codeword puzzle.
//
// Every cleared task carries a grade (>=85% green, >70% yellow, >40% orange,
// below red) taken from how cleanly the game was actually played, so the list
// tells the player where they are strong and what is worth replaying.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/skill_category.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../../games/models/performance.dart';
import '../../games/providers/game_provider.dart';
import '../../games/widgets/performance_badge.dart';
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

              // How the grading works — stated once, up front.
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: PerformanceLegend(),
              ),

              // Task list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: mission.tasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskTile(context, index, state, missionProvider);
                  },
                ),
              ),

              // Mission summary + solve codeword button (when all tasks done)
              if (mission.allTasksDone) _buildSummary(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLetterBar(BuildContext context, MissionState state) {
    final mission = state.mission;

    // One tile per letter of the codeword, grouped visually by task so the
    // player can see which game hands out which letters.
    final entries = <(String letter, bool revealed)>[];
    for (final task in mission.tasks) {
      for (final letter in task.letters.split('')) {
        entries.add((letter, task.completed));
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: SpaceTheme.starYellow.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: entries.map((entry) {
          final revealed = entry.$2;
          return Container(
            width: 26,
            height: 34,
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
                revealed ? entry.$1 : '?',
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
        }).toList(),
      ),
    );
  }

  /// Localized name of the skill a game trains, used as the tile subtitle so
  /// the calculation/puzzle mix of a mission is visible at a glance.
  String _skillLabel(S s, String gameType) {
    switch (gameSkillMap[gameType]) {
      case SkillCategory.arithmetic:
        return s.skillArithmetic;
      case SkillCategory.spatial2d:
      case SkillCategory.spatial3d:
        return s.skillSpatial;
      case SkillCategory.logicDeduction:
        return s.skillLogic;
      case SkillCategory.patternRecognition:
        return s.skillPattern;
      case null:
        return s.skillLogic;
    }
  }

  Widget _buildTaskTile(BuildContext context, int index,
      MissionState state, MissionProvider provider) {
    final s = S.of(context)!;
    final task = state.mission.tasks[index];
    final isNext = index == state.nextTaskIndex;
    final icon = gameIcons[task.gameType] ?? Icons.games;

    final performance = task.bestPerformance;
    final grade = task.performanceGrade;

    // Colour comes from the grade once the task has been played; before that
    // it is simply "next up" or "waiting".
    final Color accent = grade != null
        ? performanceColor(grade)
        : isNext
            ? SpaceTheme.starYellow
            : SpaceTheme.moonSilver.withValues(alpha: 0.4);

    final tileColor = task.completed || grade != null
        ? accent.withValues(alpha: 0.12)
        : isNext
            ? SpaceTheme.starYellow.withValues(alpha: 0.12)
            : SpaceTheme.deepSpace.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // Any task can be started, and a cleared one can be replayed to
          // improve its grade — nothing is locked behind a perfect run.
          onTap: () => _launchTask(context, index, provider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: accent, width: isNext && !task.completed ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Task number / done marker
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.completed
                            ? accent
                            : isNext
                                ? SpaceTheme.starYellow
                                : SpaceTheme.deepSpace,
                        border: Border.all(color: accent),
                      ),
                      child: Center(
                        child: task.completed
                            ? const Icon(Icons.check,
                                color: SpaceTheme.deepSpace, size: 18)
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

                    Icon(icon, color: accent, size: 24),
                    const SizedBox(width: 12),

                    // Game name + what it trains
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gameTitleFor(s, task.gameType),
                            style: SpaceTheme.bodyStyle.copyWith(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight:
                                  isNext ? FontWeight.w700 : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_skillLabel(s, task.gameType)} · '
                            '${s.level} ${task.level}',
                            style: SpaceTheme.bodyStyle.copyWith(
                              fontSize: 11,
                              color: SpaceTheme.moonSilver,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Letters this task pays out
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: task.completed
                            ? SpaceTheme.starYellow.withValues(alpha: 0.2)
                            : Colors.transparent,
                        border: Border.all(
                          color: task.completed
                              ? SpaceTheme.starYellow
                              : SpaceTheme.moonSilver.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        task.completed
                            ? task.letters
                            : '?' * task.letters.length,
                        style: TextStyle(
                          fontSize: 15,
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                          color: task.completed
                              ? SpaceTheme.starYellow
                              : SpaceTheme.moonSilver.withValues(alpha: 0.35),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),
                    Icon(
                      task.completed
                          ? Icons.refresh_rounded
                          : Icons.play_circle_fill,
                      color: task.completed ? SpaceTheme.moonSilver : accent,
                      size: task.completed ? 22 : 28,
                    ),
                  ],
                ),

                // Result line: the grade, or an invitation to start.
                const SizedBox(height: 10),
                if (performance != null) ...[
                  Row(
                    children: [
                      PerformanceBadge(performance: performance, showLabel: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          task.completed
                              ? (grade == PerfGrade.excellent
                                  ? s.missionTaskAced
                                  : s.missionTaskImproveHint)
                              : s.missionTaskRetryHint,
                          style: SpaceTheme.bodyStyle.copyWith(
                            fontSize: 11,
                            color: SpaceTheme.moonSilver,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PerformanceBar(performance: performance),
                ] else
                  Text(
                    isNext ? s.missionTaskStart : s.missionTaskNotPlayed,
                    style: SpaceTheme.bodyStyle.copyWith(
                      fontSize: 11,
                      color: SpaceTheme.moonSilver,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, MissionState state) {
    final s = S.of(context)!;
    final mission = state.mission;
    final average = mission.averagePerformance;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: average != null
              ? performanceColor(gradeForPerformance(average))
              : SpaceTheme.starYellow,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (average != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s.missionOverallRating,
                  style: SpaceTheme.bodyStyle.copyWith(fontSize: 13),
                ),
                const SizedBox(width: 10),
                PerformanceBadge(
                  performance: average,
                  showLabel: true,
                  fontSize: 15,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              textStyle: SpaceTheme.buttonStyle,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchTask(BuildContext context, int index,
      MissionProvider provider) async {
    final task = provider.state!.mission.tasks[index];
    final builder = gameBuilders[task.gameType];
    if (builder == null) return;

    final gameProvider = context.read<GameProvider>();
    // Snapshot so we can tell a finished round from a player who backed out.
    final outcomesBefore = gameProvider.outcomeCount;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => builder(task.grade, task.level)),
    );

    if (!context.mounted) return;
    if (gameProvider.outcomeCount == outcomesBefore) return; // quit early

    final outcome = gameProvider.lastOutcome;
    if (outcome == null || outcome.gameType != task.gameType) return;

    if (outcome.wasSuccessful) {
      HapticFeedback.lightImpact();
    }
    await provider.recordTaskAttempt(
      index,
      cleared: outcome.wasSuccessful,
      performance: outcome.effectivePerformance,
    );
  }
}
