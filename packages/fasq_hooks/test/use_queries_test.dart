import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:fasq/fasq.dart';

void main() {
  group('useQueries', () {
    setUp(() {
      QueryClient.resetForTesting();
    });

    testWidgets('executes all queries independently', (tester) async {
      final results = <String>[];

      Future<String> fetchData1() async {
        await Future.delayed(const Duration(milliseconds: 100));
        results.add('data1');
        return 'data1';
      }

      Future<String> fetchData2() async {
        await Future.delayed(const Duration(milliseconds: 50));
        results.add('data2');
        return 'data2';
      }

      Future<String> fetchData3() async {
        await Future.delayed(const Duration(milliseconds: 75));
        results.add('data3');
        return 'data3';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useQueries([
              QueryConfig('query1', fetchData1),
              QueryConfig('query2', fetchData2),
              QueryConfig('query3', fetchData3),
            ]);

            return Column(
              children: queries
                  .map((q) => Text(q.data?.toString() ?? 'loading'))
                  .toList(),
            );
          },
        ),
      );

      // Wait for all queries to complete
      await tester.pumpAndSettle();

      // Verify all queries executed
      expect(results, contains('data1'));
      expect(results, contains('data2'));
      expect(results, contains('data3'));

      // Verify final states
      // Note: In real usage, we'd access the hook state differently
      expect(find.text('data1'), findsOneWidget);
      expect(find.text('data2'), findsOneWidget);
      expect(find.text('data3'), findsOneWidget);
    });

    testWidgets('handles config changes correctly', (tester) async {
      bool useSecondConfig = false;

      Future<String> fetchData1() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data1';
      }

      Future<String> fetchData2() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data2';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final configs = useSecondConfig
                ? [
                    QueryConfig('query1', fetchData1),
                    QueryConfig('query2', fetchData2)
                  ]
                : [QueryConfig('query1', fetchData1)];

            final queries = useQueries(configs);

            return Column(
              children: queries
                  .map((q) => Text(q.data?.toString() ?? 'loading'))
                  .toList(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Change config
      useSecondConfig = true;
      await tester.pump();
      await tester.pumpAndSettle();

      // Should have 2 queries now
      expect(find.text('data1'), findsOneWidget);
      expect(find.text('data2'), findsOneWidget);
    });

    testWidgets('handles errors independently', (tester) async {
      Future<String> fetchSuccess() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'success';
      }

      Future<String> fetchError() async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw Exception('Test error');
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useQueries([
              QueryConfig('success', fetchSuccess),
              QueryConfig('error', fetchError),
            ]);

            return Column(
              children: [
                Text(queries[0].hasError
                    ? 'error'
                    : queries[0].data?.toString() ?? 'loading'),
                Text(queries[1].hasError
                    ? 'error'
                    : queries[1].data?.toString() ?? 'loading'),
              ],
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // First query should succeed, second should fail
      expect(find.text('success'), findsOneWidget);
      expect(find.text('error'), findsOneWidget);
    });

    testWidgets('properly cleans up on unmount', (tester) async {
      Future<String> fetchData(String key) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'data';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useQueries([
              QueryConfig('query1', () => fetchData('query1')),
              QueryConfig('query2', () => fetchData('query2')),
            ]);

            return Column(
              children: queries
                  .map((q) => Text(q.data?.toString() ?? 'loading'))
                  .toList(),
            );
          },
        ),
      );

      await tester.pumpAndSettle();

      // Unmount widget
      await tester.pumpWidget(const SizedBox());

      // Wait a bit to ensure cleanup happens
      await tester.pump(const Duration(milliseconds: 200));

      // Verify queries are cleaned up (no memory leaks)
      final client = QueryClient();
      expect(client.hasQuery('query1'), isFalse);
      expect(client.hasQuery('query2'), isFalse);
    });

    testWidgets('updates states independently', (tester) async {
      int updateCount = 0;

      Future<String> fetchData1() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'data1';
      }

      Future<String> fetchData2() async {
        await Future.delayed(const Duration(milliseconds: 200));
        return 'data2';
      }

      await tester.pumpWidget(
        HookBuilder(
          builder: (context) {
            final queries = useQueries([
              QueryConfig('query1', fetchData1),
              QueryConfig('query2', fetchData2),
            ]);

            updateCount++;

            return Column(
              children: queries
                  .map((q) => Text(q.data?.toString() ?? 'loading'))
                  .toList(),
            );
          },
        ),
      );

      // Should rebuild as queries complete independently
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('data1'), findsOneWidget);
      expect(find.text('loading'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('data1'), findsOneWidget);
      expect(find.text('data2'), findsOneWidget);

      // Should have rebuilt multiple times as states updated
      expect(updateCount, greaterThan(1));
    });
  });
}
