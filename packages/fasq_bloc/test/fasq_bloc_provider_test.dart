import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FasqBlocProvider', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await QueryClient.resetForTesting();
    });

    tearDown(() async {
      await QueryClient.resetForTesting();
    });

    testWidgets('provides QueryClient via of() method', (tester) async {
      QueryClient? providedClient;

      await tester.pumpWidget(
        MaterialApp(
          home: FasqBlocProvider(
            child: Builder(
              builder: (context) {
                providedClient = FasqBlocProvider.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(providedClient, isNotNull);
      expect(providedClient, isA<QueryClient>());
    });

    testWidgets('provides QueryClient via maybeOf() method', (tester) async {
      QueryClient? providedClient;

      await tester.pumpWidget(
        MaterialApp(
          home: FasqBlocProvider(
            child: Builder(
              builder: (context) {
                providedClient = FasqBlocProvider.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(providedClient, isNotNull);
      expect(providedClient, isA<QueryClient>());
    });

    testWidgets('maybeOf() returns null when no provider exists',
        (tester) async {
      QueryClient? providedClient;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              providedClient = FasqBlocProvider.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(providedClient, isNull);
    });

    testWidgets('of() throws when no provider exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(
                () => FasqBlocProvider.of(context),
                throwsFlutterError,
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('uses provided QueryClient when passed', (tester) async {
      final customClient = QueryClient();
      QueryClient? providedClient;

      await tester.pumpWidget(
        MaterialApp(
          home: FasqBlocProvider(
            client: customClient,
            child: Builder(
              builder: (context) {
                providedClient = FasqBlocProvider.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(providedClient, same(customClient));
    });

    testWidgets('creates default QueryClient when none provided',
        (tester) async {
      QueryClient? providedClient;

      await tester.pumpWidget(
        MaterialApp(
          home: FasqBlocProvider(
            child: Builder(
              builder: (context) {
                providedClient = FasqBlocProvider.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(providedClient, isNotNull);
      expect(providedClient, isA<QueryClient>());
      expect(providedClient, same(QueryClient.maybeInstance));
    });

    testWidgets('nested providers use innermost client', (tester) async {
      final sharedClient = QueryClient();
      QueryClient? providedClient;

      await tester.pumpWidget(
        MaterialApp(
          home: FasqBlocProvider(
            client: sharedClient,
            child: FasqBlocProvider(
              client: sharedClient,
              child: Builder(
                builder: (context) {
                  providedClient = FasqBlocProvider.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      expect(providedClient, same(sharedClient));
    });

    testWidgets('can be used with BlocProvider', (tester) async {
      QueryClient? providedClient;

      await tester.pumpWidget(
        MaterialApp(
          home: FasqBlocProvider(
            child: BlocProvider(
              create: (context) {
                providedClient = FasqBlocProvider.of(context);
                return TestCubit();
              },
              child: const SizedBox(),
            ),
          ),
        ),
      );

      expect(providedClient, isNotNull);
      expect(providedClient, isA<QueryClient>());
    });
  });
}

class TestCubit extends Cubit<int> {
  TestCubit() : super(0);
}
