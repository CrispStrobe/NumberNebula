// lib/features/games/screens/blocks_counter_game.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter_cube/flutter_cube.dart' as cube;

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../providers/game_provider.dart';
import '../widgets/game_ui.dart';
import '../widgets/space_background.dart';
import '../../../shared/utils/app_utilities.dart';

// =============================================================================
// VISUAL CONFIGURATION - Tweak these parameters to adjust 3D rendering
// =============================================================================
class _VisualConfig {
  // Camera settings
  static const double cameraZoom = 2.8;  // Reduced for better initial fit
  static const double cameraDistance = 6.0;  // Closer for better view
  static const double cameraHeight = 5.0;    // Lower for better angle
  
  // Cube appearance
  static const double cubeSize = 0.98;  // Slightly larger cubes
  static const double cubeSpacing = 1.0; // Space between cube centers
  
  // Lighting and colors - much brighter to avoid grey cubes
  static const double lightDistance = 12.0;
  static const double lightHeight = 10.0;
  static const double materialBrightness = 2.2; // Increased from 1.8
  static const double shadowBrightness = 0.95; // Much lighter shadows (was 0.85)
  
  // Animation
  static const int rotationDurationSeconds = 15;
  
  // Container - reduced height to fix overflow
  static const double containerHeight = 350.0;  // Reduced from 400
  static const double containerBorderRadius = 16.0;
  
  // More vivid, saturated cube colors
  static const List<Color> cubeColors = [
    Color(0xFF00E5FF), // Bright Cyan
    Color(0xFF76FF03), // Bright Lime Green  
    Color(0xFFFF6D00), // Bright Orange
    Color(0xFFE91E63), // Bright Pink
    Color(0xFF9C27B0), // Bright Purple
    Color(0xFFFFEB3B), // Bright Yellow
    Color(0xFF03DAC6), // Bright Teal
    Color(0xFFFF1744), // Bright Red
  ];
}

// --- FIX: Helper class to manually define Cube geometry for flutter_cube v0.1.1 ---
class _CubeGeometry {
  final List<cube.Vector3> vertices = [
    cube.Vector3(-0.5, -0.5, -0.5), cube.Vector3(0.5, -0.5, -0.5),
    cube.Vector3(0.5, 0.5, -0.5), cube.Vector3(-0.5, 0.5, -0.5),
    cube.Vector3(-0.5, -0.5, 0.5), cube.Vector3(0.5, -0.5, 0.5),
    cube.Vector3(0.5, 0.5, 0.5), cube.Vector3(-0.5, 0.5, 0.5),
  ];

  final List<cube.Polygon> indices = [
    // front
    cube.Polygon(0, 1, 2), cube.Polygon(0, 2, 3),
    // back
    cube.Polygon(5, 4, 7), cube.Polygon(5, 7, 6),
    // left
    cube.Polygon(4, 0, 3), cube.Polygon(4, 3, 7),
    // right
    cube.Polygon(1, 5, 6), cube.Polygon(1, 6, 2),
    // top
    cube.Polygon(3, 2, 6), cube.Polygon(3, 6, 7),
    // bottom
    cube.Polygon(4, 5, 1), cube.Polygon(4, 1, 0),
  ];
}
// --- END OF FIX ---

// Data Models
class BlockPosition3D {
  final int x, y, z;
  final bool isVisible;
  final Color color;

  BlockPosition3D({
    required this.x,
    required this.y,
    required this.z,
    required this.isVisible,
    required this.color,
  });

  @override
  String toString() => '($x,$y,$z)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockPosition3D &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          z == other.z;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ z.hashCode;
}

class BlockStructure {
  final List<BlockPosition3D> blocks;
  final int width, height, depth;

  BlockStructure({
    required this.blocks,
    required this.width,
    required this.height,
    required this.depth,
  });
}

class _PuzzleGenerator {
  final math.Random _random;
  Set<BlockPosition3D> _blocks = {};
  
  _PuzzleGenerator(this._random);
  
