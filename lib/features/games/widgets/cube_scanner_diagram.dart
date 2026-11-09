// lib/features/games/widgets/cube_scanner_diagram.dart
//
// Worked examples for the Cube Scanner onboarding.
//
// The game was held back because the board does not convey what it is asking.
// Two facts make the puzzle solvable and neither is visible on screen: that a
// die's opposite faces always sum to seven, and that the isometric view hides
// exactly the three faces opposite the ones you can see. Stated in a sentence
// they slide past; drawn once, the deduction becomes obvious.

import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';

/// One die face, drawn as pips rather than a digit.
///
/// Pips, because the board draws pips: a diagram that speaks a different
/// visual language than the thing it explains makes the reader translate
/// twice.
class DieFace extends StatelessWidget {
  final int value;
  final double size;
  final Color? color;
  final bool dimmed;

  const DieFace({
    super.key,
    required this.value,
    this.size = 44,
    this.color,
    this.dimmed = false,
  });

  /// Pip positions as fractions of the face, in reading order per value.
  static const _layouts = <int, List<Offset>>{
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.28, 0.28), Offset(0.72, 0.72)],
    3: [Offset(0.24, 0.24), Offset(0.5, 0.5), Offset(0.76, 0.76)],
    4: [Offset(0.28, 0.28), Offset(0.72, 0.28), Offset(0.28, 0.72), Offset(0.72, 0.72)],
    5: [Offset(0.26, 0.26), Offset(0.74, 0.26), Offset(0.5, 0.5),
        Offset(0.26, 0.74), Offset(0.74, 0.74)],
    6: [Offset(0.28, 0.22), Offset(0.28, 0.5), Offset(0.28, 0.78),
        Offset(0.72, 0.22), Offset(0.72, 0.5), Offset(0.72, 0.78)],
  };

  @override
  Widget build(BuildContext context) {
    final face = color ?? SpaceTheme.starYellow;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: dimmed ? 0.35 : 0.85),
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(
          color: face.withValues(alpha: dimmed ? 0.35 : 0.9),
          width: 1.5,
        ),
      ),
      child: CustomPaint(
        painter: _PipPainter(
          positions: _layouts[value] ?? const [],
          color: face.withValues(alpha: dimmed ? 0.4 : 1),
        ),
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  final List<Offset> positions;
  final Color color;

  _PipPainter({required this.positions, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = size.width * 0.085;
    for (final p in positions) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), r, paint);
    }
  }

  @override
  bool shouldRepaint(_PipPainter old) =>
      old.positions != positions || old.color != color;
}

/// The three opposite pairs, each shown adding to seven.
///
/// This is the whole rule of the game in one picture. Once a player has seen
/// that 1 sits opposite 6, they can read any hidden face off the one facing
/// them, which is the entire deduction the puzzle asks for.
class DieOppositePairsDiagram extends StatelessWidget {
  const DieOppositePairsDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final pair in const [[1, 6], [2, 5], [3, 4]])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DieFace(value: pair[0], size: 38),
                _glyph('+'),
                DieFace(value: pair[1], size: 38),
                _glyph('='),
                Text(
                  '7',
                  style: SpaceTheme.headlineStyle.copyWith(
                    fontSize: 22,
                    color: SpaceTheme.alienGreen,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _glyph(String s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          s,
          style: SpaceTheme.bodyStyle.copyWith(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
      );
}

/// What the scanner can see, and what it cannot.
///
/// Three faces are lit, three are faded behind them. Each faded face is
/// labelled with the subtraction that recovers it, so the player can see that
/// a hidden value is never a guess.
class DieHiddenFacesDiagram extends StatelessWidget {
  /// The three faces the scanner shows: top, left-front, right-front.
  final List<int> visible;

  /// Row captions, passed in already localized. They used to be the English
  /// literals "scanned" and "hidden" written straight into this file, which
  /// is exactly the kind of player-visible text that has no business living
  /// outside the ARB.
  final String scannedLabel;
  final String hiddenLabel;

  const DieHiddenFacesDiagram({
    super.key,
    required this.scannedLabel,
    required this.hiddenLabel,
    this.visible = const [2, 3, 1],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(
          label: scannedLabel,
          colour: SpaceTheme.alienGreen,
          faces: visible,
          dimmed: false,
        ),
        const SizedBox(height: 10),
        Icon(Icons.swap_vert,
            size: 18, color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(height: 10),
        _row(
          label: hiddenLabel,
          colour: SpaceTheme.rocketRed,
          faces: visible.map((v) => 7 - v).toList(),
          dimmed: true,
          captions: visible.map((v) => '7−$v').toList(),
        ),
      ],
    );
  }

  Widget _row({
    required String label,
    required Color colour,
    required List<int> faces,
    required bool dimmed,
    List<String>? captions,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: SpaceTheme.bodyStyle.copyWith(
            fontSize: 10,
            letterSpacing: 1.4,
            color: colour,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < faces.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DieFace(value: faces[i], size: 36, color: colour, dimmed: dimmed),
                    if (captions != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        captions[i],
                        style: SpaceTheme.bodyStyle.copyWith(
                          fontSize: 10,
                          color: colour.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Where 21 comes from: the three pairs of 7 laid end to end.
///
/// The multi-cube questions all rest on a cube carrying 21 pips altogether,
/// and two or three cubes carrying 42 or 63. Nothing on the board says so, and
/// it is not a fact a child is expected to already have -- but it falls
/// straight out of the pairs they have just been shown.
class DieTotalPipsDiagram extends StatelessWidget {
  const DieTotalPipsDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final v in const [1, 2, 3, 4, 5, 6])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: DieFace(value: v, size: 30),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '7 + 7 + 7 = 21',
          style: SpaceTheme.headlineStyle.copyWith(
            fontSize: 18,
            color: SpaceTheme.alienGreen,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final entry in const [[1, 21], [2, 42], [3, 63]])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SpaceTheme.starYellow.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry[0]} \u00d7 ',
                        style: SpaceTheme.bodyStyle.copyWith(
                          fontSize: 12,
                          color: SpaceTheme.starYellow,
                        ),
                      ),
                      const DieFace(value: 6, size: 16),
                      Text(
                        ' = ${entry[1]}',
                        style: SpaceTheme.bodyStyle.copyWith(
                          fontSize: 12,
                          color: SpaceTheme.starYellow,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
