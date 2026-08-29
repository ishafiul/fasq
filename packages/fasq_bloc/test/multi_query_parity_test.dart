import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await QueryClient.resetForTesting();
  });

  test('multi-query states have const constructors and structural hashes', () {
    const queryState = QueryState<String>(
      status: QueryStatus.success,
      data: 'value',
      hasValue: true,
    );
    const constListState = MultiQueryState([queryState]);
    const constNamedState = NamedQueryState({'value': queryState});

    final listState = MultiQueryState([queryState]);
    final sameListState = MultiQueryState([queryState]);
    final namedState = NamedQueryState({'value': queryState});
    final sameNamedState = NamedQueryState({'value': queryState});

    expect(constListState, sameListState);
    expect(constNamedState, sameNamedState);
    expect(listState.hashCode, sameListState.hashCode);
    expect(namedState.hashCode, sameNamedState.hashCode);
  });

  testWidgets('MultiQueryBuilder refetches stale cached data', (tester) async {
    final client = QueryClient.create();
    final key = 'bloc:multi-stale'.toQueryKey();
    client.setQueryData(key, 'cached');
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MultiQueryBuilder(
          client: client,
          configs: [
            MultiQueryConfig(
              queryKey: key,
              options: QueryOptions(staleTime: Duration.zero),
              queryFn: () async {
                calls++;
                return 'fresh';
              },
            ),
          ],
          builder: (context, state) =>
              Text(state.getState<String>(0).data ?? 'loading'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('fresh'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await client.dispose();
  });

  testWidgets('NamedMultiQueryBuilder refetches stale cached data', (
    tester,
  ) async {
    final client = QueryClient.create();
    final key = 'bloc:named-multi-stale'.toQueryKey();
    client.setQueryData(key, 'cached');
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: NamedMultiQueryBuilder(
          client: client,
          configs: [
            NamedQueryConfig(
              name: 'value',
              queryKey: key,
              options: QueryOptions(staleTime: Duration.zero),
              queryFn: () async {
                calls++;
                return 'fresh';
              },
            ),
          ],
          builder: (context, state) =>
              Text(state.getState<String>('value').data ?? 'loading'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('fresh'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await client.dispose();
  });
}
