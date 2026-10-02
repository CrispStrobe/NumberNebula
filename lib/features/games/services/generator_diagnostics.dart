// ignore_for_file: avoid_print
// Optional CLI/app generator tracing without importing Flutter.
const kDebugMode = bool.fromEnvironment('GENERATOR_DEBUG');
void traceGenerator(String? message) {
  if (kDebugMode && message != null) print(message);
}
