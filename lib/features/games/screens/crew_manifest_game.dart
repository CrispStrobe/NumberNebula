import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../models/game_outcome.dart';
import '../providers/game_provider.dart';
import '../widgets/space_background.dart';
import '../widgets/game_ui.dart';
import '../constants/difficulty_manager.dart';
import '../services/crew_manifest_logic.dart';

class CrewManifestGame extends StatefulWidget {
  final int grade;
  final int level;
  const CrewManifestGame({super.key, required this.grade, required this.level});

  @override
  State<CrewManifestGame> createState() => _CrewManifestGameState();
}

class _CrewManifestGameState extends State<CrewManifestGame>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  CrewManifestPuzzle? puzzle;
  DifficultyConfig? currentDifficulty;
  bool _isGenerating = true;

  // User's current assignments: crewName -> itemName (or null)
  Map<String, String?> _userAssignment = {};
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation =
        CurvedAnimation(parent: _successController, curve: Curves.elasticOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gp = context.read<GameProvider>();
        currentDifficulty = DifficultyManager.getDifficulty(gp, widget.level);
        _generatePuzzle();
      }
    });
  }

  @override
  void dispose() {
    _glowController.stop();
    _successController.stop();
    _glowController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    if (currentDifficulty == null) return;

    setState(() {
      _isGenerating = true;
      _gameOver = false;
      _successController.reset();
    });

    final generated = CrewManifestLogic.generate({
      'grade': widget.grade,
      'level': widget.level,
      'difficulty': currentDifficulty!,
    });

    if (mounted) {
      setState(() {
        puzzle = generated;
        _userAssignment = {for (final name in generated.crewNames) name: null};
        _isGenerating = false;
      });
    }
  }

  void _assignItem(String crewName, String? itemName) {
    if (_gameOver) return;
    setState(() {
      // If this item is already assigned to someone else, clear that assignment
      if (itemName != null) {
        for (final key in _userAssignment.keys) {
          if (_userAssignment[key] == itemName && key != crewName) {
            _userAssignment[key] = null;
          }
        }
      }
      _userAssignment[crewName] = itemName;
    });
  }

  void _checkSolution() {
    if (puzzle == null || _gameOver) return;

    // Check all assigned
    if (_userAssignment.values.any((v) => v == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.crewManifestLoseDesc),
          backgroundColor: SpaceTheme.rocketRed,
        ),
      );
      return;
    }

    final userMap = _userAssignment.map((k, v) => MapEntry(k, v!));
    if (puzzle!.checkSolution(userMap)) {
      _handleWin();
    } else {
      _handleLoss();
    }
  }

  void _handleWin() {
    HapticFeedback.lightImpact();
    _gameOver = true;

    int baseScore = 100 * widget.grade;
    int levelBonus = widget.level * 25;
    int sizeBonus = puzzle!.size * 50;
    int totalScore = baseScore + levelBonus + sizeBonus;

    context.read<GameProvider>().reportOutcome(GameOutcome.win(
      gameType: 'crew_manifest',
      difficulty: widget.level,
      score: totalScore,
    ));

    _successController.forward(from: 0.0);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildWinDialog(totalScore),
      );
    }
  }

  void _handleLoss() {
    HapticFeedback.heavyImpact();

    context.read<GameProvider>().reportOutcome(GameOutcome.loss(
      gameType: 'crew_manifest',
      difficulty: widget.level,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context)!.crewManifestLoseDesc)),
          ],
        ),
        backgroundColor: SpaceTheme.rocketRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    if (puzzle == null || _isGenerating) {
      return Scaffold(
        body: SpaceBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(s.loadingAdventure, style: SpaceTheme.bodyStyle),
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
                title: s.crewManifestTitle,
                level: widget.level,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(child: _buildGameArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    final s = S.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          Text(
            s.crewManifestInstructions,
            style: SpaceTheme.bodyStyle.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Clues section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: SpaceTheme.cardDecoration.copyWith(
              border: Border.all(color: SpaceTheme.nebulaPurple, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb, color: SpaceTheme.starYellow, size: 18),
                    const SizedBox(width: 8),
                    Text('Clues:', style: SpaceTheme.titleStyle.copyWith(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                ...puzzle!.clues.map((clue) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('  ', style: TextStyle(color: SpaceTheme.starYellow)),
                          Expanded(
                            child: Text(
                              clue,
                              style: SpaceTheme.bodyStyle.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Assignment grid
          ...puzzle!.crewNames.map((crewName) => _buildCrewRow(crewName)),

          const SizedBox(height: 16),

          // Submit button
          if (!_gameOver)
            Center(
              child: ElevatedButton.icon(
                onPressed: _checkSolution,
                icon: const Icon(Icons.check),
                label: Text(s.backToMenu.contains('Menu') ? 'Submit' : 'OK'),
                style: SpaceTheme.primaryButtonStyle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCrewRow(String crewName) {
    final assignedItem = _userAssignment[crewName];
    final availableItems = puzzle!.itemNames.where((item) {
      // Show all items, but mark already-assigned ones
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SpaceTheme.deepSpace.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: assignedItem != null
                    ? SpaceTheme.alienGreen.withValues(alpha: 0.7)
                    : SpaceTheme.nebulaPurple.withValues(alpha: _glowAnimation.value),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Crew member name
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C9DB), Color(0xFF06FFA5)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    crewName,
                    style: SpaceTheme.titleStyle.copyWith(fontSize: 14, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
                const SizedBox(width: 8),
                // Item dropdown
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: assignedItem,
                      hint: Text(
                        '-- select --',
                        style: SpaceTheme.bodyStyle.copyWith(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                      dropdownColor: SpaceTheme.deepSpace,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('-- none --', style: TextStyle(color: Colors.white38)),
                        ),
                        ...availableItems.map((item) {
                          final isUsedElsewhere = _userAssignment.entries
                              .any((e) => e.key != crewName && e.value == item);
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(
                              item,
                              style: TextStyle(
                                color: isUsedElsewhere ? Colors.white24 : Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) => _assignItem(crewName, value),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWinDialog(int totalScore) {
    final s = S.of(context)!;
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: SpaceTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.assignment_turned_in, size: 64, color: SpaceTheme.starYellow),
                  const SizedBox(height: 16),
                  Text(s.crewManifestWinTitle,
                      style: SpaceTheme.headlineStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text(s.crewManifestWinDesc(totalScore),
                      style: SpaceTheme.bodyStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _generatePuzzle();
                        },
                        style: SpaceTheme.secondaryButtonStyle,
                        child: Text(s.playAgain),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        style: SpaceTheme.primaryButtonStyle,
                        child: Text(s.backToMenu),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
