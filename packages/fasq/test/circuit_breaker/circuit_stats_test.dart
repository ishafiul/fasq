import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitStats', () {
    test('initializes with default values', () {
      final stats = CircuitStats();

      expect(stats.failureCount, 0);
      expect(stats.successCount, 0);
      expect(stats.lastFailureTimestamp, isNull);
    });

    test('initializes with custom values', () {
      final timestamp = DateTime.now();
      final stats = CircuitStats(
        failureCount: 5,
        successCount: 3,
        lastFailureTimestamp: timestamp,
      );

      expect(stats.failureCount, 5);
      expect(stats.successCount, 3);
      expect(stats.lastFailureTimestamp, timestamp);
    });

    test('reset restores all metrics to defaults', () {
      final timestamp = DateTime.now();
      final stats = CircuitStats(
        failureCount: 10,
        successCount: 5,
        lastFailureTimestamp: timestamp,
      );

      stats.reset();

      expect(stats.failureCount, 0);
      expect(stats.successCount, 0);
      expect(stats.lastFailureTimestamp, isNull);
    });

    test('copyWith creates new instance with updated values', () {
      final original = CircuitStats(
        failureCount: 1,
        successCount: 2,
      );

      final updated = original.copyWith(
        failureCount: 3,
        successCount: 4,
      );

      expect(updated.failureCount, 3);
      expect(updated.successCount, 4);
      expect(original.failureCount, 1);
      expect(original.successCount, 2);
    });

    test('copyWith preserves unchanged values', () {
      final timestamp = DateTime.now();
      final original = CircuitStats(
        failureCount: 1,
        successCount: 2,
        lastFailureTimestamp: timestamp,
      );

      final updated = original.copyWith(failureCount: 3);

      expect(updated.failureCount, 3);
      expect(updated.successCount, 2);
      expect(updated.lastFailureTimestamp, timestamp);
    });

    test('toString includes all fields', () {
      final timestamp = DateTime.now();
      final stats = CircuitStats(
        failureCount: 5,
        successCount: 3,
        lastFailureTimestamp: timestamp,
      );

      final string = stats.toString();

      expect(string, contains('CircuitStats'));
      expect(string, contains('failureCount: 5'));
      expect(string, contains('successCount: 3'));
      expect(string, contains('lastFailureTimestamp'));
    });
  });
}
