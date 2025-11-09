import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueryBuilder', () {
    tearDown(() async {
      await QueryClient.resetForTesting();
    });

    testWidgets('fetches and displays data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QueryBuilder<String>(
            queryKey: 'test'.toQueryKey(),
            queryFn: () async {
              await Future.delayed(Duration(milliseconds: 50));
              return 'test data';
            },
            builder: (context, state) {
              if (state.hasData) return Text('Data: ${state.data}');
              return const Text('Loading');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Data: test data'), findsOneWidget);
    });

    testWidgets('shows loading state during fetch', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QueryBuilder<String>(
            queryKey: 'test'.toQueryKey(),
            queryFn: () async {
              await Future.delayed(Duration(milliseconds: 100));
              return 'data';
            },
            builder: (context, state) {
              if (state.isLoading) return const Text('Loading');
              return Text('Data: ${state.data}');
            },
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Loading'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('shows success state with data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QueryBuilder<String>(
            queryKey: 'test'.toQueryKey(),
            queryFn: () async {
              await Future.delayed(Duration(milliseconds: 10));
              return 'success data';
            },
            builder: (context, state) {
              if (state.hasData) return Text('Data: ${state.data}');
              return const Text('Loading or Idle');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Data: success data'), findsOneWidget);

      QueryClient().clear();
    });

    testWidgets('shows error state on fetch failure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QueryBuilder<String>(
            queryKey: 'test'.toQueryKey(),
            queryFn: () async {
              await Future.delayed(Duration(milliseconds: 10));
              throw Exception('test error');
            },
            builder: (context, state) {
              if (state.hasError) return Text('Error: ${state.error}');
              return const Text('Loading or Idle');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Error:'), findsOneWidget);

      QueryClient().clear();
    });

    testWidgets('multiple widgets share same query', (tester) async {
      var fetchCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              QueryBuilder<String>(
                queryKey: 'shared'.toQueryKey(),
                queryFn: () async {
                  fetchCount++;
                  return 'shared data';
                },
                builder: (context, state) {
                  return Text('Widget 1: ${state.data ?? "loading"}');
                },
              ),
              QueryBuilder<String>(
                queryKey: 'shared'.toQueryKey(),
                queryFn: () async {
                  fetchCount++;
                  return 'shared data';
                },
                builder: (context, state) {
                  return Text('Widget 2: ${state.data ?? "loading"}');
                },
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fetchCount, 1);
      expect(find.text('Widget 1: shared data'), findsOneWidget);
      expect(find.text('Widget 2: shared data'), findsOneWidget);

      QueryClient().clear();
    });

    testWidgets('disposes subscription on widget disposal', (tester) async {
      final query = QueryClient().getQuery<String>(
        'test'.toQueryKey(),
        () async => 'data',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: QueryBuilder<String>(
            queryKey: 'test'.toQueryKey(),
            queryFn: () async => 'data',
            builder: (context, state) => Text('Data: ${state.data}'),
          ),
        ),
      );

      await tester.pump();
      expect(query.referenceCount, 1);

      await tester.pumpWidget(const MaterialApp(home: Text('Empty')));
      await tester.pump();

      expect(query.referenceCount, 0);
    });

    testWidgets('respects enabled option', (tester) async {
      var fetchCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: QueryBuilder<String>(
            queryKey: 'test'.toQueryKey(),
            queryFn: () async {
              fetchCount++;
              return 'data';
            },
            options: QueryOptions(enabled: false),
            builder: (context, state) {
              return Text('Status: ${state.status}');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fetchCount, 0);
      expect(find.text('Status: QueryStatus.idle'), findsOneWidget);

      QueryClient().clear();
    });

    testWidgets('rebuilds on state changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QueryBuilder<int>(
            queryKey: 'counter'.toQueryKey(),
            queryFn: () async {
              await Future.delayed(Duration(milliseconds: 50));
              return 42;
            },
            builder: (context, state) {
              if (state.isLoading) {
                return const CircularProgressIndicator();
              }
              if (state.hasData) {
                return Text('Count: ${state.data}');
              }
              return const Text('Idle');
            },
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Count: 42'), findsOneWidget);

      QueryClient().clear();
    });

    testWidgets('handles hot reload gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: QueryBuilder<String>(
            queryKey: 'test'.toQueryKey(),
            queryFn: () async => 'data',
            builder: (context, state) => Text('Data: ${state.data}'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Data: data'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: QueryBuilder<String>(
            queryKey: 'test'.toQueryKey(),
            queryFn: () async => 'data',
            builder: (context, state) => Text('Data: ${state.data}'),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Data: data'), findsOneWidget);

      QueryClient().clear();
    });
  });
}
