import 'dart:async';
import 'dart:math' as math;

final _randomZoneKey = Object();
final _identifierZoneKey = Object();

String? seededGeneratorIdentifier() {
  final counter = Zone.current[_identifierZoneKey] as List<int>?;
  return counter == null ? null : 'seed${counter[0]}_${counter[1]++}';
}

/// A shared stream within a seeded generation scope; ordinary app calls retain
/// their unseeded behaviour. Explicit seeds always take precedence.
math.Random generatorRandom([int? seed]) => seed != null
    ? math.Random(seed)
    : Zone.current[_randomZoneKey] as math.Random? ?? math.Random();

T withGeneratorSeed<T>(int seed, T Function() generate) =>
    runZoned(generate, zoneValues: {
      _randomZoneKey: math.Random(seed),
      _identifierZoneKey: [seed, 0]
    });

/// Keep CSP restart choices on the same scoped stream without changing app RNG defaults.
int? generatorSolverSeed() => Zone.current[_randomZoneKey] == null
    ? null
    : generatorRandom().nextInt(0x7fffffff);
