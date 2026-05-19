// lib/features/games/screens/cognitive_profile_screen.dart
//
// Visual breakdown of the player's mastery across skill categories.
// Reads from CognitiveProfileService.snapshot — purely informational,
// no actions to take here. The player improves a row by playing the
// corresponding games.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/skill_category.dart';
import '../../../core/services/cognitive_profile_service.dart';
import '../../../core/theme/space_theme.dart';

class CognitiveProfileScreen extends StatelessWidget {
  const CognitiveProfileScreen({super.key});

  static const Map<SkillCategory, String> _labels = {
    SkillCategory.arithmetic: 'Arithmetic',
    SkillCategory.spatial2d: 'Spatial (2D)',
    SkillCategory.spatial3d: 'Spatial (3D)',
    SkillCategory.logicDeduction: 'Logic & Deduction',
    SkillCategory.patternRecognition: 'Pattern Recognition',
  };

  static const Map<SkillCategory, IconData> _icons = {
    SkillCategory.arithmetic: Icons.calculate,
    SkillCategory.spatial2d: Icons.grid_on,
    SkillCategory.spatial3d: Icons.view_in_ar,
    SkillCategory.logicDeduction: Icons.psychology,
    SkillCategory.patternRecognition: Icons.auto_awesome,
  };

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<CognitiveProfileService>();
    final snapshot = profile.snapshot;
    final totalAttempts = profile.totalAttempts;

    return Scaffold(
      backgroundColor: SpaceTheme.deepSpace,
      appBar: AppBar(
        title: const Text('Cognitive Profile'),
        backgroundColor: SpaceTheme.deepSpace,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (totalAttempts == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Play a few games to start building your profile.',
                  textAlign: TextAlign.center,
                  style: SpaceTheme.bodyStyle,
                ),
              ),
            )
          else ...[
            Text(
              '$totalAttempts attempts across ${snapshot.length} skill area${snapshot.length == 1 ? '' : 's'}',
              style: SpaceTheme.bodyStyle
                  .copyWith(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            for (final category in SkillCategory.values)
              _SkillCategoryCard(
                label: _labels[category] ?? category.name,
                icon: _icons[category] ?? Icons.help_outline,
                stats: snapshot[category],
              ),
          ],
        ],
      ),
    );
  }
}

class _SkillCategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Map<int, SkillStats>? stats;
  const _SkillCategoryCard({
    required this.label,
    required this.icon,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = stats != null && stats!.isNotEmpty;
    final attempts = !hasData
        ? 0
        : stats!.values.fold<int>(0, (sum, s) => sum + s.attempts);
    final successes = !hasData
        ? 0
        : stats!.values.fold<int>(0, (sum, s) => sum + s.successes);
    final ratio = attempts > 0 ? successes / attempts : 0.0;
    final difficulties = !hasData ? <int>[] : (stats!.keys.toList()..sort());

    return Card(
      color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: SpaceTheme.starYellow, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: SpaceTheme.titleStyle.copyWith(fontSize: 16)),
                ),
                if (hasData)
                  Text(
                    '${(ratio * 100).round()}%',
                    style: SpaceTheme.titleStyle.copyWith(
                      fontSize: 18,
                      color: _colorForRatio(ratio),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasData)
              Text('No data yet — play to see this fill in.',
                  style: SpaceTheme.bodyStyle
                      .copyWith(fontSize: 12, color: Colors.white54))
            else ...[
              LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                backgroundColor: Colors.white12,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_colorForRatio(ratio)),
                minHeight: 6,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in difficulties)
                    _DifficultyChip(
                      difficulty: d,
                      stats: stats![d]!,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _colorForRatio(double r) {
    if (r >= 0.7) return SpaceTheme.alienGreen;
    if (r >= 0.4) return SpaceTheme.starYellow;
    return SpaceTheme.rocketRed;
  }
}

class _DifficultyChip extends StatelessWidget {
  final int difficulty;
  final SkillStats stats;
  const _DifficultyChip({required this.difficulty, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        'L$difficulty: ${stats.successes}/${stats.attempts}',
        style: const TextStyle(fontSize: 11, color: Colors.white70),
      ),
    );
  }
}
