/// Exact equal-side solver for the game's 3..7 nodes per side.
///
/// Each corner belongs to two sides, so three times the side sum equals
/// the sum of every number plus the three corners. Pick the corners first,
/// then partition the remaining numbers into three equal-length side groups.
/// This avoids searching permutations whose order within a side is irrelevant.
List<int>? solveMagicTriangle(int nodesPerSide, List<int> numbers) {
  final count = 3 * nodesPerSide - 3;
  if (nodesPerSide < 3 ||
      nodesPerSide > 7 ||
      numbers.length != count ||
      numbers.toSet().length != count) {
    return null;
  }
  final groupSize = nodesPerSide - 2;
  final groupsBySum = <int, List<int>>{};
  void subsets(int start, int remaining, int sum, int mask) {
    if (remaining == 0) {
      (groupsBySum[sum] ??= []).add(mask);
      return;
    }
    for (int i = start; i <= count - remaining; i++) {
      subsets(i + 1, remaining - 1, sum + numbers[i], mask | (1 << i));
    }
  }

  subsets(0, groupSize, 0, 0);
  final total = numbers.fold<int>(0, (a, b) => a + b);
  final allMask = (1 << count) - 1;
  List<int> values(int mask) => [
        for (int i = 0; i < count; i++)
          if (mask & (1 << i) != 0) numbers[i],
      ];
  for (int a = 0; a < count - 2; a++) {
    for (int b = a + 1; b < count - 1; b++) {
      for (int c = b + 1; c < count; c++) {
        final combined = total + numbers[a] + numbers[b] + numbers[c];
        if (combined % 3 != 0) continue;
        final target = combined ~/ 3;
        final corners = (1 << a) | (1 << b) | (1 << c);
        final first = groupsBySum[target - numbers[a] - numbers[b]];
        final second = groupsBySum[target - numbers[b] - numbers[c]];
        if (first == null || second == null) continue;
        for (final left in first) {
          if (left & corners != 0) continue;
          for (final right in second) {
            if (right & (corners | left) != 0) continue;
            final last = allMask ^ (corners | left | right);
            return [
              numbers[a],
              ...values(left),
              numbers[b],
              ...values(right),
              numbers[c],
              ...values(last)
            ];
          }
        }
      }
    }
  }
  return null;
}
