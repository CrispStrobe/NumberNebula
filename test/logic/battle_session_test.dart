import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/shared/utils/arithmancer.dart';
import 'package:space_math_academy/features/games/models/game_outcome.dart';

Map<String, dynamic> disk(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

void main() {
  test('restored battle can consume saved cards and advance its enemy', () {
    final game = ArithmancerGame(PrimeHunterAI(), Random(42), verbose: false)
      ..startNewBattle();
    game.currentEnemy!.turnCounter = 3;
    final restored = ArithmancerGame.fromJson(disk(game.toJson()));
    expect(restored.toJson(), game.toJson());
    expect(restored.currentEnemy!.getIntent(), game.currentEnemy!.getIntent());
    final card = restored.hand.first;
    final energy = restored.playerEnergy;
    restored.executeResult(MathResult(-2, [card], '-2', []));
    expect(restored.hand.any((c) => c.id == card.id), isFalse);
    expect(restored.playerEnergy, energy - card.cost);
    expect(restored.currentBlock, greaterThan(0));
    final turn = restored.turn;
    restored.startTurn();
    expect(restored.turn, turn + 1);
  });

  test('PvP saves both players, AI, turn and remaining card order', () {
    final game = PvPGame(
        player1AI: PrimeHunterAI(),
        player2AI: DefensiveMathAI(),
        rng: Random(21),
        verbose: false,
        player1IsHuman: true);
    game.player1State.health = 61;
    game.player1State.energy = 2;
    game.player2State.health = 83;
    game.player2State.block = 4;
    game.player2State.passedLastTurn = true;
    game.turn = 7;
    final restored = PvPGame.fromJson(disk(game.toJson()));
    expect(restored.toJson(), game.toJson());
    restored.player1State.replenishHand();
    expect(restored.player1State.health, 61);
    expect(restored.player2State.health, 83);
  });

  test('coaching adds to native hints without fabricating performance', () {
    final measured = GameOutcome.win(
            gameType: 'star_forge',
            difficulty: 1,
            score: 100,
            performance: 1,
            hintsUsed: 2)
        .withCoachingHints(1);
    expect(measured.hintsUsed, 3);
    expect(measured.performance, lessThan(1));
    final unmeasured = const GameOutcome(
            gameType: 'asteroid_math',
            difficulty: 1,
            score: 0,
            wasSuccessful: false)
        .withCoachingHints(2);
    expect(unmeasured.hintsUsed, 2);
    expect(unmeasured.performance, isNull);
  });
}
