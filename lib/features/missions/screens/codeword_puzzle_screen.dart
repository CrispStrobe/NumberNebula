// lib/features/missions/screens/codeword_puzzle_screen.dart
//
// Codeword anagram puzzle: arrange earned letters to form the target word.
// Some letters are pre-placed (based on difficulty); the rest must be dragged.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../../games/widgets/space_background.dart';
import '../providers/mission_provider.dart';

class CodewordPuzzleScreen extends StatefulWidget {
  final String codeword;
  final List<String> earnedLetters;
  final int grade;
  final int level;

  const CodewordPuzzleScreen({
    super.key,
    required this.codeword,
    required this.earnedLetters,
    required this.grade,
    required this.level,
  });

  @override
  State<CodewordPuzzleScreen> createState() => _CodewordPuzzleScreenState();
}

class _CodewordPuzzleScreenState extends State<CodewordPuzzleScreen>
    with TickerProviderStateMixin {
  late AnimationController _successController;
  late Animation<double> _successAnimation;

  /// The player's current arrangement. null = empty slot.
  late List<String?> _slots;

  /// Which slot indices are pre-placed (locked).
  late Set<int> _prePlaced;

  /// Available letters that haven't been placed yet.
  late List<String> _available;

  bool _solved = false;

  @override
  void initState() {
    super.initState();

    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _successAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _initPuzzle();
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  void _initPuzzle() {
    final word = widget.codeword;
    final n = word.length;
    _slots = List.filled(n, null);
    _prePlaced = {};

    // Determine how many letters to pre-place.
    // Grade 1 level 1: ~50%, Grade 4 level 20: 0
    final maxPre = (n * 0.5).floor();
    final prePlacedCount = (maxPre -
            (widget.grade - 1) * 2 -
            (widget.level - 1) * maxPre / 19)
        .round()
        .clamp(0, maxPre);

    // Pick random positions to pre-place
    final indices = List.generate(n, (i) => i)..shuffle(Random());
    for (int i = 0; i < prePlacedCount; i++) {
      final idx = indices[i];
      _slots[idx] = word[idx];
      _prePlaced.add(idx);
    }

    // Build available letters pool (letters not pre-placed)
    _available = [];
    for (int i = 0; i < n; i++) {
      if (!_prePlaced.contains(i)) {
        _available.add(word[i]);
      }
    }
    _available.shuffle(Random());
  }

  void _placeLetterInSlot(int slotIndex, String letter) {
    if (_solved || _prePlaced.contains(slotIndex)) return;

    setState(() {
      // If slot already has a letter, return it to available
      if (_slots[slotIndex] != null) {
        _available.add(_slots[slotIndex]!);
      }
      _slots[slotIndex] = letter;
      _available.remove(letter);
    });

    _checkSolution();
  }

  void _removeFromSlot(int slotIndex) {
    if (_solved || _prePlaced.contains(slotIndex)) return;
    if (_slots[slotIndex] == null) return;

    setState(() {
      _available.add(_slots[slotIndex]!);
      _slots[slotIndex] = null;
    });
  }

  void _checkSolution() {
    final current = _slots.join();
    if (current == widget.codeword) {
      _solved = true;
      HapticFeedback.lightImpact();
      _successController.forward(from: 0.0);

      context.read<MissionProvider>().solveCodeword();

      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _showWinDialog();
      });
    }
  }

  void _showWinDialog() {
    final s = S.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: SpaceTheme.cardDecoration.copyWith(
            border: Border.all(color: SpaceTheme.starYellow, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.military_tech,
                  size: 64, color: SpaceTheme.starYellow),
              const SizedBox(height: 16),
              Text(s.missionComplete,
                  style: SpaceTheme.headlineStyle,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                s.missionCompleteDesc(widget.codeword),
                style: SpaceTheme.bodyStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                autofocus: true,
                onPressed: () {
                  // Pop dialog, codeword screen, streak screen → back to hub
                  Navigator.of(context).pop(); // dialog
                  Navigator.of(context).pop(); // codeword screen
                  Navigator.of(context).pop(); // streak screen
                },
                style: SpaceTheme.primaryButtonStyle,
                child: Text(s.backToMenu),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(s.missionCodewordTitle,
                        style: SpaceTheme.titleStyle),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Text(s.missionCodewordInstructions,
                  style: SpaceTheme.bodyStyle,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // Slots row
              _buildSlots(),

              const SizedBox(height: 32),

              // Available letters
              Text(s.missionAvailableLetters,
                  style: SpaceTheme.bodyStyle.copyWith(
                    fontSize: 13,
                    color: SpaceTheme.moonSilver,
                  )),
              const SizedBox(height: 12),
              _buildAvailableLetters(),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlots() {
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(widget.codeword.length, (i) {
              final letter = _slots[i];
              final isPrePlaced = _prePlaced.contains(i);
              final isCorrect =
                  _solved && letter == widget.codeword[i];

              return DragTarget<String>(
                onWillAcceptWithDetails: (details) =>
                    !_solved && !isPrePlaced && _slots[i] == null,
                onAcceptWithDetails: (details) =>
                    _placeLetterInSlot(i, details.data),
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;

                  return GestureDetector(
                    onTap: () => _removeFromSlot(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? SpaceTheme.alienGreen.withValues(alpha: 0.3)
                            : isPrePlaced
                                ? SpaceTheme.starYellow
                                    .withValues(alpha: 0.15)
                                : isHovering
                                    ? SpaceTheme.starYellow
                                        .withValues(alpha: 0.2)
                                    : SpaceTheme.deepSpace
                                        .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCorrect
                              ? SpaceTheme.alienGreen
                              : isPrePlaced
                                  ? SpaceTheme.starYellow
                                  : isHovering
                                      ? SpaceTheme.starYellow
                                      : letter != null
                                          ? SpaceTheme.moonSilver
                                          : SpaceTheme.moonSilver
                                              .withValues(alpha: 0.3),
                          width: isPrePlaced || isCorrect ? 2 : 1,
                        ),
                        boxShadow: isCorrect
                            ? [
                                BoxShadow(
                                  color: SpaceTheme.alienGreen
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: letter != null
                            ? Text(
                                letter,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isPrePlaced
                                      ? SpaceTheme.starYellow
                                      : isCorrect
                                          ? SpaceTheme.alienGreen
                                          : Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.add,
                                size: 18,
                                color: SpaceTheme.moonSilver
                                    .withValues(alpha: 0.4),
                              ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildAvailableLetters() {
    if (_available.isEmpty && !_solved) {
      return Text(
        S.of(context)!.missionAllPlaced,
        style: SpaceTheme.bodyStyle.copyWith(
          color: SpaceTheme.alienGreen,
          fontSize: 13,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: _available.map((letter) {
          return Draggable<String>(
            data: letter,
            feedback: Material(
              color: Colors.transparent,
              child: _letterTile(letter, isDragging: true),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _letterTile(letter),
            ),
            child: _letterTile(letter),
          );
        }).toList(),
      ),
    );
  }

  Widget _letterTile(String letter, {bool isDragging = false}) {
    return Container(
      width: 42,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            SpaceTheme.starYellow.withValues(alpha: isDragging ? 0.4 : 0.2),
            SpaceTheme.planetOrange.withValues(alpha: isDragging ? 0.3 : 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: SpaceTheme.starYellow,
          width: isDragging ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: SpaceTheme.starYellow.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: SpaceTheme.starYellow,
          ),
        ),
      ),
    );
  }
}