  List<BlockPosition3D> get neighbors => [
    BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: Colors.white),
    BlockPosition3D(x: -1, y: 0, z: 0, isVisible: false, color: Colors.white),
    BlockPosition3D(x: 0, y: 1, z: 0, isVisible: false, color: Colors.white),
    BlockPosition3D(x: 0, y: -1, z: 0, isVisible: false, color: Colors.white),
    BlockPosition3D(x: 0, y: 0, z: 1, isVisible: false, color: Colors.white),
    BlockPosition3D(x: 0, y: 0, z: -1, isVisible: false, color: Colors.white),
  ];
  
  bool _isConnected(BlockPosition3D newBlock) {
    if (_blocks.isEmpty) return true;
    
    for (final neighbor in neighbors) {
      final adjacentBlock = BlockPosition3D(
        x: newBlock.x + neighbor.x,
        y: newBlock.y + neighbor.y,
        z: newBlock.z + neighbor.z,
        isVisible: false,
        color: Colors.white,
      );
      if (_blocks.contains(adjacentBlock)) return true;
    }
    return false;
  }
  
  void _addConnectedBlock(BlockPosition3D base, BlockPosition3D direction, Color color) {
    final newBlock = BlockPosition3D(
      x: base.x + direction.x,
      y: base.y + direction.y,
      z: base.z + direction.z,
      isVisible: false,
      color: color,
    );
    
    if (!_blocks.contains(newBlock)) {
      _blocks.add(newBlock);
    }
  }
  
  List<BlockPosition3D> _generateVeryEasy() {
    _blocks.clear();
    final color = _getRandomColor();
    
    final patterns = ['simple_L', 'mini_stair', 'small_tower'];
    final pattern = patterns[_random.nextInt(patterns.length)];
    
    if (pattern == 'simple_L') {
      // Basic L-shape with height variation
      _blocks.addAll([
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 2, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 1, isVisible: false, color: color), // Corner tower
      ]);
      if (_random.nextBool()) {
        _blocks.add(BlockPosition3D(x: 2, y: 0, z: 1, isVisible: false, color: color)); // End tower
      }
    } else if (pattern == 'mini_stair') {
      // 3-step staircase with width
      _blocks.addAll([
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 0, isVisible: false, color: color), // Add width
        BlockPosition3D(x: 1, y: 1, z: 0, isVisible: false, color: color),
      ]);
    } else { // small_tower
      // Tower with cross base
      _blocks.addAll([
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 2, isVisible: false, color: color), // Tower
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: -1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: -1, z: 0, isVisible: false, color: color), // Cross base
      ]);
    }
    
    return _blocks.toList();
  }
  
  List<BlockPosition3D> _generateEasy() {
    _blocks.clear();
    final color = _getRandomColor();
    
    final patterns = ['stepped_L', 'corner_building', 'terraced_block'];
    final pattern = patterns[_random.nextInt(patterns.length)];
    
    if (pattern == 'stepped_L') {
      // L with strategic height variations for hiding
      _blocks.addAll([
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 2, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 2, isVisible: false, color: color), // Corner tower
        BlockPosition3D(x: 2, y: 0, z: 1, isVisible: false, color: color), // End pillar
        BlockPosition3D(x: 1, y: 0, z: 1, isVisible: false, color: color), // Hidden by corner tower
        BlockPosition3D(x: 0, y: 1, z: 1, isVisible: false, color: color), // Hidden by corner tower
      ]);
    } else if (pattern == 'corner_building') {
      // Building with corner tower
      _blocks.addAll([
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 1, z: 0, isVisible: false, color: color), // Base
        BlockPosition3D(x: 0, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 1, isVisible: false, color: color), // Second level
        BlockPosition3D(x: 0, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 3, isVisible: false, color: color), // Tower
        BlockPosition3D(x: 2, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 2, z: 0, isVisible: false, color: color), // Extensions
      ]);
    } else { // terraced_block
      // Terraced structure with overhangs
      _blocks.addAll([
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 1, z: 0, isVisible: false, color: color), // Base layer
        BlockPosition3D(x: 0, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 1, isVisible: false, color: color), // Second layer
        BlockPosition3D(x: 0, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 2, isVisible: false, color: color), // Overhang level
        BlockPosition3D(x: 1, y: 1, z: 1, isVisible: false, color: color), // Hidden under overhang
      ]);
    }
    
    return _blocks.toList();
  }
  
  List<BlockPosition3D> _generateMedium() {
    _blocks.clear();
    final color = _getRandomColor();
    
    final patterns = ['bridge_structure', 'nested_L', 'stepped_pyramid'];
    final pattern = patterns[_random.nextInt(patterns.length)];
    
    if (pattern == 'bridge_structure') {
      // Bridge with pillars creating hiding opportunities
      _blocks.addAll([
        // Left pillar
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 2, isVisible: false, color: color),
        // Right pillar
        BlockPosition3D(x: 4, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 4, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 4, y: 0, z: 2, isVisible: false, color: color),
        // Bridge deck
        BlockPosition3D(x: 1, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 0, z: 2, isVisible: false, color: color),
        // Support structure (creates hiding)
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 0, isVisible: false, color: color), // Center support
      ]);
    } else if (pattern == 'nested_L') {
      // Large L with smaller L on top creating complex hiding
      _blocks.addAll([
        // Base L
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 2, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 3, z: 0, isVisible: false, color: color),
        // Upper L (offset to create hiding)
        BlockPosition3D(x: 1, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 1, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 2, z: 1, isVisible: false, color: color),
        // Towers
        BlockPosition3D(x: 0, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 2, isVisible: false, color: color), // Corner tower
        BlockPosition3D(x: 3, y: 0, z: 1, isVisible: false, color: color), // End pillar
        // Hidden cubes
        BlockPosition3D(x: 1, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 1, z: 0, isVisible: false, color: color), // Hidden by upper level
      ]);
    } else { // stepped_pyramid
      // 3-level pyramid with strategic gaps for hiding
      _blocks.addAll([
        // Base level (3x3 with strategic placement)
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 2, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 2, z: 0, isVisible: false, color: color),
        // Second level (cross shape)
        BlockPosition3D(x: 1, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 1, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 1, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 2, z: 1, isVisible: false, color: color),
        // Top level
        BlockPosition3D(x: 1, y: 1, z: 2, isVisible: false, color: color),
      ]);
    }
    
    return _blocks.toList();
  }
  
  List<BlockPosition3D> _generateHard() {
    _blocks.clear();
    final color = _getRandomColor();
    
    final patterns = ['multi_level_complex', 'interlocked_towers', 'terraced_complex'];
    final pattern = patterns[_random.nextInt(patterns.length)];
    
    if (pattern == 'multi_level_complex') {
      // Multiple levels with maximum hiding complexity
      _blocks.addAll([
        // Base level (irregular)
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 2, z: 0, isVisible: false, color: color),
        // Second level (offset)
        BlockPosition3D(x: 1, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 1, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 1, isVisible: false, color: color),
        // Third level (creates overhangs)
        BlockPosition3D(x: 0, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 2, isVisible: false, color: color),
        // Fourth level (complex overhang)
        BlockPosition3D(x: 1, y: 0, z: 3, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 0, z: 2, isVisible: false, color: color),
        // Strategic hidden cubes
        BlockPosition3D(x: 2, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 2, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 1, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 1, z: 1, isVisible: false, color: color),
      ]);
    } else if (pattern == 'interlocked_towers') {
      // Multiple towers with connecting bridges
      _blocks.addAll([
        // Tower 1
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 0, z: 3, isVisible: false, color: color),
        // Tower 2
        BlockPosition3D(x: 3, y: 3, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 3, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 3, z: 2, isVisible: false, color: color),
        // Tower 3
        BlockPosition3D(x: 0, y: 3, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 3, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 3, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 3, z: 3, isVisible: false, color: color),
        // Connecting bridges
        BlockPosition3D(x: 1, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 1, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 2, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 2, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 3, z: 2, isVisible: false, color: color),
        // Base connections
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 2, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 1, z: 0, isVisible: false, color: color),
      ]);
    } else { // terraced_complex
      // Complex terraced structure with maximum strategic hiding
      _blocks.addAll([
        // Base level
        BlockPosition3D(x: 0, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 1, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 2, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 1, z: 0, isVisible: false, color: color), // Strategic placement
        // Level 1 terraces
        BlockPosition3D(x: 1, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 0, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 0, y: 1, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 1, z: 1, isVisible: false, color: color),
        // Level 2 overhangs
        BlockPosition3D(x: 0, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 1, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 2, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 0, z: 2, isVisible: false, color: color),
        // Level 3 complex overhang
        BlockPosition3D(x: 1, y: 0, z: 3, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 0, z: 3, isVisible: false, color: color),
        // Hidden cubes at multiple levels
        BlockPosition3D(x: 1, y: 2, z: 0, isVisible: false, color: color),
        BlockPosition3D(x: 2, y: 1, z: 1, isVisible: false, color: color),
        BlockPosition3D(x: 3, y: 1, z: 1, isVisible: false, color: color),
      ]);
    }
    
    return _blocks.toList();
  }
  
  Color _getRandomColor() {
    // Use the bright, visible colors from visual config
    return _VisualConfig.cubeColors[_random.nextInt(_VisualConfig.cubeColors.length)];
  }
}

