import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/core/utils/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('debug does not throw', () {
      expect(() => AppLogger.debug('hello'), returnsNormally);
      expect(() => AppLogger.debug('with tag', tag: 'Test'), returnsNormally);
    });

    test('verbose does not throw regardless of flag', () {
      expect(() => AppLogger.verbose('msg', enabled: true, tag: 'V'), returnsNormally);
      expect(() => AppLogger.verbose('msg', enabled: false, tag: 'V'), returnsNormally);
    });

    test('verbose only emits when enabled=true in debug mode', () {
      final messages = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = original);

      // enabled false should produce no output
      AppLogger.verbose('should-not-appear', enabled: false, tag: 'T');
      expect(messages, isEmpty, reason: 'disabled verbose must not log');

      // enabled true should produce output in debug mode
      AppLogger.verbose('should-appear', enabled: true, tag: 'T');
      // In test, kDebugMode is true, so we expect one message.
      expect(messages, hasLength(1));
      expect(messages.first, contains('should-appear'));
      expect(messages.first, contains('[T]'));

      messages.clear();
      AppLogger.debug('debug-msg', tag: 'D');
      expect(messages, hasLength(1));
      expect(messages.first, contains('debug-msg'));
    });

    test('debug includes tag bracketing', () {
      final messages = <String>[];
      final original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = original);

      AppLogger.debug('payload', tag: 'StarLoader');
      expect(messages.single, '[StarLoader] payload');
    });
  });
}
