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

    testWidgets('maybeOf() returns null when no provider exists', (
      tester,
    ) async {
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
              expect(() => FasqBlocProvider.of(context), throwsFlutterError);
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

    testWidgets('bridges an existing FasqRuntime to core context', (
      tester,
    ) async {
      final runtime = _TestRuntime(QueryClient.create());
      FasqRuntime? providedRuntime;
      QueryClient? adapterClient;
      QueryClient? contextClient;
      FasqRuntime? repositoryRuntime;

      await tester.pumpWidget(
        MaterialApp(
          home: FasqBlocProvider(
            runtime: runtime,
            child: Builder(
              builder: (context) {
                providedRuntime = FasqBlocProvider.runtimeOf(context);
                adapterClient = FasqBlocProvider.of(context);
                contextClient = context.queryClient;
                repositoryRuntime = context.read<FasqRuntime>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(providedRuntime, same(runtime));
      expect(adapterClient, same(runtime.queryClient));
      expect(contextClient, same(runtime.queryClient));
      expect(repositoryRuntime, same(runtime));

      await tester.pumpWidget(const SizedBox());
      await runtime.close();
    });

    testWidgets('exposes its client through flutter_bloc context', (
      tester,
    ) async {
      final client = QueryClient.create();
      QueryClient? repositoryClient;

      await tester.pumpWidget(
        MaterialApp(
          home: FasqBlocProvider(
            client: client,
            child: Builder(
              builder: (context) {
                repositoryClient = context.read<QueryClient>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(repositoryClient, same(client));

      await tester.pumpWidget(const SizedBox());
      await client.dispose();
    });

    testWidgets('supports core QueryClient configuration', (tester) async {
      QueryClient? providedClient;
      const config = CacheConfig(defaultStaleTime: Duration(minutes: 5));

      await tester.pumpWidget(
        MaterialApp(
          home: FasqBlocProvider(
            config: config,
            child: Builder(
              builder: (context) {
                providedClient = context.read<QueryClient>();
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(
        providedClient?.cache.config.defaultStaleTime,
        config.defaultStaleTime,
      );
    });

    testWidgets('creates default QueryClient when none provided', (
      tester,
    ) async {
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
              child: Builder(
                builder: (context) {
                  context.read<TestCubit>();
                  return const SizedBox();
                },
              ),
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

class _TestRuntime implements FasqRuntime {
  _TestRuntime(this.queryClient) : mutations = DurableMutationCatalog(const []);

  @override
  final QueryClient queryClient;

  @override
  final DurableMutationCatalog mutations;

  @override
  DurableMutationQueue? get mutationQueue => null;

  @override
  Future<void> close() => queryClient.dispose();
}