class BlockCountingPuzzle {
  final BlockStructure blockStructure;
  final int correctAnswer;
  final List<int> answerChoices;
  final int difficulty;

  BlockCountingPuzzle({
    required this.blockStructure,
    required this.correctAnswer,
    required this.answerChoices,
    required this.difficulty,
  });

  static BlockCountingPuzzle generate(Map<String, int> args) {
    final grade = args['grade']!;
    final level = args['level']!;
    final random = math.Random();
    final generator = _PuzzleGenerator(random);

    // Determine difficulty based on grade and level
    String difficulty;
    if (grade <= 2) {
      difficulty = 'very_easy';
    } else if (grade <= 4 || level < 10) {
      difficulty = 'easy';  
    } else if (grade <= 6 || level < 20) {
      difficulty = 'medium';
    } else {
      difficulty = 'hard';
    }

    // Generate blocks based on difficulty
    List<BlockPosition3D> rawBlocks;
    switch (difficulty) {
      case 'very_easy':
        rawBlocks = generator._generateVeryEasy();
        break;
      case 'easy':
        rawBlocks = generator._generateEasy();
        break;
      case 'medium':
        rawBlocks = generator._generateMedium();
        break;
      default:
        rawBlocks = generator._generateHard();
    }

    // Normalize coordinates to start from 0,0,0
    if (rawBlocks.isNotEmpty) {
      final minX = rawBlocks.map((b) => b.x).reduce(math.min);
      final minY = rawBlocks.map((b) => b.y).reduce(math.min);
      final minZ = rawBlocks.map((b) => b.z).reduce(math.min);

      rawBlocks = rawBlocks.map((b) => BlockPosition3D(
        x: b.x - minX,
        y: b.y - minY,
        z: b.z - minZ,
        isVisible: false,
        color: b.color,
      )).toList();
    }

    // Calculate visibility for each block
    final blockSet = rawBlocks.map((b) => '${b.x},${b.y},${b.z}').toSet();
    final finalBlocks = rawBlocks.map((b) => BlockPosition3D(
      x: b.x,
      y: b.y,
      z: b.z,
      isVisible: _isBlockVisible(b.x, b.y, b.z, blockSet),
      color: b.color,
    )).toList();

    // Calculate dimensions
    final maxX = finalBlocks.isEmpty ? 0 : finalBlocks.map((b) => b.x).reduce(math.max);
    final maxY = finalBlocks.isEmpty ? 0 : finalBlocks.map((b) => b.y).reduce(math.max);
    final maxZ = finalBlocks.isEmpty ? 0 : finalBlocks.map((b) => b.z).reduce(math.max);

    final correctAnswer = finalBlocks.length;

    // Generate plausible wrong answers
    final choices = <int>{correctAnswer};
    final variance = math.max(2, correctAnswer ~/ 3);
    
    while (choices.length < 4) {
      int wrongAnswer;
      if (random.nextBool()) {
        wrongAnswer = correctAnswer + random.nextInt(variance) + 1;
      } else {
        wrongAnswer = math.max(1, correctAnswer - random.nextInt(variance) - 1);
      }
      choices.add(wrongAnswer);
    }

    return BlockCountingPuzzle(
      blockStructure: BlockStructure(
        blocks: finalBlocks,
        width: maxX + 1,
        height: maxY + 1,
        depth: maxZ + 1,
      ),
      correctAnswer: correctAnswer,
      answerChoices: choices.toList()..shuffle(),
      difficulty: ['very_easy', 'easy', 'medium', 'hard'].indexOf(difficulty),
    );
  }

