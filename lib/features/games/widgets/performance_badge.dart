// lib/features/games/widgets/performance_badge.dart
//
// Shared visual language for the 0..1 performance ratio games report:
// green / yellow / orange / red, the same everywhere it appears.

import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/performance.dart';

/// Colour for a performance grade.
Color performanceColor(PerfGrade grade) {
  switch (grade) {
    case PerfGrade.excellent:
      return SpaceTheme.alienGreen;
    case PerfGrade.good:
      return SpaceTheme.starYellow;
    case PerfGrade.fair:
      return SpaceTheme.planetOrange;
    case PerfGrade.poor:
      return SpaceTheme.rocketRed;
  }
}

/// Localized one-word verdict for a performance grade.
String performanceLabel(S s, PerfGrade grade) {
  switch (grade) {
    case PerfGrade.excellent:
      return s.perfGradeExcellent;
    case PerfGrade.good:
      return s.perfGradeGood;
    case PerfGrade.fair:
      return s.perfGradeFair;
    case PerfGrade.poor:
      return s.perfGradePoor;
  }
}

/// Icon that reinforces the grade for players who can't rely on colour alone.
IconData performanceIcon(PerfGrade grade) {
  switch (grade) {
    case PerfGrade.excellent:
      return Icons.star_rounded;
    case PerfGrade.good:
      return Icons.thumb_up_alt_rounded;
    case PerfGrade.fair:
      return Icons.trending_flat_rounded;
    case PerfGrade.poor:
      return Icons.replay_rounded;
  }
}

/// Compact "87%" chip, coloured and iconed by grade.
class PerformanceBadge extends StatelessWidget {
  final double performance;
  final bool showLabel;
  final double fontSize;

  const PerformanceBadge({
    super.key,
    required this.performance,
    this.showLabel = false,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final grade = gradeForPerformance(performance);
    final color = performanceColor(grade);
    final percent = performancePercent(performance);

    return Semantics(
      label: '$percent% — ${performanceLabel(s, grade)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(performanceIcon(grade), color: color, size: fontSize + 3),
            const SizedBox(width: 4),
            Text(
              '$percent%',
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                performanceLabel(s, grade),
                style: TextStyle(
                  color: color,
                  fontSize: fontSize - 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thin bar showing the ratio, with tick marks at the grade thresholds so the
/// player can see how far they are from the next colour.
class PerformanceBar extends StatelessWidget {
  final double performance;
  final double height;

  const PerformanceBar({
    super.key,
    required this.performance,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final value = performance.clamp(0.0, 1.0);
    final color = performanceColor(gradeForPerformance(value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
              // Threshold ticks: the goal line the player is aiming for.
              for (final t in const [kPerfFair, kPerfGood, kPerfExcellent])
                Positioned(
                  left: width * t,
                  child: Container(
                    width: 1.5,
                    height: height,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The colour scale, spelled out. Shown once at the top of the mission list so
/// the grading is never a mystery.
class PerformanceLegend extends StatelessWidget {
  const PerformanceLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    Widget chip(PerfGrade grade, String range) {
      final color = performanceColor(grade);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            range,
            style: SpaceTheme.bodyStyle.copyWith(
              fontSize: 11,
              color: SpaceTheme.moonSilver,
            ),
          ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(
          s.perfLegendTitle,
          style: SpaceTheme.bodyStyle.copyWith(
            fontSize: 11,
            color: SpaceTheme.moonSilver,
          ),
        ),
        chip(PerfGrade.excellent, '≥85%'),
        chip(PerfGrade.good, '>70%'),
        chip(PerfGrade.fair, '>40%'),
        chip(PerfGrade.poor, '≤40%'),
      ],
    );
  }
}
