import 'package:dart_csp/dart_csp.dart';

/// Exact supports for a op b = result. Named column order avoids assignment-map
/// iteration dependence; dart_csp's table propagator prunes all three domains.
List<List<dynamic>> arithmeticTriples(List<int> domain, String op) {
  final allowed = domain.toSet();
  final tuples = <List<dynamic>>[];
  for (final a in domain) {
    for (final b in domain) {
      final int? result = switch (op) {
        '+' => a + b,
        '−' || '-' => a - b,
        '×' || '*' => a * b,
        '÷' || '/' => b != 0 && a % b == 0 ? a ~/ b : null,
        _ => null,
      };
      if (result != null && allowed.contains(result)) {
        tuples.add([a, b, result]);
      }
    }
  }
  return tuples;
}

/// Specialized library propagation for linear arithmetic, indexed exact supports
/// for multiplication/division. Keep the original predicates as the A/B baseline.
void addArithmeticConstraint(
    Problem problem, List<String> vars, List<int> domain, String op) {
  if (op == '+' || op == '−' || op == '-') {
    problem.addLinearEquals(vars, [1, op == '+' ? 1 : -1, -1], 0);
    return;
  }
  final supports = <int, Map<int, Set<int>>>{};
  for (final tuple in arithmeticTriples(domain, op)) {
    supports
        .putIfAbsent(tuple[0] as int, () => {})
        .putIfAbsent(tuple[1] as int, () => {})
        .add(tuple[2] as int);
  }
  problem.addConstraint(
      vars,
      (Map<String, dynamic> values) =>
          supports[values[vars[0]]]?[values[vars[1]]]
              ?.contains(values[vars[2]]) ??
          false);
}

/// Establish generalized arc consistency before invoking the CSP search.
/// Impossible random operator layouts are rejected without spending a solve budget.
Map<String, List<int>>? pruneArithmeticDomains(Map<String, List<int>> domains,
    List<({List<String> cells, String op})> equations) {
  final ds = domains.map((k, v) => MapEntry(k, v.toSet()));
  final tables = [
    for (final eq in equations)
      (
        cells: eq.cells,
        tuples: arithmeticTriples(
            eq.cells.expand((c) => domains[c]!).toSet().toList(), eq.op)
      )
  ];
  var changed = true;
  while (changed) {
    changed = false;
    for (final table in tables) {
      final supports = List.generate(3, (_) => <int>{});
      for (final tuple in table.tuples) {
        if (List.generate(3, (i) => ds[table.cells[i]]!.contains(tuple[i]))
            .every((v) => v)) {
          for (var i = 0; i < 3; i++) {
            supports[i].add(tuple[i] as int);
          }
        }
      }
      for (var i = 0; i < 3; i++) {
        final domain = ds[table.cells[i]]!, before = domain.length;
        domain.retainAll(supports[i]);
        if (domain.isEmpty) return null;
        changed |= before != domain.length;
      }
    }
  }
  return ds.map((k, v) => MapEntry(k, v.toList()));
}
