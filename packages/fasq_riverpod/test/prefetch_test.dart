import 'package:fasq_riverpod/fasq_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrefetchExtension', () {
    testWidgets('prefetchQuery works correctly', (tester) async {
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        return 'test-data';
      }

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return ElevatedButton(
                  onPressed: () =>
                      ref.prefetchQuery('test-key'.toQueryKey(), fetchData),
                  child: const Text('Prefetch'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Prefetch'));
      await tester.pump();

      expect(fetchCount, equals(1));
    });

    testWidgets('prefetchQueries works with multiple configs', (tester) async {
      int fetchCount1 = 0;
      int fetchCount2 = 0;

      Future<String> fetchData1() async {
        fetchCount1++;
        return 'test-data-1';
      }

      Future<String> fetchData2() async {
        fetchCount2++;
        return 'test-data-2';
      }

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return ElevatedButton(
                  onPressed: () => ref.prefetchQueries([
                    PrefetchConfig(
                      queryKey: 'test-key-1'.toQueryKey(),
                      queryFn: fetchData1,
                    ),
                    PrefetchConfig(
                      queryKey: 'test-key-2'.toQueryKey(),
                      queryFn: fetchData2,
                    ),
                  ]),
                  child: const Text('Prefetch All'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Prefetch All'));
      await tester.pump();

      expect(fetchCount1, equals(1));
      expect(fetchCount2, equals(1));
    });
  });

  group('Hook-like prefetch', () {
    testWidgets('prefetches correctly via extension', (tester) async {
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        return 'test-data';
      }

      var hasInitialized = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                if (!hasInitialized) {
                  hasInitialized = true;
                  // Use the extension method to prefetch
                  Future.microtask(() => ref.prefetchQuery(
                        'test-key'.toQueryKey(),
                        fetchData,
                      ));
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fetchCount, equals(1));
    });

    testWidgets('multiple configs work in parallel', (tester) async {
      int fetchCount1 = 0;
      int fetchCount2 = 0;

      Future<String> fetchData1() async {
        fetchCount1++;
        return 'test-data-1';
      }

      Future<String> fetchData2() async {
        fetchCount2++;
        return 'test-data-2';
      }

      var hasInitialized = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                if (!hasInitialized) {
                  hasInitialized = true;
                  // Use the extension method to prefetch multiple queries
                  Future.microtask(() => ref.prefetchQueries([
                        PrefetchConfig(
                          queryKey: 'test-key-1'.toQueryKey(),
                          queryFn: fetchData1,
                        ),
                        PrefetchConfig(
                          queryKey: 'test-key-2'.toQueryKey(),
                          queryFn: fetchData2,
                        ),
                      ]));
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fetchCount1, equals(1));
      expect(fetchCount2, equals(1));
    });
  });
}