  static bool _isBlockVisible(int x, int y, int z, Set<String> allBlocks) {
    // A block is visible if at least one face is exposed
    final neighbors = [
      '${x},${y + 1},${z}', // above
      '${x + 1},${y},${z}', // right
      '${x - 1},${y},${z}', // left
      '${x},${y},${z + 1}', // forward
      '${x},${y},${z - 1}', // back
      '${x},${y - 1},${z}', // below
    ];
    
    return neighbors.any((neighbor) => !allBlocks.contains(neighbor));
  }
}

class BlockCounterGame extends StatefulWidget {
  final int grade;
  final int level;

  const BlockCounterGame({
    super.key,
    required this.grade,
    required this.level,
  });

  @override
  State<BlockCounterGame> createState() => _BlockCounterGameState();
}

class _BlockCounterGameState extends State<BlockCounterGame> with TickerProviderStateMixin {
  late AnimationController _successController;
  late Animation<double> _successAnimation;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  BlockCountingPuzzle? currentPuzzle;
  int? userAnswer;
  List<int> answerChoices = [];
  
  bool _isGenerating = true;
  int _selectedAnswerIndex = -1;
  cube.Object? _sceneObject;
  cube.Scene? _scene; 
  Key _cubeKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
    
    _rotationController = AnimationController(
      duration: Duration(seconds: _VisualConfig.rotationDurationSeconds),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
    
    _generatePuzzle();
    _rotationController.repeat(); // Slow continuous rotation
  }

