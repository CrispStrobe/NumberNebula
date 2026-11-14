import 'package:integration_test/integration_test_driver.dart';

// The KOMPASS end-to-end run opens every session, paper and lab; on a loaded
// machine that exceeds the driver's 20-minute default.
Future<void> main() => integrationDriver(timeout: const Duration(minutes: 45));
