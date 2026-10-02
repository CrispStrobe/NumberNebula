import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/games/services/number_wall_fallback.dart';

void main() {
  for (int height = 3; height <= 6; height++) {
    for (final operation in [
      'addition',
      'subtraction',
      'multiplication',
      'division'
    ]) {
      test(
          '$height-row $operation fallback has every cell and obeys every relation',
          () {
        final wall = buildFallbackNumberWall(height, operation);
        expect(wall, hasLength(height * (height + 1) ~/ 2));
        expect(wall.every((v) => v > 0), isTrue);
        final rows = <List<int>>[];
        int offset = 0;
        for (int length = 1; length <= height; length++) {
          rows.add(wall.sublist(offset, offset + length));
          offset += length;
        }
        for (int r = 0; r < height - 1; r++) {
          for (int c = 0; c < rows[r].length; c++) {
            final parent = rows[r][c],
                a = rows[r + 1][c],
                b = rows[r + 1][c + 1];
            switch (operation) {
              case 'addition':
                expect(parent, a + b);
              case 'subtraction':
                expect(parent, (a - b).abs());
              case 'multiplication':
                expect(parent, a * b);
              case 'division':
                expect(parent * a == b || parent * b == a, isTrue);
            }
          }
        }
      });
    }
  }
}
