import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/models/starloader_level_model.dart';

void main() {
  test('retired board history and ratings survive a database round trip', () {
    final legacy = LevelEntry(
        id: 'retired',
        difficulty: 'grade_2',
        dimX: 1,
        dimY: 1,
        roomStructure: [
          [0]
        ],
        roomState: [
          [0]
        ],
        optimalMoves: 9,
        avgRating: 4.5,
        ratingCount: 2);
    final db = LevelDatabase(levels: [legacy], retiredLevelIds: {'retired'});
    final restored = LevelDatabase.fromJson(db.toJson());
    expect(restored.retiredLevelIds, {'retired'});
    expect(restored.levels.single.id, 'retired');
    expect(restored.levels.single.avgRating, 4.5);
    expect(restored.levels.single.ratingCount, 2);
    final oldFormat = LevelDatabase.fromJson({
      'levels': [legacy.toJson()]
    });
    expect(oldFormat.retiredLevelIds, isEmpty);
  });
}
