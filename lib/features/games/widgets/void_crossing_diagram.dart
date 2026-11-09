// lib/features/games/widgets/void_crossing_diagram.dart
//
// Worked examples for the Void Crossing onboarding.
//
// The game was held back because the board does not convey its rules. The
// onboarding it already had was three lines of text, and the line carrying the
// actual rule ended "check the rules at the bottom" -- it pointed at the rule
// instead of showing it. The rule is what the whole puzzle turns on: two
// creatures left on a bank with nobody to watch them is a loss, and that is a
// statement about a *situation*, which is far easier to draw than to say.

import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';

/// One bank of the crossing, with whoever is standing on it.
class _Bank extends StatelessWidget {
  final List<String> occupants;
  final bool shuttleHere;
  final bool safe;

  const _Bank({
    required this.occupants,
    required this.shuttleHere,
    required this.safe,
  });

  @override
  Widget build(BuildContext context) {
    final edge = safe ? SpaceTheme.alienGreen : SpaceTheme.rocketRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: edge.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in occupants)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(e, style: const TextStyle(fontSize: 26)),
                ),
              if (shuttleHere)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text('🚀', style: TextStyle(fontSize: 22)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Icon(
            safe ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: edge,
          ),
        ],
      ),
    );
  }
}

/// The rule the game actually turns on, drawn as two situations.
///
/// Left: the shuttle has gone, and the two creatures that do not get on are
/// alone together. Right: the shuttle is still here, so the same two are fine.
/// Same creatures both times -- the only thing that changed is who is watching,
/// which is exactly the thing a player has to learn to track.
class VoidConflictDiagram extends StatelessWidget {
  /// The pair that cannot be left alone together.
  final String predator;
  final String prey;

  const VoidConflictDiagram({
    super.key,
    this.predator = '🦎',
    this.prey = '🐛',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _case(
          bank: _Bank(occupants: [predator, prey], shuttleHere: false, safe: false),
          caption: 'left alone',
          colour: SpaceTheme.rocketRed,
        ),
        const SizedBox(width: 18),
        _case(
          bank: _Bank(occupants: [predator, prey], shuttleHere: true, safe: true),
          caption: 'you are here',
          colour: SpaceTheme.alienGreen,
        ),
      ],
    );
  }

  Widget _case({
    required Widget bank,
    required String caption,
    required Color colour,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bank,
        const SizedBox(height: 6),
        Text(
          caption.toUpperCase(),
          style: SpaceTheme.bodyStyle.copyWith(
            fontSize: 9,
            letterSpacing: 1.2,
            color: colour,
          ),
        ),
      ],
    );
  }
}

/// How many the shuttle takes, and that it never crosses empty.
///
/// The second thing that is invisible on the board: the pilot goes along on
/// every trip, so "send two across" always means two creatures *plus* you --
/// and coming back, someone may have to ride with you.
class VoidShuttleDiagram extends StatelessWidget {
  final int capacity;

  const VoidShuttleDiagram({super.key, this.capacity = 2});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: SpaceTheme.deepSpace.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: SpaceTheme.starYellow.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚀', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              for (int i = 0; i < capacity; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(Icons.add,
                        size: 14, color: Colors.white.withValues(alpha: 0.35)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_forward,
                size: 14, color: SpaceTheme.alienGreen.withValues(alpha: 0.8)),
            const SizedBox(width: 10),
            Icon(Icons.arrow_back,
                size: 14, color: SpaceTheme.starYellow.withValues(alpha: 0.8)),
          ],
        ),
      ],
    );
  }
}
