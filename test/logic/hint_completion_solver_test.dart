import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/hint_completion_solver.dart';
import 'package:space_math_academy/features/games/services/star_forge_logic.dart';
import 'package:space_math_academy/features/games/services/orbital_towers_logic.dart';

void main() {
  test('star hints respect an alternative valid partial solution', () async {
    final p = await StarForgeGenerator().generate(points: 5, clueCount: 0);
    // Swapping both halves of one tip/node pair leaves every arm total valid.
    final alternative = Map<int, int>.from(p.solution);
    alternative[0] = p.solution[5]!;
    alternative[5] = p.solution[0]!;
    expect(p.validateSolution(alternative), isTrue);
    final result = findHintCompletion({
      'values': {'0': alternative[0]},
      'domains': {for (int i = 0; i < 10; i++) '$i': p.numberPool},
      'groups': [List.generate(10, (i) => '$i')],
      'pool': p.numberPool,
      'equations': p.lines
          .map((l) => {
                'op': 'sum',
                'target': p.magicConstant,
                'cells': l.map((i) => '$i').toList()
              })
          .toList(),
    });
    expect(result, isNotNull);
    expect(result!['0'], alternative[0]);
    expect(p.validateSolution(result.map((k, v) => MapEntry(int.parse(k), v))),
        isTrue);
  });
  test('tower completion honours sightlines, rows and columns', () {
    final result = findHintCompletion({
      'values': {'r0c0': 3},
      'domains': {
        for (int r = 0; r < 3; r++)
          for (int c = 0; c < 3; c++) 'r${r}c$c': [1, 2, 3]
      },
      'groups': [
        for (int r = 0; r < 3; r++) List.generate(3, (c) => 'r${r}c$c'),
        for (int c = 0; c < 3; c++) List.generate(3, (r) => 'r${r}c$c')
      ],
      'sightlines': [
        {
          'cells': ['r0c0', 'r0c1', 'r0c2'],
          'target': 1
        }
      ],
    });
    expect(result, isNotNull);
    final p = OrbitalTowersPuzzle(
        size: 3,
        solution: result!,
        clues: {},
        emptyCells: result.keys.toSet(),
        numberPool: [1, 2, 3],
        edgeClues: {'left_0': 1});
    expect(p.validateSolution(result), isTrue);
  });
  test('wall completion handles repeated bricks and refuses contradictions',
      () {
    final data = <String, dynamic>{
      'values': {'1': 3, '2': 4},
      'domains': {
        '0': [6, 7, 8]
      },
      'pool': [6, 7, 8],
      'equations': [
        {
          'cells': ['0', '1', '2'],
          'op': 'addition'
        }
      ]
    };
    expect(findHintCompletion(data)!['0'], 7);
    data['values'] = {'0': 6, '1': 3, '2': 4};
    expect(findHintCompletion(data), isNull);
  });
}
