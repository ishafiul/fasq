import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Query.disposalDelay = Duration.zero;
    QueryCache.gcInterval = Duration.zero;
  });

  tearDown(() async {
    Query.disposalDelay = const Duration(seconds: 5);
    await QueryClient.resetForTesting();
  });

  testWidgets('returns state and query commands', (tester) async {
    var calls = 0;
    UseQueryResult<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            final fetch = useCallback<Future<String> Function()>(() async {
              calls++;
              return 'hello $calls';
            }, const []);
            result = useQuery<String>('greeting'.toQueryKey(), queryFn: fetch);
            return Text(result!.data ?? 'loading');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(result!.data, 'hello 1');
    expect(result!.isSuccess, isTrue);

    result!.setData('manual');
    await tester.pumpAndSettle();
    expect(result!.data, 'manual');

    await result!.refetch();
    await tester.pump();
    expect(result!.data, 'hello 2');
  });

  testWidgets('supports token fetchers and dependency keys', (tester) async {
    UseQueryResult<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            final fetch =
                useCallback<Future<String> Function(CancellationToken token)>((
                  receivedToken,
                ) async {
                  expect(receivedToken, isA<CancellationToken>());
                  return 'token-result';
                }, const []);
            result = useQuery<String>(
              'child'.toQueryKey(),
              queryFnWithToken: fetch,
              dependsOn: 'parent'.toQueryKey(),
            );
            return Text(result!.data ?? 'loading');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(result!.data, 'token-result');
  });

  testWidgets('reconfigures the same query instance', (tester) async {
    var version = 1;
    UseQueryResult<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => HookBuilder(
            builder: (context) {
              final fetch = useCallback<Future<String> Function()>(
                () async => 'version $version',
                [version],
              );
              result = useQuery<String>(
                'versioned'.toQueryKey(),
                queryFn: fetch,
              );
              return Column(
                children: [
                  Text(result!.data ?? 'loading'),
                  ElevatedButton(
                    onPressed: () => setState(() => version = 2),
                    child: const Text('change'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final query = result!.query;
    expect(result!.data, 'version 1');

    await tester.tap(find.text('change'));
    await tester.pumpAndSettle();

    expect(identical(result!.query, query), isTrue);
    expect(result!.data, 'version 2');
  });

  testWidgets('cancels and removes a query', (tester) async {
    UseQueryResult<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            final fetch = useCallback<Future<String> Function()>(
              () async => 'data',
              const [],
            );
            result = useQuery<String>('remove-me'.toQueryKey(), queryFn: fetch);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    result!.cancel();
    result!.remove();
    expect(result!.client.hasQuery('remove-me'.toQueryKey()), isFalse);
  });
}
