/// A complete, valid fallback of the requested size for every wall operation.
List<int> buildFallbackNumberWall(int height, String operation) {
  if (height < 3 || height > 6) {
    throw ArgumentError.value(height, 'height', 'Expected 3..6');
  }
  final wall = List<int>.filled(height * (height + 1) ~/ 2, 0);
  final bottom = height * (height - 1) ~/ 2;
  for (int c = 0; c < height; c++) {
    wall[bottom + c] = switch (operation) {
      'addition' => c + 2,
      'subtraction' => 1 << (c + 1),
      'multiplication' => c == 0
          ? 2
          : c == height - 1
              ? 3
              : 1,
      'division' => 2,
      _ => throw ArgumentError.value(operation, 'operation'),
    };
  }
  for (int r = height - 2; r >= 0; r--) {
    for (int c = 0; c <= r; c++) {
      final left = wall[(r + 1) * (r + 2) ~/ 2 + c];
      final right = wall[(r + 1) * (r + 2) ~/ 2 + c + 1];
      wall[r * (r + 1) ~/ 2 + c] = switch (operation) {
        'addition' => left + right,
        'subtraction' => (left - right).abs(),
        'multiplication' => left * right,
        'division' => left >= right ? left ~/ right : right ~/ left,
        _ => throw StateError('Unsupported operation'),
      };
    }
  }
  return wall;
}
