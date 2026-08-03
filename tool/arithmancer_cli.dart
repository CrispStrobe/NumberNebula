// ignore_for_file: avoid_print
// tool/arithmancer_cli.dart
//
// Terminal front-end for the Arithmancer combat engine: play a duel on stdin,
// run AI-vs-AI tournaments, or watch continuous play.
//
// Usage:
//   dart run tool/arithmancer_cli.dart
//
// Lives here, not in lib/, so the app doesn't ship an entry point or a
// terminal-only dart:io dependency (whose APIs throw on web). It drives the
// engine through its public API only.

import 'dart:io';
import 'dart:math';

import 'package:space_math_academy/shared/utils/arithmancer.dart';

/// Prompts a human player for their move — the terminal implementation of
/// [PvPGame.humanTurnHandler].
List<MathResult> promptHumanTurn(ArithmancerGame game) {
  if (game.currentEnemy!.mathematicalShields.isNotEmpty) {
    print("Opponent Defenses: ${game.currentEnemy!.mathematicalShields}");
  }

  List<MathResult> allResults = game.generateAllPossibleResults();

  // FIX: Sort results by effectiveness to show the best options first.
  allResults.sort((a, b) {
    // Prioritize higher damage and block
    int scoreA = a.damage + a.block;
    int scoreB = b.damage + b.block;
    return scoreB.compareTo(scoreA); // Sort in descending order
  });

  if (allResults.isEmpty) {
    print("No valid plays available. You can only End Turn.");
  }

  print("\nAvailable Actions:");
  print("0: End Turn (Keep remaining energy for next turn)");

  for (int i = 0; i < allResults.length && i < 20; i++) {
    MathResult result = allResults[i];
    int cost = result.usedCards.fold(0, (sum, card) => sum + card.cost);
    String costStr = cost <= game.playerEnergy
        ? "Cost: $cost"
        : "Cost: $cost (TOO EXPENSIVE)";
    String effectStr = "";
    if (result.damage > 0) effectStr += "Damage: ${result.damage}";
    if (result.block > 0) {
      effectStr +=
          "${effectStr.isNotEmpty ? ', ' : ''}Block: ${result.block}";
    }
    if (effectStr.isEmpty) effectStr = "No effect";

    String hint = "";
    if (game.currentEnemy!.mathematicalShields.containsKey('fibonacci_only') && result.isFibonacci) {
      hint = " *Effective*";
    }
    if (game.currentEnemy!.mathematicalShields.containsKey('prime_shield') && result.isPrime) {
      hint = " *Effective*";
    }
    if (game.currentEnemy!.mathematicalShields.containsKey('square_immune') && result.isPerfectSquare) {
      hint = " *Effective*";
    }

    print(
        "${i + 1}: ${result.expression} = ${result.value} - $effectStr ($costStr)$hint");
  }

  while (true) {
    stdout.write("\nChoose action (0-${min(20, allResults.length)}): ");
    String? input = stdin.readLineSync();

    if (input == null) continue;

    int? choice = int.tryParse(input);
    if (choice == null ||
        choice < 0 ||
        choice > min(20, allResults.length)) {
      print(
          "Invalid choice. Please enter a number between 0 and ${min(20, allResults.length)}.");
      continue;
    }

    if (choice == 0) {
      return [];
    }

    MathResult selectedResult = allResults[choice - 1];
    int cost =
        selectedResult.usedCards.fold(0, (sum, card) => sum + card.cost);
    if (cost > game.playerEnergy) {
      print("Not enough energy for that action!");
      continue;
    }

    return [selectedResult];
  }
}


void _runContinuousHumanVsGame() {
  // The AI personality is just a placeholder, as its 'decideTurn' won't be called.
  AIPersonality humanPlaceholder = PrimeHunterAI();
  Random rng = Random();
  ArithmancerGame game = ArithmancerGame(humanPlaceholder, rng, verbose: true);

  print("\n⚔️ Starting continuous play as Human...");

  // The main game loop
  while (!game.gameOver) {
    if (!game.battleActive) {
      // Check for total victory before starting the next battle
      if (game.enemiesDefeated >= EnemyRoster.getMathematicalEnemies().length) {
        game.winGame();
        continue; // Let the loop terminate
      }
      game.startNewBattle();
    } else {
      // In an active battle, handle one full turn (human action + enemy action)
      _handlePveHumanTurn(game);
    }
  }
}

