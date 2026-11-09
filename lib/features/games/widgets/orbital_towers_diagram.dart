// lib/features/games/widgets/orbital_towers_diagram.dart
//
// Worked examples for the Orbital Towers onboarding. The rule that makes this
// puzzle click -- a taller tower hides every shorter one behind it -- is much
// easier to see once than to read three times, so these draw it.

import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';
import '../services/orbital_towers_logic.dart';

/// A side-on view of one row of towers, as the edge camera sees it.
///
/// [heights] are the towers left to right; the camera stands at the left and
/// counts a tower only when it is taller than everything in front of it. The
/// hidden ones are drawn faded with the tower that blocks them called out.
class TowerSightlineDiagram extends StatelessWidget {
  final List<int> heights;

  const TowerSightlineDiagram({super.key, this.heights = const [2, 1, 4, 3]});

  @override
  Widget build(BuildContext context) {
    final visible = OrbitalTowersPuzzle.visibilityAlongLine(heights);
    final visibleCount = visible.where((v) => v).length;
    final maxHeight = heights.reduce((a, b) => a > b ? a : b);
    const unit = 16.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The camera, and the number it reports back.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: SpaceTheme.starYellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$visibleCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.videocam,
                    color: SpaceTheme.starYellow, size: 20),
              ],
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 22),
            for (int i = 0; i < heights.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _tower(heights[i], visible[i], maxHeight, unit),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Legend, so the fading is not left to guesswork.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendSwatch(SpaceTheme.alienGreen, Icons.visibility),
            const SizedBox(width: 12),
            _legendSwatch(Colors.white24, Icons.visibility_off),
          ],
        ),
      ],
    );
  }

  Widget _tower(int height, bool isVisible, int maxHeight, double unit) {
    final color = isVisible ? SpaceTheme.alienGreen : Colors.white24;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(height: (maxHeight - height) * unit),
        Container(
          width: 26,
          height: height * unit,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isVisible ? 0.55 : 0.2),
            border: Border.all(color: color, width: 1.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            '$height',
            style: TextStyle(
              color: isVisible ? Colors.white : Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendSwatch(Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Icon(icon, color: color == Colors.white24 ? Colors.white38 : color, size: 14),
      ],
    );
  }
}

/// A small grid with one row and one column filled in, showing that each
/// height appears exactly once along both.
class TowerLatinSquareDiagram extends StatelessWidget {
  final int size;

  const TowerLatinSquareDiagram({super.key, this.size = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < size; r++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int c = 0; c < size; c++) _cell(r, c),
            ],
          ),
      ],
    );
  }

  Widget _cell(int r, int c) {
    // Fill the top row and the left column; leave the rest blank so the grid
    // reads as a puzzle in progress rather than a finished answer.
    final onFilledRow = r == 0;
    final onFilledCol = c == 0;
    final int? value = onFilledRow
        ? c + 1
        : onFilledCol
            ? (r + 1)
            : null;

    final highlighted = onFilledRow || onFilledCol;
    final color = highlighted ? SpaceTheme.alienGreen : Colors.white24;

    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlighted ? 0.25 : 0.08),
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          value?.toString() ?? '',
          style: TextStyle(
            color: highlighted ? Colors.white : Colors.white38,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
