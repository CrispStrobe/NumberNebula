import 'dart:async';

/// Keep baseline and candidate implementations independently selectable.
/// Auto uses a verified candidate, then the existing algorithm on failure.
enum AlgorithmPath { legacy, candidate, auto }

final _algorithmKey = Object();
AlgorithmPath get algorithmPath =>
    Zone.current[_algorithmKey] as AlgorithmPath? ??
    AlgorithmPath.values.byName(const String.fromEnvironment(
        'GAME_ALGORITHM_PATH',
        defaultValue: 'auto'));
T withAlgorithmPath<T>(AlgorithmPath path, T Function() action) =>
    runZoned(action, zoneValues: {_algorithmKey: path});

final _traceKey = Object();
T withAlgorithmTrace<T>(Map<String, String> trace, T Function() action) =>
    runZoned(action, zoneValues: {_traceKey: trace});
void recordAlgorithm(String operation, String implementation) {
  (Zone.current[_traceKey] as Map<String, String>?)?[operation] =
      implementation;
}

/// Independently compare the two CSP candidates without changing the baseline.
enum SquareGenerationPath { pruned, constructive }

final _squarePathKey = Object();
SquareGenerationPath get squareGenerationPath =>
    Zone.current[_squarePathKey] as SquareGenerationPath? ??
    SquareGenerationPath.values.byName(const String.fromEnvironment(
        'SQUARE_GENERATION_PATH',
        defaultValue: 'constructive'));
T withSquareGenerationPath<T>(SquareGenerationPath path, T Function() action) =>
    runZoned(action, zoneValues: {_squarePathKey: path});
