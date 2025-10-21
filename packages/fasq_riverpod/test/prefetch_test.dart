import 'package:fasq/fasq.dart';
import 'package:fasq_riverpod/fasq_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                  onPressed: () => ref.prefetchQuery('test-key', fetchData),
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
                    PrefetchConfig(key: 'test-key-1', queryFn: fetchData1),
                    PrefetchConfig(key: 'test-key-2', queryFn: fetchData2),
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

  group('usePrefetch', () {
    testWidgets('prefetches correctly', (tester) async {
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
                usePrefetch(ref, [
                  PrefetchConfig(key: 'test-key', queryFn: fetchData),
                ]);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.pump();

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

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                usePrefetch(ref, [
                  PrefetchConfig(key: 'test-key-1', queryFn: fetchData1),
                  PrefetchConfig(key: 'test-key-2', queryFn: fetchData2),
                ]);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.pump();

      expect(fetchCount1, equals(1));
      expect(fetchCount2, equals(1));
    });
  });
}
