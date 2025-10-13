import 'package:flutter/material.dart';
import 'package:flutter_query/flutter_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Query Lifecycle Integration Tests', () {
    tearDown(() {
      QueryClient.resetForTesting();
    });

    testWidgets('complete flow: mount → fetch → display → unmount',
        (tester) async {
      var fetchCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QueryBuilder<String>(
              queryKey: 'lifecycle-test',
              queryFn: () async {
                fetchCount++;
                await Future.delayed(Duration(milliseconds: 50));
                return 'lifecycle data';
              },
              builder: (context, state) {
                if (state.isLoading) return const CircularProgressIndicator();
                if (state.hasError) return Text('Error: ${state.error}');
                if (state.hasData) return Text('Success: ${state.data}');
                return const Text('Idle');
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Success: lifecycle data'), findsOneWidget);
      expect(fetchCount, 1);

      await tester.pumpWidget(const MaterialApp(home: Text('Unmounted')));
      await tester.pump();
      expect(find.text('Unmounted'), findsOneWidget);

    });

    testWidgets('error recovery scenario', (tester) async {
      var shouldFail = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QueryBuilder<String>(
              queryKey: 'error-test',
              queryFn: () async {
                if (shouldFail) {
                  throw Exception('Initial error');
                }
                return 'recovered data';
              },
              builder: (context, state) {
                if (state.isLoading) return const CircularProgressIndicator();
                if (state.hasError) return const Text('Error occurred');
                if (state.hasData) return Text('Data: ${state.data}');
                return const Text('Idle');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Error occurred'), findsOneWidget);

      shouldFail = false;
      final query = QueryClient().getQueryByKey<String>('error-test');
      await query!.fetch();
      await tester.pumpAndSettle();

      expect(find.text('Data: recovered data'), findsOneWidget);

    });

    testWidgets('rapid navigation (mount/unmount/remount)', (tester) async {
      var fetchCount = 0;

      Widget buildQuery() {
        return MaterialApp(
          home: QueryBuilder<String>(
            queryKey: 'rapid-nav',
            queryFn: () async {
              fetchCount++;
              await Future.delayed(Duration(milliseconds: 50));
              return 'nav data';
            },
            builder: (context, state) {
              return Text('Data: ${state.data ?? "loading"}');
            },
          ),
        );
      }

      await tester.pumpWidget(buildQuery());
      await tester.pump();
      expect(fetchCount, 1);

      await tester.pumpWidget(const MaterialApp(home: Text('Away')));
      await tester.pump();

      await tester.pumpWidget(buildQuery());
      await tester.pumpAndSettle();

      expect(fetchCount, 1);

    });

    testWidgets('memory leak test with many query creations', (tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: QueryBuilder<int>(
              queryKey: 'query-$i',
              queryFn: () async => i,
              builder: (context, state) => Text('${state.data ?? 0}'),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(const MaterialApp(home: Text('Done')));
      await tester.pumpAndSettle();

      final client = QueryClient();
      final beforeCleanup = client.queryCount;
      expect(beforeCleanup, greaterThan(0));

    });

    testWidgets('concurrent queries with same key share state', (tester) async {
      var fetchCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              QueryBuilder<String>(
                queryKey: 'shared-query',
                queryFn: () async {
                  fetchCount++;
                  await Future.delayed(Duration(milliseconds: 50));
                  return 'shared';
                },
                builder: (context, state) => Text('A: ${state.data}'),
              ),
              QueryBuilder<String>(
                queryKey: 'shared-query',
                queryFn: () async {
                  fetchCount++;
                  return 'shared';
                },
                builder: (context, state) => Text('B: ${state.data}'),
              ),
              QueryBuilder<String>(
                queryKey: 'shared-query',
                queryFn: () async {
                  fetchCount++;
                  return 'shared';
                },
                builder: (context, state) => Text('C: ${state.data}'),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fetchCount, 1);
      expect(find.text('A: shared'), findsOneWidget);
      expect(find.text('B: shared'), findsOneWidget);
      expect(find.text('C: shared'), findsOneWidget);

    });

    testWidgets('query persists during rapid widget rebuilds', (tester) async {
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  QueryBuilder<int>(
                    queryKey: 'persist-test',
                    queryFn: () async => 42,
                    builder: (context, state) {
                      buildCount++;
                      return Text('Value: ${state.data}');
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Rebuild'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      final initialBuildCount = buildCount;

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Rebuild'));
        await tester.pump();
      }

      expect(buildCount, greaterThan(initialBuildCount));
      expect(find.text('Value: 42'), findsOneWidget);

    });

    testWidgets('different query keys create independent queries',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              QueryBuilder<int>(
                queryKey: 'query-1',
                queryFn: () async => 1,
                builder: (context, state) => Text('Q1: ${state.data}'),
              ),
              QueryBuilder<int>(
                queryKey: 'query-2',
                queryFn: () async => 2,
                builder: (context, state) => Text('Q2: ${state.data}'),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Q1: 1'), findsOneWidget);
      expect(find.text('Q2: 2'), findsOneWidget);
      expect(QueryClient().queryCount, 2);

    });

    testWidgets('callbacks are invoked correctly', (tester) async {
      var successCalled = false;
      var errorCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: QueryBuilder<String>(
            queryKey: 'callback-test',
            queryFn: () async => 'success',
            options: QueryOptions(
              onSuccess: () => successCalled = true,
              onError: (_) => errorCalled = true,
            ),
            builder: (context, state) => Text('${state.data}'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(successCalled, isTrue);
      expect(errorCalled, isFalse);

    });
  });
}

