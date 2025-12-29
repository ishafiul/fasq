import 'package:fasq/src/logger/fasq_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FasqLogger', () {
    test('default constructor sets correct default values', () {
      final logger = FasqLogger();

      expect(logger.enabled, isTrue);
      expect(logger.showData, isFalse);
      expect(logger.truncateLength, 100);
    });

    test('constructor with custom values sets properties correctly', () {
      final logger = FasqLogger(
        enabled: false,
        showData: true,
        truncateLength: 50,
      );

      expect(logger.enabled, isFalse);
      expect(logger.showData, isTrue);
      expect(logger.truncateLength, 50);
    });
  });
}
