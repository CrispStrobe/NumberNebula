/// Synchronous, bounded support propagation for cages and visibility lines.
/// No stored solution is consulted. Every completion respects current placements.
Map<String, int>? findTableHintCompletion(Map<String, dynamic> data) {
  final clock = Stopwatch()..start();
  final timeout = data['timeoutMs'] as int? ?? 40;
  final maxVisits = data['maxVisits'] as int? ?? 12000;
  var visits = 0, tupleVisits = 0;
  bool expired() => clock.elapsedMilliseconds >= timeout || visits >= maxVisits;
  final initial = Map<String, int>.from(data['values']);
  final domains = (data['domains'] as Map)
      .map((k, v) => MapEntry(k as String, List<int>.from(v).toSet()));
  for (final entry in initial.entries) {
    if (domains.containsKey(entry.key) &&
        !domains[entry.key]!.contains(entry.value)) {
      return null;
    }
    domains[entry.key] = {entry.value};
  }
  if (domains.values.any((d) => d.isEmpty)) return null;
  final groups =
      (data['groups'] as List? ?? []).map((g) => List<String>.from(g)).toList();
  final constraints = <({List<String> cells, List<List<int>> tuples})>[];
  for (final raw in [
    ...?data['cages'] as List?,
    ...?data['sightlines'] as List?
  ]) {
    final row = raw as Map, cells = List<String>.from(raw['cells']);
    if (cells.any((c) => !domains.containsKey(c))) return null;
    final sightline = row.containsKey('target');
    final target = sightline
        ? row['target'] as int
        : int.tryParse(
            row['clue'].toString().replaceAll(RegExp(r'[^0-9]'), ''));
    if (target == null) return null;
    final tuples = <List<int>>[];
    bool valid(List<int> v) {
      if (sightline) {
        var high = 0, seen = 0;
        for (final value in v) {
          if (value > high) {
            high = value;
            seen++;
          }
        }
        return seen == target;
      }
      return switch (row['op']) {
        '+' => v.fold<int>(0, (a, b) => a + b) == target,
        '×' || '*' => v.fold<int>(1, (a, b) => a * b) == target,
        '−' || '-' => v.length == 2 && (v[0] - v[1]).abs() == target,
        '÷' ||
        '/' =>
          v.length == 2 && (v[0] == v[1] * target || v[1] == v[0] * target),
        _ => v.length == 1 && v.single == target,
      };
    }

    final conflicts = List.generate(
        cells.length,
        (i) => List.generate(
            cells.length,
            (j) => groups
                .any((g) => g.contains(cells[i]) && g.contains(cells[j]))));
    final positive = cells.every((c) => domains[c]!.every((v) => v > 0));
    void enumerate(List<int> prefix) {
      if (expired() || ++tupleVisits > 100000) return;
      if (sightline) {
        var highest = 0, seen = 0;
        for (final value in prefix) {
          if (value > highest) {
            highest = value;
            seen++;
          }
        }
        if (seen > target || seen + cells.length - prefix.length < target) {
          return;
        }
      } else if (row['op'] == '+') {
        final known = prefix.fold<int>(0, (a, b) => a + b);
        var min = known, max = known;
        for (var i = prefix.length; i < cells.length; i++) {
          min += domains[cells[i]]!.reduce((a, b) => a < b ? a : b);
          max += domains[cells[i]]!.reduce((a, b) => a > b ? a : b);
        }
        if (min > target || max < target) return;
      } else if (positive && (row['op'] == '×' || row['op'] == '*')) {
        final product = prefix.fold<int>(1, (a, b) => a * b);
        if (product > target || target % product != 0) return;
      }
      if (prefix.length == cells.length) {
        if (valid(prefix)) tuples.add(List<int>.from(prefix));
        return;
      }
      final cell = cells[prefix.length];
      for (final value in domains[cell]!) {
        var repeats = false;
        for (var j = 0; j < prefix.length; j++) {
          if (prefix[j] == value && conflicts[prefix.length][j]) {
            repeats = true;
            break;
          }
        }
        if (!repeats) enumerate([...prefix, value]);
      }
    }

    enumerate([]);
    if (expired() || tupleVisits > 100000 || tuples.isEmpty) return null;
    constraints.add((cells: cells, tuples: tuples));
  }
  bool propagate(Map<String, Set<int>> ds) {
    var changed = true;
    while (changed) {
      if (expired()) return false;
      changed = false;
      for (final group in groups) {
        final singles = <int>{};
        for (final cell in group) {
          final d = ds[cell];
          if (d == null || d.isEmpty) return false;
          if (d.length == 1 && !singles.add(d.single)) return false;
        }
        for (final cell in group) {
          final d = ds[cell]!;
          if (d.length == 1) continue;
          final before = d.length;
          d.removeAll(singles);
          if (d.isEmpty) return false;
          changed |= before != d.length;
        }
        // A Hall violation can be proved cheaply for the entire row/column.
        if (group.expand((c) => ds[c]!).toSet().length < group.length) {
          return false;
        }
      }
      for (final table in constraints) {
        final supports = List.generate(table.cells.length, (_) => <int>{});
        for (final tuple in table.tuples) {
          var matches = true;
          for (var i = 0; i < tuple.length; i++) {
            if (!ds[table.cells[i]]!.contains(tuple[i])) {
              matches = false;
              break;
            }
          }
          if (matches) {
            for (var i = 0; i < tuple.length; i++) {
              supports[i].add(tuple[i]);
            }
          }
        }
        for (var i = 0; i < table.cells.length; i++) {
          final d = ds[table.cells[i]]!, before = d.length;
          d.retainAll(supports[i]);
          if (d.isEmpty) return false;
          changed |= before != d.length;
        }
      }
    }
    return true;
  }

  Map<String, int>? search(Map<String, Set<int>> ds) {
    visits++;
    if (expired() || !propagate(ds)) return null;
    String? cell;
    for (final e in ds.entries) {
      if (e.value.length > 1 &&
          (cell == null || e.value.length < ds[cell]!.length)) {
        cell = e.key;
      }
    }
    if (cell == null) return ds.map((k, d) => MapEntry(k, d.single));
    for (final value in ds[cell]!) {
      final copy = ds.map((k, d) => MapEntry(k, Set<int>.from(d)));
      copy[cell] = {value};
      final answer = search(copy);
      if (answer != null) return answer;
      if (expired()) return null;
    }
    return null;
  }

  return search(domains);
}
