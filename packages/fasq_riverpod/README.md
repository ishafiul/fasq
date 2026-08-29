# fasq_riverpod

[![Pub Version](https://img.shields.io/pub/v/fasq_riverpod?style=flat-square)](https://pub.dev/packages/fasq_riverpod)
[![Repository](https://img.shields.io/badge/repository-GitHub-181717?style=flat-square)](https://github.com/ishafiul/fasq)
[![Issues](https://img.shields.io/github/issues/ishafiul/fasq?style=flat-square)](https://github.com/ishafiul/fasq/issues)

> **Riverpod adapter for FASQ (Flutter Async State Query).**

Seamlessly integrate FASQ's powerful caching and async management into your Riverpod application.

**Current Version:** 0.4.0+1

## 📚 Documentation

For full documentation and API reference, visit:  
**[https://shafi.dev/fasq/riverpod](https://shafi.dev/fasq/riverpod)**

## ✨ Features

- **🔌 queryProvider**: Create type-safe query providers.
- **♾️ infiniteQueryProvider**: Paginated lists with Riverpod.
- **⚡ queriesProvider / namedQueriesProvider**: Execute parallel query sets.
- **🔄 mutationProvider**: Handle immediate or typed durable server side-effects.
- **📬 mutationQueueProvider**: Observe, replay, repair, and project durable work.
- **🔀 combineQueries**: Merge multiple `AsyncValue` providers into one state.
- **⚡ Riverpod Integration**: Works with `ref.watch`, `ConsumerWidget`, and
  explicit `ProviderContainer` scopes.

## 📦 Installation

```yaml
dependencies:
  fasq_riverpod: ^0.4.0+1
```

## 🚀 Quick Start

### 1. Define a Provider

Create a `queryProvider` for your data source.

```dart
final usersProvider = queryProvider<List<User>>(
  'users'.toQueryKey(),
  () => api.fetchUsers(),
  options: QueryOptions(
    staleTime: Duration(minutes: 5),
  ),
);
```

### 2. Watch in Widget

Use `ConsumerWidget` or `Consumer` to listen to the provider.

```dart
class UsersScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usersProvider);
    
    if (state.isLoading) return CircularProgressIndicator();
    if (state.hasError) return Text('Error: ${state.error}');
    
    return ListView.builder(
      itemCount: state.data!.length,
      itemBuilder: (context, index) => Text(state.data![index].name),
    );
  }
}
```

### 3. Mutations

Use `mutationProvider` for actions.

```dart
final createUserProvider = mutationProvider<User, String>(
  (name) => api.createUser(name),
);
```

After the submission completes, use the same scoped client to invalidate
related queries:

```dart
final receipt = await ref.read(createUserProvider.notifier).submit('Ada');
if (receipt.isSucceeded) {
  ref.read(fasqClientProvider).invalidateQuery('users'.toQueryKey());
}
```

## 🧩 Advanced Features

- **Parameterized Queries**: include parameters in a typed `QueryKey`, then
  create one provider per parameterized key (or use the core `QueryClient`
  registry directly).
- **Parallel Queries**: use `queriesProvider` with `QueryConfig` or
  `namedQueriesProvider` with `NamedQueryConfig`; use `combineQueries` when
  the inputs are already Riverpod providers.
- **Prefetching**: `ref.prefetchQuery`.
- **Dependent Queries**: use core `dependsOn: parentKey`, or compose a child
  provider from another Riverpod provider when its key depends on Riverpod
  state.

`QueryNotifier` exposes the underlying core query through `query`, `queryClient`,
and `ready`, plus `refetch`, `invalidate`, `cancel`, `setData`,
`updateFromCache`, `remove`, `updateOptions`, `metrics`, and `debugInfo`.
`InfiniteQueryNotifier` additionally exposes next/previous page fetches, page
refetch, reset, invalidation, page restoration, and pagination flags.

The adapter's public surface is:

- `queryProvider` and `queryProviderWithToken` for ordinary and
  cancellation-aware queries.
- `infiniteQueryProvider` for page-based data.
- `queriesProvider` / `namedQueriesProvider` for owned parallel query sets.
- `combineQueries` / `combineNamedQueries` for composing existing
  `AsyncValue` providers.
- `mutationProvider` / `durableMutationProvider` for immediate or typed
  durable mutations.
- `mutationQueueProvider` for redacted queue observation plus replay,
  projection, history, and repair commands.
- `PrefetchExtension` for `WidgetRef.prefetchQuery` and
  `WidgetRef.prefetchQueries`.

For an application-owned runtime, override the provider once:

```dart
ProviderScope(
  overrides: [fasqRuntimeProvider.overrideWithValue(runtime)],
  child: const App(),
);
```

The runtime's `QueryClient` and durable queue are borrowed. With no runtime
override, `fasqClientProvider` creates an isolated client per container and
disposes it with that container.

Durable mutations can be created from a typed core contract:

```dart
final saveProvider = mutationProvider<SaveResult, SaveInput>(
  null,
  mutationKey: saveMutationKey,
);

final receipt = await ref.read(saveProvider.notifier).submit(input);
```

The receipt preserves queued/succeeded/failed status and its opaque local
reference. Use `mutationQueueProvider` for redacted queue observations and
the full replay, projection, history, and repair commands.

The adapter re-exports all public `fasq` APIs, so cache inspection, persistence,
security, circuit breakers, metrics, observers, and durable contracts remain
available through the same import. See the [durable mutation documentation](https://shafi.dev/fasq/core/essentials/durable-mutations).

When an application supplies a `FasqRuntime`, the adapter borrows its client
and durable queue. Without a runtime override, `fasqClientProvider` creates an
isolated `QueryClient` per `ProviderContainer` and disposes it with that
container.

See the [main documentation](https://shafi.dev/fasq) for more.

## 🔗 Repository Links

- [Source repository](https://github.com/ishafiul/fasq)
- [Issue tracker](https://github.com/ishafiul/fasq/issues)
- [Pull requests](https://github.com/ishafiul/fasq/pulls)

## 📄 License

MIT
