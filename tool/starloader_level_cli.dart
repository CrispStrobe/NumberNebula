// ignore_for_file: avoid_print, constant_identifier_names
// tool/starloader_level_cli.dart
//
// Terminal harness for the Cargo-Loader (Sokoban) level generator: generates
// levels and renders them with ANSI colours so a human can eyeball them.
//
// Usage:
//   dart run tool/starloader_level_cli.dart [--w=8] [--h=8] [--b=3] [--n=1]
//
// Lifted out of lib/ so the runtime library doesn't ship a CLI entry point or
// a terminal-only dart:io dependency (whose APIs throw on web).

import 'dart:io';

import 'package:space_math_academy/features/games/services/starloader_level_generator.dart';

void main(List<String> args) {
  // Default parameters
  int width = 8;
  int height = 8;
  int boxes = 3;
  int attempts = 1;

  // Simple arg parsing
  for (var arg in args) {
    if (arg.startsWith('--w=')) width = int.parse(arg.split('=')[1]);
    if (arg.startsWith('--h=')) height = int.parse(arg.split('=')[1]);
    if (arg.startsWith('--b=')) boxes = int.parse(arg.split('=')[1]);
    if (arg.startsWith('--n=')) attempts = int.parse(arg.split('=')[1]);
  }

  stdout.writeln('🔧 Generating $attempts Level(s) [${width}x$height, Boxes: $boxes]...\n');

  final generator = LevelGenerator(verbose: true);

  for (int i = 0; i < attempts; i++) {
    final level = generator.generateLevel(
      dimX: width,
      dimY: height,
      numBoxes: boxes,
      maxTries: 10, 
    );

    print('\n════════════════════════════════════');
    print('      LEVEL ${i + 1} GENERATED');
    print('════════════════════════════════════');
    print('Score (Complexity): ${level.optimalMoves}');
    print('Map Layout:');
    print(LevelVisualizer.render(level));
    print('════════════════════════════════════\n');
  }
}

/// Helper to render the level with ANSI colors for debugging
class LevelVisualizer {
  static const String ANSI_RESET = '\x1B[0m';
  static const String ANSI_WALL = '\x1B[48;5;235m\x1B[38;5;240m'; // Dark Grey
  static const String ANSI_FLOOR = '\x1B[48;5;250m'; // Light Grey
  static const String ANSI_TARGET = '\x1B[48;5;250m\x1B[31m'; // Red on Grey
  static const String ANSI_BOX = '\x1B[48;5;136m\x1B[38;5;0m'; // Brown
  static const String ANSI_BOX_OK = '\x1B[48;5;34m\x1B[38;5;0m'; // Green (Box on target)
  static const String ANSI_PLAYER = '\x1B[48;5;33m\x1B[38;5;255m'; // Blue

  static String render(GeneratedLevel level) {
    StringBuffer buffer = StringBuffer();
    
    // Top border
    buffer.writeln('   ${List.generate(level.roomState[0].length, (index) => '$index').join('')}');
    
    for (int x = 0; x < level.roomState.length; x++) {
      buffer.write('${x.toString().padRight(2)} '); // Row number
      for (int y = 0; y < level.roomState[x].length; y++) {
        int stateTile = level.roomState[x][y];
        int structTile = level.roomStructure[x][y];
        
        String char = ' ';
        String color = ANSI_RESET;

        if (stateTile == LevelGenerator.WALL) {
          char = '#';
          color = ANSI_WALL;
        } else if (stateTile == LevelGenerator.PLAYER) {
          char = '@'; // Player
          color = ANSI_PLAYER;
        } else if (stateTile == LevelGenerator.BOX) {
          char = '\$';
          // Check if it's on a target (even if state says BOX, structure checks truth)
          if (structTile == LevelGenerator.TARGET) {
             color = ANSI_BOX_OK;
          } else {
             color = ANSI_BOX;
          }
        } else if (stateTile == LevelGenerator.BOX_ON_TARGET) {
          char = '*';
          color = ANSI_BOX_OK;
        } else {
          // Empty Floor or Target
          if (structTile == LevelGenerator.TARGET) {
            char = '.';
            color = ANSI_TARGET;
          } else {
            char = ' ';
            color = ANSI_FLOOR;
          }
        }
        buffer.write('$color$char$ANSI_RESET');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
