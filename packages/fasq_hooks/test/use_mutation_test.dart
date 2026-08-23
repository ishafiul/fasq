import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => QueryCache.gcInterval = Duration.zero);
  tearDown(() async {
    await QueryClient.resetForTesting();
  });

  testWidgets('returns submission and updates mutation state', (tester) async {
    UseMutationResult<String, String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            result = useMutation<String, String>(
              mutationFn: (name) async => 'User: $name',
            );
            return ElevatedButton(
              onPressed: () => result!.mutate('Ada'),
              child: Text(result!.data ?? 'create'),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await result!.mutate('Ada');
    await tester.pump();
    await tester.pump();

    expect(result!.isSuccess, isTrue);
    expect(result!.data, 'User: Ada');
    final submission = await result!.submit('Grace');
    expect(submission.isSucceeded, isTrue);
    expect(submission.data, 'User: Grace');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('preserves callbacks and stack traces', (tester) async {
    Object? callbackError;
    UseMutationResult<String, String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            result = useMutation<String, String>(
              mutationFn: (_) async => throw StateError('failed'),
              onError: (error) => callbackError = error,
            );
            return ElevatedButton(
              onPressed: () => result!.mutate('x'),
              child: const Text('fail'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('fail'));
    await tester.pumpAndSettle();

    expect(result!.isError, isTrue);
    expect(result!.stackTrace, isNotNull);
    expect(callbackError, isA<StateError>());
    result!.reset();
    expect(result!.mutation.state.isIdle, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