/// Handles the logic for a single turn in a Human vs. Enemy battle.
void _handlePveHumanTurn(ArithmancerGame game) {
  // --- 1. Generate and Display Actions (with deduplication) ---
  List<MathResult> allResults = game.generateAllPossibleResults();
  
  final Map<String, MathResult> uniqueResults = {};
  for (final result in allResults) {
    var key = result.expression;
    if (key.contains('+') || key.contains('*')) {
      final operator = key.contains('+') ? '+' : '*';
      var parts = key.split(' $operator ');
      parts.sort();
      key = parts.join(' $operator ');
    }
    if (!uniqueResults.containsKey(key)) {
      uniqueResults[key] = result;
    }
  }
  final List<MathResult> filteredResults = uniqueResults.values.toList();
  filteredResults.sort((a, b) => (b.damage + b.block).compareTo(a.damage + a.block));

  print("\nAvailable Actions:");
  print("0: End Turn (Keep remaining energy for next turn)");

  for (int i = 0; i < filteredResults.length && i < 20; i++) {
    MathResult result = filteredResults[i];
    int cost = result.usedCards.fold(0, (sum, card) => sum + card.cost);
    String costStr = cost <= game.playerEnergy ? "Cost: $cost" : "Cost: $cost (TOO EXPENSIVE)";
    
    String effectStr = "";
    if (result.damage > 0) effectStr += "Damage: ${result.damage}";
    if (result.block > 0) effectStr += "${effectStr.isNotEmpty ? ", " : ""}Block: ${result.block}";
    if (result.damageReduction > 0) {
      effectStr += "${effectStr.isNotEmpty ? ", " : ""}Dmg. Reduction: ${(result.damageReduction * 100).toStringAsFixed(0)}%";
    }
    if (effectStr.isEmpty) effectStr = "No effect";

    print("${i + 1}: ${result.expression} = ${result.value.toStringAsFixed(2)} - $effectStr ($costStr)");
  }

  // --- 2. Get Player's Choice ---
  MathResult? chosenResult;
  while (true) {
    stdout.write("\nChoose action (0-${min(20, filteredResults.length)}): ");
    String? input = stdin.readLineSync();
    int? choice = int.tryParse(input ?? "-1");

    if (choice == null || choice < 0 || choice > min(20, filteredResults.length)) {
      print("Invalid choice.");
      continue;
    }
    if (choice == 0) break;

    chosenResult = filteredResults[choice - 1];
    int cost = chosenResult.usedCards.fold(0, (sum, card) => sum + card.cost);
    if (cost > game.playerEnergy) {
      print("Not enough energy!");
      chosenResult = null;
      continue;
    }
    break;
  }

  // --- 3. Execute Turn based on Player's Choice ---
  bool playerActed = chosenResult != null;
  if (playerActed) {
    game.executeResult(chosenResult, playerName: "Player"); // This removes the used cards from the hand
  } else {
    game.log("Player passes the turn.");
  }

  if (game.currentEnemy!.health <= 0) {
    game.log("🏆 ${game.currentEnemy!.name} defeated!");
    game.enemiesDefeated++;
    game.battleActive = false;
    game.grantBattleReward();
    return;
  }

  // --- 4. Optional Discard Phase: disabled (kept for reference) ---

  // --- 5. Enemy's Turn ---
  game.currentEnemy!.takeTurn(game);
  if (game.playerHealth <= 0) {
    game.loseGame();
    return;
  }
  
  // --- 6. Prepare for Next Turn (with new "Keep and Refill" logic) ---
  if (playerActed) {
    // Player acted, so we refill their hand back to 7.
    final cardsToDraw = 7 - game.hand.length;
    if (cardsToDraw > 0) {
      game.log("Drawing $cardsToDraw cards...");
      game.drawCards(cardsToDraw);
    }
    // Then call startTurn to reset energy/block and advance the turn counter.
    game.startTurn();
  } else {
    // Player passed, so they keep their hand. Just reset resources.
    game.turn++;
    game.currentBlock = 0;
    game.playerEnergy = game.maxEnergy;
    game.log("\n--- Turn ${game.turn} | HP: ${game.playerHealth}/${game.maxHealth} | E: ${game.playerEnergy}/${game.maxEnergy} | Block: ${game.currentBlock} ---");
    game.log("Hand: ${game.hand.map((c) => c.toString()).join(', ')}");
    if (game.currentEnemy != null) {
      String intent = game.currentEnemy!.getIntent()['desc'] ?? '...';
      game.log("Target: ${game.currentEnemy!.name} (${game.currentEnemy!.health} HP) | Intent: $intent");
    }
  }
}

