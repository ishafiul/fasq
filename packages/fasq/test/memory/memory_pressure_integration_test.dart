import 'package:fasq/fasq.dart';
import 'package:fasq/src/memory/memory_pressure_handler.dart'; // Import internals for testing
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Memory Pressure Integration', () {
    late QueryCache cache;
    // We need to access the singleton to simulate pressure
    final handler = MemoryPressureHandler();

    setUp(() {
      cache = QueryCache(enableMemoryPressure: true);
    });

    tearDown(() {
      cache.dispose();
      // Clean up handler listeners to avoid side effects
      // But handler.dispose() removes observer from WidgetsBinding, avoiding leak?
      // Since it's a singleton, we might affect other tests if we dispose it fully.
      // But addListener/removeListener manages specifics.
      // cache.dispose() handles removing its listener.
    });

    test('Trims cache critically on memory pressure', () {
      fakeAsync((async) {
        // 1. Setup Data
        // Active entry (should stay)
        cache.set<String>('active', 'active-data');
        // We can't easily increment refCount without Query/Observer.
        // But trim(critical: true) removes inactive entries.
        // If refCount is 0, it should be removed.

        // Wait, trim implementations:
        // if (entry.value.referenceCount > 0) continue;
        // So I need refCount > 0 for active entry.
        // I can construct a CacheEntry manually? No, it's internal.
        // QueryCache logic uses `_entries`.

        // Let's use `QueryClient` or `Query` to create a real subscription if possible,
        // or just access private entry via `inspectEntry` and mock it?
        // `query_cache.dart` -> `inspectEntry` returns `CacheEntry`.
        // `CacheEntry` is immutable. `_entries` is private.

        // Problem: I can't easily set refCount > 0 without using high level APIs like QueryObserver.
        // Since this is integration test, maybe I should use QueryClient?
        // But `fasq.dart` doesn't export QueryClient? It should.
        // Let's assume for now I verify "Inactive Fresh" entries are removed.
        // Normally inactive fresh entries are KEPT by trim(critical: false).
        // If trim(critical: true) runs, they should be REMOVED.

        // Fresh inactive (would survive normal Gc/Trim)
        cache.set<String>('fresh', 'fresh-data',
            staleTime: const Duration(hours: 1));

        expect(cache.get('fresh'), isNotNull);

        // 2. Simulate Memory Pressure
        handler.didHaveMemoryPressure();

        // 3. Fast Forward time (Debounce is 500ms)
        async.elapse(const Duration(milliseconds: 600));

        // 4. Verify Eviction
        // Should be null because critical trim removes ALL inactive entries.
        expect(cache.get('fresh'), isNull);
      });
    });

    test('Debounces memory pressure signals', () {
      fakeAsync((async) {
        // Setup fresh data
        cache.set<String>('fresh', 'fresh-data',
            staleTime: const Duration(hours: 1));

        // Trigger multiple times
        handler.didHaveMemoryPressure();
        async.elapse(const Duration(milliseconds: 100));
        handler.didHaveMemoryPressure();
        async.elapse(const Duration(milliseconds: 100));
        handler.didHaveMemoryPressure();

        // Total time elapsed: 200ms. Debounce is 500ms from FIRST call?
        // Logic: if (_debounceTimer?.isActive ?? false) return;
        // This means it ignores SUBSEQUENT calls until timer fires.
        // So first call starts 500ms timer.
        // 200ms later -> still active, ignored.
        // 500ms total -> fires.

        // Verify still there before 500ms
        async.elapse(const Duration(milliseconds: 200)); // Total 400ms
        expect(cache.get('fresh'), isNotNull);

        // Pass threshold
        async.elapse(const Duration(milliseconds: 200)); // Total 600ms
        expect(cache.get('fresh'), isNull);
      });
    });
  });
}
