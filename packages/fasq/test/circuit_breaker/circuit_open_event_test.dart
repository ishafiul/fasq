import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitOpenEvent', () {
    test('creates event with circuitId and openedAt', () {
      final now = DateTime.now();
      final event = CircuitOpenEvent(
        circuitId: 'api.example.com',
        openedAt: now,
      );

      expect(event.circuitId, 'api.example.com');
      expect(event.openedAt, now);
    });

    test('toString returns formatted string', () {
      final now = DateTime(2024, 1, 1, 12, 0, 0);
      final event = CircuitOpenEvent(
        circuitId: 'api.example.com',
        openedAt: now,
      );

      final str = event.toString();
      expect(str, contains('CircuitOpenEvent'));
      expect(str, contains('api.example.com'));
      expect(str, contains('2024-01-01'));
    });
  });

  group('CircuitOpenCallback', () {
    test('callback can be invoked with event', () {
      CircuitOpenCallback? callback;
      CircuitOpenEvent? receivedEvent;

      callback = (event) {
        receivedEvent = event;
      };

      final testEvent = CircuitOpenEvent(
        circuitId: 'test-circuit',
        openedAt: DateTime.now(),
      );

      callback(testEvent);

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.circuitId, 'test-circuit');
    });
  });
}
