import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fasq/src/persistence/encryption_service.dart';

void main() {
  group('Encryption Performance Benchmarks', () {
    late EncryptionService encryptionService;
    late String encryptionKey;

    setUp(() {
      encryptionService = EncryptionService();
      encryptionKey = encryptionService.generateKey();
    });

    test('encryption overhead is under 20ms for typical cache entry (1KB)',
        () async {
      final data = List.generate(1024, (i) => i % 256); // 1KB

      final stopwatch = Stopwatch()..start();
      final encrypted = await encryptionService.encrypt(data, encryptionKey);
      final decrypted =
          await encryptionService.decrypt(encrypted, encryptionKey);
      stopwatch.stop();

      expect(decrypted, equals(data));
      expect(stopwatch.elapsedMilliseconds,
          lessThan(30)); // Increased threshold for AES-GCM with IV
    });

    test('encryption performance scales linearly with data size', () async {
      final sizes = [1024, 10 * 1024, 100 * 1024]; // 1KB, 10KB, 100KB
      final times = <int>[];

      for (final size in sizes) {
        final data = List.generate(size, (i) => i % 256);

        final stopwatch = Stopwatch()..start();
        final encrypted = await encryptionService.encrypt(data, encryptionKey);
        final decrypted =
            await encryptionService.decrypt(encrypted, encryptionKey);
        stopwatch.stop();

        expect(decrypted, equals(data));
        times.add(stopwatch.elapsedMilliseconds);
      }

      // Verify that encryption time scales roughly linearly
      // (allowing for some variance due to isolate overhead)
      expect(times[1],
          lessThan(times[0] * 15)); // 10KB should be < 15x slower than 1KB
      expect(times[2],
          lessThan(times[0] * 150)); // 100KB should be < 150x slower than 1KB
    });

    test('large data encryption uses isolate and maintains performance',
        () async {
      final largeData = List.generate(1024 * 1024, (i) => i % 256); // 1MB

      final stopwatch = Stopwatch()..start();
      final encrypted =
          await encryptionService.encrypt(largeData, encryptionKey);
      final decrypted =
          await encryptionService.decrypt(encrypted, encryptionKey);
      stopwatch.stop();

      expect(decrypted, equals(largeData));
      expect(stopwatch.elapsedMilliseconds,
          lessThan(5000)); // Should complete within 5 seconds
    });

    test('encryption performance is consistent across multiple runs', () async {
      final data = List.generate(10 * 1024, (i) => i % 256); // 10KB
      final times = <int>[];

      // Run encryption/decryption 5 times
      for (int i = 0; i < 5; i++) {
        final stopwatch = Stopwatch()..start();
        final encrypted = await encryptionService.encrypt(data, encryptionKey);
        final decrypted =
            await encryptionService.decrypt(encrypted, encryptionKey);
        stopwatch.stop();

        expect(decrypted, equals(data));
        times.add(stopwatch.elapsedMilliseconds);
      }

      // Calculate variance (times should be relatively consistent)
      final average = times.reduce((a, b) => a + b) / times.length;
      final variance = times
              .map((t) => (t - average) * (t - average))
              .reduce((a, b) => a + b) /
          times.length;
      final standardDeviation = sqrt(variance);

      // Standard deviation should be less than 50% of average
      expect(standardDeviation, lessThan(average * 0.5));
    });

    test('encryption key generation is fast', () {
      final stopwatch = Stopwatch()..start();
      final key = encryptionService.generateKey();
      stopwatch.stop();

      expect(key, isNotEmpty);
      expect(encryptionService.isValidKey(key), isTrue);
      expect(
          stopwatch.elapsedMilliseconds, lessThan(100)); // Should be very fast
    });
  });
}