  @override
  void dispose() {
    _successController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _generatePuzzle() async {
    debugPrint("🧊 BlockCounterGame._generatePuzzle() - Starting puzzle generation");

    setState(() {
      _isGenerating = true;
      _cubeKey = UniqueKey(); // Force the Cube widget to rebuild
      _scene = null; // Reset the scene reference
      userAnswer = null; // Reset game state immediately
      _selectedAnswerIndex = -1;
      _successController.reset();
      debugPrint("🧊 State reset: _isGenerating = true, game state cleared");
    });

    try {
      debugPrint("🧊 Computing new puzzle with grade ${widget.grade}, level ${widget.level}");
      final puzzle = await compute(
        BlockCountingPuzzle.generate,
        {'grade': widget.grade, 'level': widget.level},
      );
      
      debugPrint("🧊 Puzzle computation completed: ${puzzle.correctAnswer} blocks");
      
      if (mounted) {
        debugPrint("🧊 Widget still mounted, updating state with new puzzle");
        // IMPORTANT: Create the new 3D object before the next setState
        _createSceneObject(puzzle.blockStructure);
        
        setState(() {
          currentPuzzle = puzzle;
          answerChoices = List.from(currentPuzzle!.answerChoices);
          _isGenerating = false;
          debugPrint("🧊 State updated: _isGenerating = false, new puzzle ready for display");
        });
      }
    } catch (e, stackTrace) {
      debugPrint("🧊 ❌ Error generating puzzle: $e\n$stackTrace");
      if (mounted) setState(() => _isGenerating = false);
    }
  }
  
  void _createSceneObject(BlockStructure blockStructure) {
    debugPrint("🧊 _createSceneObject() - Creating 3D scene for new puzzle");
    
    final scene = cube.Object(name: 'world');
    // final blockStructure = currentPuzzle!.blockStructure; // DELETE THIS OLD LINE
    final geometry = _CubeGeometry();

    debugPrint("🧊 Block structure: ${blockStructure.blocks.length} blocks, ${blockStructure.width}x${blockStructure.height}x${blockStructure.depth}");

    // Center the structure
    final centerX = blockStructure.width / 2.0;
    final centerY = blockStructure.height / 2.0; 
    final centerZ = blockStructure.depth / 2.0;

    int visibleBlockCount = 0;
    for (final blockData in blockStructure.blocks) {
      final bool isHidden = !blockData.isVisible;
      if (isHidden) continue;
      
      visibleBlockCount++;

      final cubeObject = cube.Object(
        position: cube.Vector3(
          (blockData.x - centerX + 0.5) * _VisualConfig.cubeSpacing,
          (blockData.z - centerZ + 0.5) * _VisualConfig.cubeSpacing, // z up in flutter_cube
          (blockData.y - centerY + 0.5) * _VisualConfig.cubeSpacing,
        ),
        scale: cube.Vector3(
          _VisualConfig.cubeSize, 
          _VisualConfig.cubeSize, 
          _VisualConfig.cubeSize
        ),
        lighting: true,
      );

      final material = cube.Material();
      
      // Use brighter, more visible colors
      final colorIndex = blockData.hashCode.abs() % _VisualConfig.cubeColors.length;
      final color = _VisualConfig.cubeColors[colorIndex];
      
      // Apply brightness multiplier for better visibility
      final brightColor = Color.fromRGBO(
        (color.red * _VisualConfig.materialBrightness).clamp(0, 255).toInt(),
        (color.green * _VisualConfig.materialBrightness).clamp(0, 255).toInt(),
        (color.blue * _VisualConfig.materialBrightness).clamp(0, 255).toInt(),
        1.0,
      );
      
      material.diffuse.setFrom(cube.Vector3(
        brightColor.red / 255.0,
        brightColor.green / 255.0,
        brightColor.blue / 255.0,
      ));
      
      cubeObject.mesh = cube.Mesh(
        vertices: geometry.vertices,
        indices: geometry.indices,
        material: material,
      );
      
      scene.add(cubeObject);
    }
    
    _sceneObject = scene;
    debugPrint("🧊 3D scene created: $visibleBlockCount visible cubes added to scene");
  }

  void _selectAnswer(int answerIndex) {
    if (userAnswer != null) {
      debugPrint("🧊 _selectAnswer() - Answer already selected, ignoring");
      return; // Prevent multiple selections
    }
    
    debugPrint("🧊 _selectAnswer($answerIndex) - Answer selected: ${answerChoices[answerIndex]}");
    
    setState(() {
      _selectedAnswerIndex = answerIndex;
      userAnswer = answerChoices[answerIndex];
    });
    _checkAnswer();
  }

  void _checkAnswer() {
    if (userAnswer == null) {
      debugPrint("🧊 _checkAnswer() - No answer to check");
      return;
    }
    
    final isCorrect = userAnswer == currentPuzzle!.correctAnswer;
    debugPrint("🧊 _checkAnswer() - User: $userAnswer, Correct: ${currentPuzzle!.correctAnswer}, Result: ${isCorrect ? 'CORRECT' : 'INCORRECT'}");
    
    if (isCorrect) {
      _handleSuccess();
    } else {
      _handleIncorrect();
    }
  }

  void _handleSuccess() {
    debugPrint("🧊 _handleSuccess() - Puzzle solved correctly!");
    
    int baseScore = 150 * widget.grade;
    int difficultyBonus = (currentPuzzle!.difficulty + 1) * 50;
    int totalScore = baseScore + difficultyBonus;
    
    debugPrint("🧊 Score calculation: base($baseScore) + difficulty($difficultyBonus) = $totalScore");
    
    context.read<GameProvider>().addScore(totalScore);
    _successController.forward(from: 0.0);
    
    debugPrint("🧊 Showing success dialog");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSuccessDialog(totalScore),
    );
  }

