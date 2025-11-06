import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    QueryClient.resetForTesting();
  });

  group('useQuery', () {
    testWidgets('fetches data and updates state', (tester) async {
      Future<String> fetchData() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'test data';
      }

      QueryState<String>? capturedState;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              final state = useQuery('test-key'.toQueryKey(), fetchData);
              capturedState = state;
              return Text(state.data ?? 'loading');
            },
          ),
        ),
      );

      expect(capturedState?.isLoading, true);
      expect(capturedState?.hasData, false);

      await tester.pumpAndSettle();

      expect(capturedState?.hasData, true);
      expect(capturedState?.data, 'test data');
      expect(find.text('test data'), findsOneWidget);
    });

    testWidgets('handles errors correctly', (tester) async {
      Future<String> fetchData() async {
        await Future.delayed(const Duration(milliseconds: 100));
        throw Exception('fetch failed');
      }

      QueryState<String>? capturedState;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              final state = useQuery('test-error'.toQueryKey(), fetchData);
              capturedState = state;

              if (state.hasError) {
                return Text('error: ${state.error}');
              }
              return const Text('loading');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedState?.hasError, true);
      expect(capturedState?.error.toString(), contains('fetch failed'));
      expect(find.textContaining('error:'), findsOneWidget);
    });

    testWidgets('shares query across widgets with same key', (tester) async {
      var fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        await Future.delayed(const Duration(milliseconds: 100));
        return 'shared data';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              HookBuilder(
                builder: (context) {
                  final queryKey = 'shared-key'.toQueryKey();
                  final state = useQuery(queryKey, fetchData);
                  return Text('Widget1: ${state.data ?? "loading"}');
                },
              ),
              HookBuilder(
                builder: (context) {
                  final queryKey = 'shared-key'.toQueryKey();
                  final state = useQuery(queryKey, fetchData);
                  return Text('Widget2: ${state.data ?? "loading"}');
                },
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fetchCount, 1);
      expect(find.text('Widget1: shared data'), findsOneWidget);
      expect(find.text('Widget2: shared data'), findsOneWidget);
    });

    testWidgets('resubscribes when key changes', (tester) async {
      var key = 'key1'.toQueryKey();

      Future<String> fetchData() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data for ${key.key}';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return HookBuilder(
                builder: (context) {
                  final state = useQuery(key, fetchData);

                  return Column(
                    children: [
                      Text(state.data ?? 'loading'),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => key = 'key2'.toQueryKey());
                        },
                        child: const Text('Change Key'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('data for key1'), findsOneWidget);

      await tester.tap(find.text('Change Key'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('data for key2'), findsOneWidget);
    });

    testWidgets('cleans up subscription on disposal', (tester) async {
      Future<String> fetchData() async {
        return 'test data';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              final queryKey = 'disposal-test'.toQueryKey();
              final state = useQuery(queryKey, fetchData);
              return Text(state.data ?? 'loading');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final queryKey = 'disposal-test'.toQueryKey();
      final queryBefore = QueryClient().getQueryByKey(queryKey);
      expect(queryBefore, isNotNull);
      expect(queryBefore?.referenceCount, greaterThan(0));

      await tester.pumpWidget(const MaterialApp(home: Text('empty')));
      await tester.pumpAndSettle();

      await Future.delayed(const Duration(seconds: 6));

      final queryAfter = QueryClient().getQueryByKey(queryKey);
      expect(queryAfter, isNull);
    });
  });
}