// === MAIN LAUNCHER ===

void main() {
  print("🧮 ARITHMANCER'S DUEL - Mathematical Combat");
  print("=" * 50);
  print("1. Prime Hunter AI vs Mathematical Enemies");
  print("2. Sequence Weaver AI vs Mathematical Enemies");
  print("3. Defensive Calculator AI vs Mathematical Enemies");
  print("4. Run AI Comparison Simulation");
  print("5. AI vs AI Battle (Single)");
  print("6. AI vs AI Tournament (Multiple)");
  print("7. Human vs AI Battle");
  print("8. Continuous AI vs Game Mode");
  print("9. Continuous Play (Human)");

  stdout.write("\nSelect mode (1-9): ");
  String? input = stdin.readLineSync();

  Random rng = Random();

  switch (input) {
    case "1":
      ArithmancerGame game = ArithmancerGame(PrimeHunterAI(), rng);
      while (!game.gameOver) {
        if (!game.battleActive) {
          game.startNewBattle();
        } else {
          game.endTurn();
        }
      }
      break;
    case "2":
      ArithmancerGame game = ArithmancerGame(SequenceWeaverAI(), rng);
      while (!game.gameOver) {
        if (!game.battleActive) {
          game.startNewBattle();
        } else {
          game.endTurn();
        }
      }
      break;
    case "3":
      ArithmancerGame game = ArithmancerGame(DefensiveMathAI(), rng);
      while (!game.gameOver) {
        if (!game.battleActive) {
          game.startNewBattle();
        } else {
          game.endTurn();
        }
      }
      break;
    case "4":
      stdout.write("Number of runs per AI (default 20): ");
      String? runsInput = stdin.readLineSync();
      int runs = int.tryParse(runsInput ?? "20") ?? 20;
      GameSimulation.runAIComparison(runs);
      break;
    case "5":
      _runSingleAiVsAi();
      break;
    case "6":
      _runAiVsAiTournament();
      break;
    case "7":
      _runHumanVsAi();
      break;
    case "8":
      _runContinuousAiVsGame();
      break;
    case "9":
      _runContinuousHumanVsGame();
      break;
    default:
      print("Invalid selection");
  }
}

void _runSingleAiVsAi() {
  List<AIPersonality> personalities = [
    PrimeHunterAI(),
    SequenceWeaverAI(),
    DefensiveMathAI()
  ];

  print("\nSelect Player 1 AI:");
  for (int i = 0; i < personalities.length; i++) {
    print("${i + 1}: ${personalities[i].name}");
  }

  stdout.write("Choose Player 1 (1-${personalities.length}): ");
  String? input1 = stdin.readLineSync();
  int? choice1 = int.tryParse(input1 ?? "1");
  if (choice1 == null || choice1 < 1 || choice1 > personalities.length) {
    choice1 = 1;
  }

  print("\nSelect Player 2 AI:");
  for (int i = 0; i < personalities.length; i++) {
    print("${i + 1}: ${personalities[i].name}");
  }

  stdout.write("Choose Player 2 (1-${personalities.length}): ");
  String? input2 = stdin.readLineSync();
  int? choice2 = int.tryParse(input2 ?? "2");
  if (choice2 == null || choice2 < 1 || choice2 > personalities.length) {
    choice2 = 2;
  }

  AIPersonality ai1 = personalities[choice1 - 1];
  AIPersonality ai2 = personalities[choice2 - 1];

  Random rng = Random();
  PvPGame battle = PvPGame(
    player1AI: ai1,
    player2AI: ai2,
    rng: rng,
    verbose: true,
    player1IsHuman: false,
    player2IsHuman: false,
  );
  battle.runGame();
}

