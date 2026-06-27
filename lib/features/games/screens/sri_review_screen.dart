// lib/features/games/screens/sri_review_screen.dart
//
// User-facing view of the SRI (spaced repetition) state. Shows what's due
// for review, what's mastered, and the toughest items in the database.
// Read-only; players review by actually playing the games.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/sri_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';

class SriReviewScreen extends StatelessWidget {
  const SriReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sri = context.watch<SriService>();

    final due = sri.getAvailableReviewCount();
    final total = sri.totalTrackedProblems;
    final mastered = sri.masteredProblemCount;
    final learning = sri.learningProblemCount;
    final masteryPct = total > 0 ? (mastered / total * 100).round() : 0;

    final hardest = sri.getMostDifficultProblems(limit: 10);

    return Scaffold(
      backgroundColor: SpaceTheme.deepSpace,
      appBar: AppBar(
        title: Text(S.of(context)!.sriReviewTitle),
        backgroundColor: SpaceTheme.deepSpace,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Headline(due: due, total: total),
          const SizedBox(height: 24),
          _StatRow(
            children: [
              _StatTile(label: S.of(context)!.sriMasteredLabel, value: '$mastered'),
              _StatTile(label: S.of(context)!.sriLearningLabel, value: '$learning'),
              _StatTile(label: S.of(context)!.sriMasteryLabel, value: '$masteryPct%'),
            ],
          ),
          const SizedBox(height: 24),
          if (hardest.isNotEmpty) ...[
            Text(S.of(context)!.sriToughestProblems,
                style: SpaceTheme.titleStyle.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Card(
              color: SpaceTheme.nebulaPurple.withValues(alpha: 0.3),
              child: Column(
                children: [
                  for (final p in hardest)
                    ListTile(
                      title: Text(p.problemId,
                          style: const TextStyle(fontFamily: 'monospace')),
                      subtitle: Text(
                        'EF ${p.easinessFactor.toStringAsFixed(2)} · '
                        '${p.successCount}✓ ${p.failureCount}✗ · '
                        'next review ${_formatDate(p.nextReviewDate)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Play a few games to start tracking what you know.',
                textAlign: TextAlign.center,
                style: SpaceTheme.bodyStyle,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final delta = d.difference(now);
    if (delta.isNegative) return 'overdue';
    final days = delta.inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }
}

class _Headline extends StatelessWidget {
  final int due;
  final int total;
  const _Headline({required this.due, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SpaceTheme.nebulaPurple, SpaceTheme.spaceBlue],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book, size: 48, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == 0
                      ? 'No data yet'
                      : (due == 0 ? 'All caught up!' : '$due due for review'),
                  style: SpaceTheme.headlineStyle.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? 'Play a game to start tracking your progress.'
                      : (due == 0
                          ? 'Check back later for items to review.'
                          : 'Open any arithmetic game to drill these.'),
                  style: SpaceTheme.bodyStyle
                      .copyWith(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final List<Widget> children;
  const _StatRow({required this.children});

  @override
  Widget build(BuildContext context) =>
      Row(children: [for (final c in children) Expanded(child: c)]);
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SpaceTheme.deepSpace,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(value, style: SpaceTheme.titleStyle.copyWith(fontSize: 24)),
            const SizedBox(height: 4),
            Text(label,
                style: SpaceTheme.bodyStyle.copyWith(
                    fontSize: 12, color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}
