import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import '../../../core/services/sri_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../../../features/games/constants/app_constants.dart';

/// A dialog that displays detailed learning statistics from the SriService.
/// It provides parents with an at-a-glance overview of their child's progress.
class SriStatisticsDialog extends StatelessWidget {
  const SriStatisticsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final sriService = context.watch<SriService>();
    final s = S.of(context)!;

    // Fetch all base and detailed statistics from the service
    final total = sriService.totalTrackedProblems;
    final mastered = sriService.masteredProblemCount;
    final learning = sriService.learningProblemCount;
    final masteryPercent = total > 0 ? mastered / total : 0.0;
    final detailedData = sriService.getDetailedBreakdown();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235).withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SpaceTheme.nebulaPurple, width: 2),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("${s.sriStatisticsTitle} 🧠", style: SpaceTheme.headlineStyle),
                const SizedBox(height: 8),
                Text(s.sriStatisticsDesc, style: SpaceTheme.bodyStyle.copyWith(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 24),

                _buildMasteryMeter(context, masteryPercent),
                const SizedBox(height: 24),

                _buildSummarySection(context, total, mastered, learning),
                const Divider(color: SpaceTheme.nebulaPurple, height: 32),
                
                // NEW: The Progress Matrix Section
                _buildHeatmapSection(context, detailedData),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: SpaceTheme.primaryButtonStyle.copyWith(
                    backgroundColor: MaterialStateProperty.all(SpaceTheme.deepSpace),
                    side: MaterialStateProperty.all(const BorderSide(color: SpaceTheme.cosmicPink)),
                  ),
                  child: Text(s.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildMasteryMeter(BuildContext context, double percent) {
    return Column(
      children: [
        Text(S.of(context)!.sriMastery, style: SpaceTheme.titleStyle),
        const SizedBox(height: 12),
        SizedBox(
          width: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              LinearProgressIndicator(
                value: percent,
                minHeight: 20,
                backgroundColor: SpaceTheme.deepSpace,
                valueColor: const AlwaysStoppedAnimation<Color>(SpaceTheme.alienGreen),
                borderRadius: BorderRadius.circular(10),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: SpaceTheme.titleStyle.copyWith(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(BuildContext context, int total, int mastered, int learning) {
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(context, S.of(context)!.sriTotal, total.toString(), Icons.functions),
          const VerticalDivider(color: SpaceTheme.nebulaPurple, indent: 8, endIndent: 8),
          _buildStatItem(context, S.of(context)!.sriMastered, mastered.toString(), Icons.star),
          const VerticalDivider(color: SpaceTheme.nebulaPurple, indent: 8, endIndent: 8),
          _buildStatItem(context, S.of(context)!.sriLearning, learning.toString(), Icons.school),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, color: SpaceTheme.starYellow, size: 24),
          const SizedBox(height: 4),
          Text(value, style: SpaceTheme.headlineStyle.copyWith(fontSize: 20)),
          Text(label, style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, color: Colors.white70), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHeatmapSection(BuildContext context, Map<MathOperation, Map<NumberRange, OperationStat>> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.grid_view_sharp, color: SpaceTheme.cosmicPink, size: 20),
            const SizedBox(width: 8),
            Text("Progress Matrix", style: SpaceTheme.titleStyle.copyWith(fontSize: 18)), // TODO: Add to L10n
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Color shows mastery (green is best). Number shows problems tracked in that area.", // TODO: Add to L10n
          style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, color: Colors.white60)
        ),
        const SizedBox(height: 12),
        ProgressHeatmap(data: data),
      ],
    );
  }
}


/// A specialized widget that renders the progress data as a heatmap.
class ProgressHeatmap extends StatelessWidget {
  final Map<MathOperation, Map<NumberRange, OperationStat>> data;

  const ProgressHeatmap({super.key, required this.data});

  // NEW: A color function based on the average easiness factor.
  // The default E-Factor is 2.5. Correct answers increase it, incorrect answers decrease it.
  Color _getColorForEasiness(double easiness) {
    if (easiness >= 3.5) return SpaceTheme.alienGreen; // Consistently correct
    if (easiness > 2.5) return SpaceTheme.starYellow; // More right than wrong
    if (easiness > 0) return SpaceTheme.planetOrange; // More wrong than right
    return Colors.grey.shade800; // No data
  }
  
  Color _getColorForPercentage(double percent) {
    if (percent >= 0.8) return SpaceTheme.alienGreen;
    if (percent >= 0.5) return SpaceTheme.starYellow;
    if (percent > 0) return SpaceTheme.planetOrange;
    return Colors.grey.shade800;
  }
  
  IconData _getIconForOperation(MathOperation op) {
    switch (op) {
      case MathOperation.addition: return Icons.add;
      case MathOperation.subtraction: return Icons.remove;
      case MathOperation.multiplication: return Icons.close;
      case MathOperation.division: return Icons.percent; // Represents division/fractions
    }
  }

  @override
  Widget build(BuildContext context) {
    final numberRanges = NumberRange.values.toList();
    final operations = [
      MathOperation.addition, MathOperation.subtraction, 
      MathOperation.multiplication, MathOperation.division
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header Row: Renders the '1-10', '11-20', etc. labels
          Row(
            children: [
              const SizedBox(width: 40), // Spacer for operation icons
              ...numberRanges.map((range) => Expanded(
                child: Center(child: Text(getNumberRangeLabel(range), style: SpaceTheme.bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.bold))),
              )).toList(),
            ],
          ),
          const SizedBox(height: 8),

          // Data Rows: Renders each operation and its corresponding heatmap cells
          ...operations.map((op) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  // Operation Icon (Y-axis label)
                  SizedBox(width: 40, child: Icon(_getIconForOperation(op), color: Colors.white, size: 20)),
                  // Heatmap Cells
                  ...numberRanges.map((range) {
                    final stat = data[op]?[range] ?? OperationStat();
                    // MODIFIED: Use the new color function with the averageEasiness value
                    // A cell will only be grey if its `tracked` count is 0.
                    final color = stat.tracked > 0 
                        ? _getColorForEasiness(stat.averageEasiness) 
                        : Colors.grey.shade800;
                    
                    return Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withOpacity(0.5), width: 1)
                          ),
                          child: stat.tracked > 0
                            ? Center(
                                child: Text(
                                  stat.tracked.toString(),
                                  style: SpaceTheme.titleStyle.copyWith(
                                    fontSize: 14,
                                    color: color == SpaceTheme.starYellow ? Colors.black.withOpacity(0.7) : Colors.white,
                                    shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2)],
                                  ),
                                ),
                              )
                            : null,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}