void _runAiVsAiTournament() {
  List<AIPersonality> personalities = [
    PrimeHunterAI(),
    SequenceWeaverAI(),
    DefensiveMathAI()
  ];

  stdout.write("Number of battles per matchup (default 10): ");
  String? battlesInput = stdin.readLineSync();
  int numBattles = int.tryParse(battlesInput ?? "10") ?? 10;

  print("\n🥊 AI vs AI TOURNAMENT");
  print("Running $numBattles battles per matchup...");
  print("=" * 60);

  Map<String, Map<String, int>> results = {};
  for (AIPersonality ai1 in personalities) {
    results[ai1.name] = {};
    for (AIPersonality ai2 in personalities) {
      results[ai1.name]![ai2.name] = 0;
    }
  }

  Random masterRng = Random(42);

  for (int i = 0; i < personalities.length; i++) {
    for (int j = 0; j < personalities.length; j++) {
      if (i == j) continue;

      AIPersonality ai1 = personalities[i];
      AIPersonality ai2 = personalities[j];

      print("\n🎲 ${ai1.name} vs ${ai2.name} ($numBattles battles)");

      int ai1Wins = 0;
      for (int battle = 0; battle < numBattles; battle++) {
        Random battleRng = Random(masterRng.nextInt(1000000));
        PvPGame battleInstance = PvPGame(
          player1AI: ai1,
          player2AI: ai2,
          rng: battleRng,
          verbose: false,
        );
        String winner = battleInstance.runGame();

        if (winner == ai1.name) {
          ai1Wins++;
        }
      }

      results[ai1.name]![ai2.name] = ai1Wins;
      int ai2Wins = numBattles - ai1Wins;

      print(
          "  ${ai1.name}: $ai1Wins wins (${(ai1Wins / numBattles * 100).toStringAsFixed(1)}%)");
      print(
          "  ${ai2.name}: $ai2Wins wins (${(ai2Wins / numBattles * 100).toStringAsFixed(1)}%)");
    }
  }

  print("\n📊 TOURNAMENT RESULTS SUMMARY");
  for (AIPersonality ai in personalities) {
    int totalWins = 0;
    int totalBattles = 0;
    for (AIPersonality opponent in personalities) {
      if (ai.name != opponent.name) {
        totalWins += results[ai.name]![opponent.name]!;
        totalBattles += numBattles;
      }
    }
    double winRate = (totalWins / totalBattles) * 100;
    print("${ai.name}: ${winRate.toStringAsFixed(1)}% overall win rate");
  }
}

void _runHumanVsAi() {
  List<AIPersonality> personalities = [PrimeHunterAI(), SequenceWeaverAI(), DefensiveMathAI()];
  
  print("\nSelect AI Opponent:");
  for (int i = 0; i < personalities.length; i++) {
    print("${i + 1}: ${personalities[i].name} - ${personalities[i].description}");
  }
  
  stdout.write("Choose AI opponent (1-${personalities.length}): ");
  String? input = stdin.readLineSync();
  int? choice = int.tryParse(input ?? "1");
  if (choice == null || choice < 1 || choice > personalities.length) choice = 1;
  
  AIPersonality aiOpponent = personalities[choice - 1];
  AIPersonality humanPlaceholder = PrimeHunterAI(); // This doesn't matter, just a placeholder
  
  print("\nWho goes first?");
  print("1: Human");
  print("2: AI");
  
  stdout.write("Choose (1-2): ");
  String? firstInput = stdin.readLineSync();
  bool humanFirst = firstInput != "2";

  Random rng = Random();
  PvPGame battle = PvPGame(
    // FIX: Correctly assign player roles based on turn order
    player1AI: humanFirst ? humanPlaceholder : aiOpponent,
    player2AI: humanFirst ? aiOpponent : humanPlaceholder,
    rng: rng,
    verbose: true,
    player1IsHuman: humanFirst,
    player2IsHuman: !humanFirst,
  );
  battle.runGame();
}

void _runContinuousAiVsGame() {
  List<AIPersonality> personalities = [
    PrimeHunterAI(),
    SequenceWeaverAI(),
    DefensiveMathAI()
  ];

  print("\nSelect AI for Continuous Play:");
  for (int i = 0; i < personalities.length; i++) {
    print(
        "${i + 1}: ${personalities[i].name} - ${personalities[i].description}");
  }

  stdout.write("Choose AI (1-${personalities.length}): ");
  String? input = stdin.readLineSync();
  int? choice = int.tryParse(input ?? "1");
  if (choice == null || choice < 1 || choice > personalities.length) {
    choice = 1;
  }

  AIPersonality selectedAI = personalities[choice - 1];

  Random rng = Random();
  ContinuousPlayGame game =
      ContinuousPlayGame(selectedAI, rng, verbose: true);

  print("\n🚀 Starting continuous play with ${selectedAI.name}...");
  bool victory = game.playFullGame();

  print(victory ? "\n🎊 Mission accomplished!" : "\n💀 Mission failed!");
}