  void _handleIncorrect() {
    debugPrint("🧊 _handleIncorrect() - Wrong answer, showing feedback");
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context)!.blockCounterFail),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        debugPrint("🧊 Resetting answer selection after incorrect answer");
        setState(() {
          _selectedAnswerIndex = -1;
          userAnswer = null;
        });
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    if (_isGenerating || currentPuzzle == null) {
      return Scaffold(
        body: SpaceBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: SpaceTheme.starYellow),
                const SizedBox(height: 16),
                Text(
                  S.of(context)!.loadingAdventure,
                  style: SpaceTheme.bodyStyle,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameUI(
                title: S.of(context)!.blockCounterGameTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 650;
                    return isWide ? _buildWideLayout() : _buildTallLayout();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: _buildVisualizationArea()),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: _buildAnswerArea()),
        ],
      ),
    );
  }

  Widget _buildTallLayout() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(), // Prevents overscroll glow
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0), // Reduced top padding
        child: Column(
          children: [
            _buildVisualizationArea(),
            const SizedBox(height: 16), // Reduced spacing
            _buildAnswerArea(),
            const SizedBox(height: 24), // Bottom padding for safe area
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizationArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          S.of(context)!.blockCounterQuestion,
          style: SpaceTheme.titleStyle.copyWith(fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
              height: _VisualConfig.containerHeight,
              decoration: SpaceTheme.cardDecoration.copyWith(
                borderRadius: BorderRadius.circular(_VisualConfig.containerBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: SpaceTheme.starYellow.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_VisualConfig.containerBorderRadius),
                child: Container(
                  color: const Color(0xFF1A1A2E), // Dark blue background
                  child: AnimatedBuilder(
                  animation: _rotationAnimation,
                  // The builder now ONLY handles rotation updates
                  builder: (context, child) {
                    if (_sceneObject != null) {
                      // This correctly updates the rotation on every frame
                      _sceneObject?.rotation.y = _rotationAnimation.value;
                      _scene?.update();
                      return child!;
                    }
                    return child!;
                  },
                  // The Cube widget is now the static child, it only rebuilds when its key changes
                  child: cube.Cube(
                    key: _cubeKey,
                    onSceneCreated: (cube.Scene scene) {
                      // This callback now correctly runs only ONCE per puzzle
                      _scene = scene;
                      if (_sceneObject != null) {
                        scene.world.add(_sceneObject!);
                      }
                      
                      // One-time camera setup
                      scene.camera.zoom = _VisualConfig.cameraZoom;
                      scene.camera.position.setFrom(cube.Vector3(
                        _VisualConfig.cameraDistance, 
                        _VisualConfig.cameraHeight, 
                        _VisualConfig.cameraDistance
                      ));
                      
                      // One-time lighting setup
                      scene.light.position.setFrom(cube.Vector3(
                        _VisualConfig.lightDistance, 
                        _VisualConfig.lightHeight, 
                        _VisualConfig.lightDistance
                      ));
                    },
                  ),
                ),
              )),
        ),
      ],
    );
  }

  Widget _buildAnswerArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          S.of(context)!.blockCounterSelectAnswer,
          style: SpaceTheme.titleStyle.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: SpaceTheme.cardDecoration,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.0,
            ),
            itemCount: answerChoices.length,
            itemBuilder: (context, index) {
              final answer = answerChoices[index];
              final isSelected = _selectedAnswerIndex == index;
              final isCorrect = userAnswer != null && 
                               answer == currentPuzzle!.correctAnswer;
              final isWrong = userAnswer != null && isSelected && !isCorrect;
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: ElevatedButton(
                  onPressed: userAnswer == null ? () => _selectAnswer(index) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCorrect 
                        ? SpaceTheme.alienGreen 
                        : isWrong 
                            ? SpaceTheme.rocketRed 
                            : isSelected
                                ? SpaceTheme.spaceBlue
                                : SpaceTheme.deepSpace,
                    foregroundColor: Colors.white,
                    elevation: isSelected ? 8 : 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected 
                            ? SpaceTheme.starYellow 
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    answer.toString(),
                    style: SpaceTheme.headlineStyle.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (userAnswer != null) ...[
          const SizedBox(height: 16),
          Text(
            userAnswer == currentPuzzle!.correctAnswer
                ? '🎉 ${S.of(context)!.blockCounterWinTitle}'
                : '🤔 Try again!',
            style: SpaceTheme.titleStyle.copyWith(
              color: userAnswer == currentPuzzle!.correctAnswer
                  ? SpaceTheme.alienGreen
                  : SpaceTheme.rocketRed,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildSuccessDialog(int totalScore) {
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A3E).withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Colors.greenAccent, width: 2),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 30),
                const SizedBox(width: 10),
                Text(
                  S.of(context)!.blockCounterWinTitle, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ]
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context)!.blockCounterWinDesc(currentPuzzle!.correctAnswer),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  S.of(context)!.blockCounterBonusPoints(totalScore),
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text(
                  S.of(context)!.blockCounterNextPuzzle, 
                  style: const TextStyle(color: Colors.cyanAccent)
                ),
                onPressed: () {
                  debugPrint("🧊 Next puzzle button pressed");
                  Navigator.pop(context); // Close dialog
                  debugPrint("🧊 Dialog closed, generating new puzzle");
                  _generatePuzzle(); // Generate new puzzle directly
                },
              ),
              TextButton(
                child: Text(
                  S.of(context)!.blockCounterBackToMenu, 
                  style: const TextStyle(color: Colors.white)
                ),
                onPressed: () {
                  debugPrint("🧊 Back to menu button pressed");
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to menu
                  debugPrint("🧊 Returned to main menu");
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
}