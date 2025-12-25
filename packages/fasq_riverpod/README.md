# fasq_riverpod

> **Riverpod adapter for FASQ (Flutter Async State Query).**

Seamlessly integrate FASQ's powerful caching and async management into your Riverpod application.

**Current Version:** 0.2.4+1

## 📚 Documentation

For full documentation and API reference, visit:  
**[https://fasq.shafi.dev/adapters/riverpod](https://fasq.shafi.dev/adapters/riverpod)**

## ✨ Features

- **🔌 queryProvider**: Create type-safe query providers.
- **♾️ infiniteQueryProvider**: Paginated lists with Riverpod.
- **🔄 mutationProvider**: Handle server side-effects.
- **🔀 combineQueries**: Merge multiple queries into a single state.
- **⚡ Riverpod Integration**: Works with `ref.watch`, `ConsumerWidget`, and `.family`.

## 📦 Installation

```yaml
dependencies:
  fasq_riverpod: ^0.2.4+1
```

## 🚀 Quick Start

### 1. Define a Provider

Create a `queryProvider` for your data source.

```dart
final usersProvider = queryProvider<List<User>>(
  'users',
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
  options: MutationOptions(
    onSuccess: (user) {
      QueryClient().invalidateQuery('users');
    },
  ),
);
```

## 🧩 Advanced Features

- **Parameterized Queries**: `queryProvider.family`.
- **Prefetching**: `ref.prefetchQuery`.
- **Dependent Queries**: `enabled: ref.watch(otherProvider).isSuccess`.

See the [main documentation](https://fasq.shafi.dev) for more.

## 📄 License

MIT
