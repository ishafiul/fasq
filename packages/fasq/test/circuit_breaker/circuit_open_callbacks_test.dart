import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('logCircuitOpenEvent', () {
    test('can be invoked without throwing', () {
      final event = CircuitOpenEvent(
        circuitId: 'api.example.com',
        openedAt: DateTime.now(),
      );

      expect(() => logCircuitOpenEvent(event), returnsNormally);
    });
  });
}
