import 'algorithm_path.dart';
import 'table_hint_solver.dart';

/// Find a completion that respects the child's current moves. Work is bounded
/// and runs in an isolate; a hint never declares a different valid solution wrong.
Map<String, int>? findHintCompletion(Map<String, dynamic> data) {
  if (algorithmPath == AlgorithmPath.legacy ||
      ((data['cages'] as List? ?? []).isEmpty &&
          (data['sightlines'] as List? ?? []).isEmpty)) {
    return findHintCompletionLegacy(data);
  }
  final clock = Stopwatch()..start();
  final completion = findTableHintCompletion(data);
  if (completion != null) {
    // Independent baseline validation with a fully fixed board is cheap and
    // guards every constraint, including any future additions to the schema.
    final verified = findHintCompletionLegacy(
        {...data, 'values': completion, 'timeoutMs': null, 'maxVisits': 1});
    if (verified != null) return verified;
  }
  if (algorithmPath == AlgorithmPath.candidate) return null;
  final budget = data['timeoutMs'] as int?;
  if (budget != null && clock.elapsedMilliseconds >= budget) return null;
  return findHintCompletionLegacy({
    ...data,
    if (budget != null) 'timeoutMs': budget - clock.elapsedMilliseconds
  });
}

Map<String, int>? findHintCompletionLegacy(Map<String, dynamic> data) {
  final values = Map<String, int>.from(data['values']);
  final domains = (data['domains'] as Map)
      .map((k, v) => MapEntry(k as String, List<int>.from(v)));
  final equations = (data['equations'] as List? ?? []).cast<Map>();
  final groups =
      (data['groups'] as List? ?? []).map((v) => List<String>.from(v)).toList();
  final sightlines = (data['sightlines'] as List? ?? []).cast<Map>();
  final pool = data['pool'] == null ? null : List<int>.from(data['pool']);
  final initial = Map<String, int>.from(values);
  var visits = 0;
  final clock = Stopwatch()..start();
  final maxVisits = data['maxVisits'] as int? ?? 30000;
  final timeoutMs = data['timeoutMs'] as int?;
  bool legal() {
    for (final group in groups) {
      final filled =
          group.where(values.containsKey).map((k) => values[k]!).toList();
      if (filled.toSet().length != filled.length) return false;
    }
    if (pool != null) {
      final used = <int, int>{};
      // Fixed clues are outside the placement pool.
      for (final key in domains.keys) {
        final value = values[key];
        if (value != null) used[value] = (used[value] ?? 0) + 1;
      }
      for (final entry in used.entries) {
        if (pool.where((v) => v == entry.key).length < entry.value) {
          return false;
        }
      }
    }
    for (final eq in equations) {
      final cells = List<String>.from(eq['cells']);
      if (eq['op'] == 'sum') {
        final target = eq['target'] as int;
        final known = cells
            .where(values.containsKey)
            .fold<int>(0, (sum, k) => sum + values[k]!);
        final unknown = cells.where((k) => !values.containsKey(k)).toList();
        if (unknown.isEmpty && known != target) return false;
        if (unknown.isNotEmpty) {
          final minSum = unknown.fold<int>(
              0, (sum, k) => sum + domains[k]!.reduce((a, b) => a < b ? a : b));
          final maxSum = unknown.fold<int>(
              0, (sum, k) => sum + domains[k]!.reduce((a, b) => a > b ? a : b));
          if (known + minSum > target || known + maxSum < target) return false;
        }
      } else if (cells.every(values.containsKey)) {
        final result = values[cells[0]]!,
            a = values[cells[1]]!,
            b = values[cells[2]]!;
        final valid = switch (eq['op']) {
          'addition' => result == a + b,
          'subtraction' => result == (a - b).abs(),
          'multiplication' => result == a * b,
          'division' => (b != 0 && a % b == 0 && result == a ~/ b) ||
              (a != 0 && b % a == 0 && result == b ~/ a),
          _ => false,
        };
        if (!valid) return false;
      }
    }
    for (final raw in data['cages'] as List? ?? []) {
      final cage = raw as Map;
      final cells = List<String>.from(cage['cells']);
      if (!cells.every(values.containsKey)) continue;
      final v = cells.map((c) => values[c]!).toList();
      final target = int.tryParse(
          cage['clue'].toString().replaceAll(RegExp(r'[^0-9]'), ''));
      if (target == null) return false;
      final op = cage['op'];
      final valid = switch (op) {
        '+' => v.fold<int>(0, (a, b) => a + b) == target,
        '×' || '*' => v.fold<int>(1, (a, b) => a * b) == target,
        '−' || '-' => v.length == 2 && (v[0] - v[1]).abs() == target,
        '÷' ||
        '/' =>
          v.length == 2 && (v[0] == v[1] * target || v[1] == v[0] * target),
        _ => v.length == 1 && v[0] == target,
      };
      if (!valid) return false;
    }
    for (final line in sightlines) {
      final cells = List<String>.from(line['cells']);
      if (!cells.every(values.containsKey)) continue;
      int highest = 0, visible = 0;
      for (final cell in cells) {
        final height = values[cell]!;
        if (height > highest) {
          highest = height;
          visible++;
        }
      }
      if (visible != line['target']) return false;
    }
    return true;
  }

  Map<String, int>? search() {
    if (++visits > maxVisits ||
        (timeoutMs != null && clock.elapsedMilliseconds >= timeoutMs)) {
      return null;
    }
    if (!legal()) return null;
    String? next;
    List<int>? choices;
    for (final entry in domains.entries) {
      if (values.containsKey(entry.key)) continue;
      final candidates = <int>[];
      for (final candidate in entry.value) {
        values[entry.key] = candidate;
        if (legal()) candidates.add(candidate);
      }
      values.remove(entry.key);
      if (candidates.isEmpty) return null;
      if (choices == null || candidates.length < choices.length) {
        next = entry.key;
        choices = candidates;
        if (candidates.length == 1) break;
      }
    }
    if (next == null) return Map<String, int>.from(values);
    for (final value in choices!) {
      values[next] = value;
      final solution = search();
      if (solution != null) return solution;
    }
    values.remove(next);
    return null;
  }

  // Invalid domains indicate a damaged board; never invent a demonstration.
  if (domains.values.any((v) => v.isEmpty)) return null;
  for (final entry in initial.entries) {
    if (domains.containsKey(entry.key) &&
        !domains[entry.key]!.contains(entry.value)) {
      return null;
    }
  }
  return search();
}
