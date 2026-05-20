import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';

class ArithmancerVictoryDialog extends StatelessWidget {
  final int score;
  final VoidCallback onNextChallenge;
  final VoidCallback onReturnToBridge;

  const ArithmancerVictoryDialog({
    super.key,
    required this.score,
    required this.onNextChallenge,
    required this.onReturnToBridge,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: SpaceTheme.alienGreen, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.military_tech, color: SpaceTheme.starYellow, size: 30),
          const SizedBox(width: 10),
          Text(
            S.of(context)!.arithmancerVictoryTitle,
            style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.alienGreen),
          ),
        ],
      ),
      content: Text(
        S.of(context)!.arithmancerVictoryDesc(score),
        style: SpaceTheme.bodyStyle,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onNextChallenge();
          },
          child: Text(
            S.of(context)!.arithmancerNextChallenge,
            style: const TextStyle(color: SpaceTheme.alienGreen),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onReturnToBridge();
          },
          child: Text(
            S.of(context)!.arithmancerReturnToBridge,
            style: const TextStyle(color: SpaceTheme.starYellow),
          ),
        ),
      ],
    );
  }
}

class ArithmancerLadderStepDialog extends StatelessWidget {
  final int ladderProgress;
  final int totalLadderSteps;
  final VoidCallback onContinue;

  const ArithmancerLadderStepDialog({
    super.key,
    required this.ladderProgress,
    required this.totalLadderSteps,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: SpaceTheme.starYellow, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.trending_up, color: SpaceTheme.starYellow, size: 30),
          const SizedBox(width: 10),
          Text(
            S.of(context)!.arithmancerLadderProgressTitle,
            style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.starYellow),
          ),
        ],
      ),
      content: Text(
        S.of(context)!.arithmancerLadderProgressDesc(ladderProgress + 1, totalLadderSteps),
        style: SpaceTheme.bodyStyle,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onContinue();
          },
          child: Text(
            S.of(context)!.arithmancerLadderContinue,
            style: const TextStyle(color: SpaceTheme.starYellow),
          ),
        ),
      ],
    );
  }
}

class ArithmancerLadderCompleteDialog extends StatelessWidget {
  final int score;
  final VoidCallback onReturnToBridge;

  const ArithmancerLadderCompleteDialog({
    super.key,
    required this.score,
    required this.onReturnToBridge,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: SpaceTheme.alienGreen, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.emoji_events, color: SpaceTheme.starYellow, size: 30),
          const SizedBox(width: 10),
          Text(
            S.of(context)!.arithmancerLadderChampionTitle,
            style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.alienGreen),
          ),
        ],
      ),
      content: Text(
        S.of(context)!.arithmancerLadderChampionDesc(score),
        style: SpaceTheme.bodyStyle,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onReturnToBridge();
          },
          child: Text(
            S.of(context)!.arithmancerReturnToBridge,
            style: const TextStyle(color: SpaceTheme.starYellow),
          ),
        ),
      ],
    );
  }
}

class ArithmancerDefeatDialog extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onReturnToBridge;

  const ArithmancerDefeatDialog({
    super.key,
    required this.onTryAgain,
    required this.onReturnToBridge,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SpaceTheme.deepSpace.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: SpaceTheme.rocketRed, width: 2),
      ),
      title: Row(
        children: [
          const Icon(Icons.warning, color: SpaceTheme.rocketRed, size: 30),
          const SizedBox(width: 10),
          Text(
            S.of(context)!.arithmancerDefeatTitle,
            style: SpaceTheme.headlineStyle.copyWith(color: SpaceTheme.rocketRed),
          ),
        ],
      ),
      content: Text(
        S.of(context)!.arithmancerDefeatDesc,
        style: SpaceTheme.bodyStyle,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onTryAgain();
          },
          child: Text(
            S.of(context)!.arithmancerTryAgain,
            style: const TextStyle(color: SpaceTheme.alienGreen),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onReturnToBridge();
          },
          child: Text(
            S.of(context)!.arithmancerReturnToBridge,
            style: const TextStyle(color: SpaceTheme.starYellow),
          ),
        ),
      ],
    );
  }
}
