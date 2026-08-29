# fasq_bloc

[![Pub](https://img.shields.io/pub/v/fasq_bloc.svg)](https://pub.dev/packages/fasq_bloc)
[![Repository](https://img.shields.io/badge/repository-GitHub-181717?style=flat-square)](https://github.com/ishafiul/fasq)
[![Issues](https://img.shields.io/github/issues/ishafiul/fasq?style=flat-square)](https://github.com/ishafiul/fasq/issues)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)]()

> The native Bloc adapter for FASQ.

`fasq_bloc` connects FASQ's shared cache, query lifecycle, optimistic updates,
pagination, persistence, and durable mutations to `Cubit` and Flutter widgets.
The package also re-exports `fasq`, so all public core types remain available
from one import.

**Current Version:** 0.4.1

## Documentation

Full guides and API reference: [shafi.dev/fasq/bloc](https://shafi.dev/fasq/bloc)

## Installation

```yaml
dependencies:
  fasq_bloc: ^0.4.1
  flutter_bloc: ^8.0.0
```

## Quick start

Pass an existing client when creating cubits. `FasqBlocProvider` exposes the
same client to core widgets, `context.read<QueryClient>()`, and static lookup
helpers.

```dart
final client = QueryClient.create();

runApp(
  FasqBlocProvider(
    client: client,
    child: MyApp(),
  ),
);
```

The provider borrows an explicitly supplied client and owns only a default
client that it creates itself. A bootstrapped runtime can be supplied instead:

```dart
FasqBlocProvider(
  runtime: runtime,
  child: MyApp(),
)
```

For an owned configured scope, use the same configuration fields as the core
provider:

```dart
FasqBlocProvider(
  config: CacheConfig(defaultStaleTime: const Duration(minutes: 5)),
  child: MyApp(),
)
```

Runtime-backed scopes also expose `context.read<FasqRuntime>()`. Cubits created
by `BlocProvider` should receive the client or runtime explicitly, for example
with `FasqBlocProvider.of(context)`.

### QueryCubit

```dart
class UserCubit extends QueryCubit<User> {
  UserCubit(this.userId, QueryClient client) : super(client: client);

  final int userId;

  @override
  QueryKey get queryKey => 'user:$userId'.toQueryKey();

  @override
  Future<User> Function() get queryFn => () => api.fetchUser(userId);
}

BlocProvider(
  create: (context) => UserCubit(
    42,
    FasqBlocProvider.of(context),
  ),
  child: UserScreen(),
)
```

`QueryCubit` supports ordinary or cancellation-aware query functions,
`dependsOn`, every `QueryOptions` feature, `ready`, `refetch`, `invalidate`,
`cancel`, `setData`, `remove`, metrics, debug information, and live
`updateOptions` reconfiguration. The underlying core query is available as
`cubit.query`.

```dart
@override
Future<User> Function(CancellationToken token)? get queryFnWithToken =>
    (token) => api.fetchUser(userId, token: token);

@override
QueryKey? get dependsOn => sessionQueryKey;
```

### InfiniteQueryCubit

`InfiniteQueryCubit<TData, TParam>` exposes `fetchNextPage`,
`fetchPreviousPage`, `refetchPage`, `reset`, `updateFromCache`, `invalidate`,
`remove`, and live reconfiguration while preserving the core pagination state.
It also exposes `hasNextPage`, `hasPreviousPage`, `isFetchingNextPage`, and
`isFetchingPreviousPage` helpers.

### MutationCubit

Ordinary mutations return the core `MutationSubmission`, including a durable
local reference when the supplied options queue work offline.

```dart
class AddTodoCubit extends MutationCubit<Todo, String> {
  AddTodoCubit(QueryClient client) : super(client: client);

  @override
  Future<Todo> Function(String text) get mutationFn => api.addTodo;
}

final submission = await context.read<AddTodoCubit>().submit('Buy milk');
```

For a generated durable mutation, pass the bootstrapped runtime and expose its
typed key:

```dart
class CreateTodoCubit extends MutationCubit<Todo, CreateTodoInput> {
  CreateTodoCubit(FasqRuntime runtime) : super(runtime: runtime);

  @override
  FasqMutationKey<Todo, CreateTodoInput> get mutationKey =>
      createTodoMutationKey;
}
```

The runtime must contain the matching catalog entry and durable queue. All
core `MutationOptions` behavior remains available, including
`queueWhenOffline`, write-ahead execution, projections, dependencies, retry,
auth, and lifecycle callbacks.

### Durable queue in Bloc

`MutationQueueCubit` gives the durable queue a reactive Bloc state while
forwarding replay, observation, projection, and repair commands to the core
queue:

```dart
BlocProvider(
  create: (_) => MutationQueueCubit(runtime: runtime),
  child: QueueStatusScreen(),
)

BlocBuilder<MutationQueueCubit, DurableQueueObservation>(
  builder: (context, observation) => Text(
    'Pending: ${observation.operations.length}',
  ),
)
```

The cubit borrows the queue; close the runtime separately.

The queue adapter also forwards `open`, `closeQueue`, `register`, `enqueue`,
`watch`, retention checks, scoped aggregate state, operation lookup/history,
and every core replay, projection, and repair command. The underlying
`queue` remains available for direct core composition.

## Widgets and composition

- `MultiQueryBuilder` and `NamedMultiQueryBuilder` observe heterogeneous query
  sets, including token-aware functions and dependencies.
- `PrefetchQueryCubit` and `PrefetchBuilder` prefetch one or many queries using
  an explicit or inherited client.
- `FasqSubscriptionMixin` manages query subscriptions and their reference
  counts, and releases them when the Bloc closes.

```dart
class DashboardCubit extends Cubit<DashboardState>
    with FasqSubscriptionMixin<DashboardState> {
  DashboardCubit(QueryClient client) : super(DashboardState.loading()) {
    final users = client.getQuery<List<User>>(
      'users'.toQueryKey(),
      queryFn: api.fetchUsers,
    );
    subscribeToQuery(users, (state) {
      if (!isClosed) emit(this.state.copyWith(users: state.data));
    });
  }
}
```

## Core API

The entrypoint re-exports `package:fasq/fasq.dart`. You can therefore use
FASQ's cache, `QueryClient`, core providers/builders, circuit breakers,
metrics, persistence/security types, pagination models, mutation contracts,
and durable sync-engine APIs alongside the Bloc adapters.

## Links

- [Source repository](https://github.com/ishafiul/fasq)
- [Issue tracker](https://github.com/ishafiul/fasq/issues)
- [Pull requests](https://github.com/ishafiul/fasq/pulls)
