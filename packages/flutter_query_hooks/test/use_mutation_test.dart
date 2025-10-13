import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query_hooks/flutter_query_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('useMutation', () {
    testWidgets('executes mutation and updates state', (tester) async {
      Future<String> createUser(String name) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'User: $name';
      }

      UseMutationResult<String, String>? capturedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              final mutation = useMutation<String, String>(createUser);
              capturedResult = mutation;

              return ElevatedButton(
                onPressed: () => mutation.mutate('John'),
                child: Text(mutation.data ?? 'Create User'),
              );
            },
          ),
        ),
      );

      expect(capturedResult?.isIdle, true);
      expect(capturedResult?.hasData, false);

      await tester.tap(find.text('Create User'));
      await tester.pump();

      expect(capturedResult?.isLoading, true);

      await tester.pumpAndSettle();

      expect(capturedResult?.hasData, true);
      expect(capturedResult?.data, 'User: John');
      expect(find.text('User: John'), findsOneWidget);
    });

    testWidgets('handles errors correctly', (tester) async {
      Future<String> createUser(String name) async {
        await Future.delayed(const Duration(milliseconds: 100));
        throw Exception('creation failed');
      }

      UseMutationResult<String, String>? capturedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              final mutation = useMutation<String, String>(createUser);
              capturedResult = mutation;

              if (mutation.hasError) {
                return Text('Error: ${mutation.error}');
              }

              return ElevatedButton(
                onPressed: () => mutation.mutate('John'),
                child: const Text('Create User'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Create User'));
      await tester.pump();

      await tester.pumpAndSettle();

      expect(capturedResult?.hasError, true);
      expect(capturedResult?.error.toString(), contains('creation failed'));
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('calls onSuccess callback', (tester) async {
      String? successResult;

      Future<String> createUser(String name) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'User: $name';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              final mutation = useMutation<String, String>(
                createUser,
                onSuccess: (data) {
                  successResult = data;
                },
              );

              return ElevatedButton(
                onPressed: () => mutation.mutate('Alice'),
                child: const Text('Create'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(successResult, 'User: Alice');
    });

    testWidgets('calls onError callback', (tester) async {
      Object? errorResult;

      Future<String> createUser(String name) async {
        await Future.delayed(const Duration(milliseconds: 100));
        throw Exception('creation failed');
      }

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              final mutation = useMutation<String, String>(
                createUser,
                onError: (error) {
                  errorResult = error;
                },
              );

              return ElevatedButton(
                onPressed: () => mutation.mutate('Bob'),
                child: const Text('Create'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(errorResult, isNotNull);
      expect(errorResult.toString(), contains('creation failed'));
    });

    // testWidgets('reset clears mutation state', (tester) async {
    //   Future<String> createUser(String name) async {
    //     await Future.delayed(const Duration(milliseconds: 100));
    //     return 'User: $name';
    //   }
    //
    //   MutationState<String, String>? capturedResult;
    //
    //   await tester.pumpWidget(
    //     MaterialApp(
    //       home: HookBuilder(
    //         builder: (context) {
    //           final mutation = useMutation<String, String>(createUser);
    //           capturedResult = mutation;
    //
    //           return Column(
    //             children: [
    //               ElevatedButton(
    //                 onPressed: () => mutation.mutate('Charlie'),
    //                 child: const Text('Create'),
    //               ),
    //               ElevatedButton(
    //                 onPressed: mutation.reset,
    //                 child: const Text('Reset'),
    //               ),
    //               Text(mutation.data ?? 'no data'),
    //             ],
    //           );
    //         },
    //       ),
    //     ),
    //   );
    //
    //   await tester.tap(find.text('Create'));
    //   await tester.pumpAndSettle();
    //
    //   expect(capturedResult?.hasData, true);
    //   expect(find.text('User: Charlie'), findsOneWidget);
    //
    //   await tester.tap(find.text('Reset'));
    //   await tester.pump();
    //
    //   expect(capturedResult?.isIdle, true);
    //   expect(capturedResult?.hasData, false);
    //   expect(find.text('no data'), findsOneWidget);
    // });
  });
}
