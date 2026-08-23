import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Query.disposalDelay = Duration.zero;
    QueryCache.gcInterval = Duration.zero;
  });
  tearDown(() async => QueryClient.resetForTesting());

  testWidgets('returns rich results for parallel queries', (tester) async {
    List<UseQueryResult<dynamic>>? results;
    await tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            final fetchOne = useCallback<Future<String> Function()>(
              () async => 'one',
              const [],
            );
            final fetchTwo = useCallback<Future<int> Function()>(
              () async => 2,
              const [],
            );
            results = useQueries([
              QueryConfig<String>('one'.toQueryKey(), fetchOne),
              QueryConfig<int>('two'.toQueryKey(), fetchTwo),
            ]);
            return Text(
              results!.map((result) => result.data?.toString() ?? '').join(','),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(results!.map((result) => result.data).toList(), ['one', 2]);
  });

  testWidgets('reconciles named query changes with the same length', (
    tester,
  ) async {
    var useSecond = false;
    Map<String, UseQueryResult<dynamic>>? results;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => HookBuilder(
            builder: (context) {
              final fetch = useCallback<Future<String> Function()>(
                () async => useSecond ? 'second' : 'first',
                [useSecond],
              );
              results = useNamedQueries([
                NamedQueryConfig<String>(
                  name: 'primary',
                  queryKey: (useSecond ? 'second' : 'first').toQueryKey(),
                  queryFn: fetch,
                ),
              ]);
              return ElevatedButton(
                onPressed: () => setState(() => useSecond = true),
                child: Text(results!['primary']?.data?.toString() ?? 'load'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(results!['primary']!.data, 'first');
    await tester.tap(find.text('first'));
    await tester.pumpAndSettle();
    expect(results!['primary']!.data, 'second');
  });
}
