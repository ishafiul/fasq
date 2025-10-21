import 'package:fasq/fasq.dart';
import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('usePrefetchQuery', () {
    testWidgets('returns stable callback', (tester) async {
      late void Function(String, Future<String> Function(), {QueryOptions? options}) prefetch1;
      late void Function(String, Future<String> Function(), {QueryOptions? options}) prefetch2;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              prefetch1 = usePrefetchQuery<String>();
              prefetch2 = usePrefetchQuery<String>();
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();

      expect(prefetch1, equals(prefetch2));
    });

    testWidgets('prefetch callback works correctly', (tester) async {
      late void Function(String, Future<String> Function(), {QueryOptions? options}) prefetch;
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        return 'test-data';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              prefetch = usePrefetchQuery<String>();
              return const SizedBox();
            },
          ),
        ),
      );

      prefetch('test-key', fetchData);
      await tester.pump();

      expect(fetchCount, equals(1));
    });
  });

  group('usePrefetchOnMount', () {
    testWidgets('prefetches on mount', (tester) async {
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        return 'test-data';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              usePrefetchOnMount([
                PrefetchConfig(key: 'test-key', queryFn: fetchData),
              ]);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();

      expect(fetchCount, equals(1));
    });

    testWidgets('multiple configs prefetch in parallel', (tester) async {
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
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              usePrefetchOnMount([
                PrefetchConfig(key: 'test-key-1', queryFn: fetchData1),
                PrefetchConfig(key: 'test-key-2', queryFn: fetchData2),
              ]);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();

      expect(fetchCount1, equals(1));
      expect(fetchCount2, equals(1));
    });

    testWidgets('does not prefetch on rebuild', (tester) async {
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        return 'test-data';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              usePrefetchOnMount([
                PrefetchConfig(key: 'test-key', queryFn: fetchData),
              ]);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(fetchCount, equals(1));
    });
  });
}
