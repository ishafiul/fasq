# fasq_bloc

[![Pub](https://img.shields.io/pub/v/fasq_bloc.svg)](https://pub.dev/packages/fasq_bloc)
[![Repository](https://img.shields.io/badge/repository-GitHub-181717?style=flat-square)](https://github.com/ishafiul/fasq)
[![Issues](https://img.shields.io/github/issues/ishafiul/fasq?style=flat-square)](https://github.com/ishafiul/fasq/issues)
[![Enterprise Ready](https://img.shields.io/badge/Enterprise-Ready-blue)]()
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)]()

> **The Native Bloc Adapter for FASQ.**

Bring the power of caching, optimistic updates, and offline support to your Bloc application with **zero friction**. `fasq_bloc` bridges the gap between `fasq`'s powerful query engine and the `flutter_bloc` ecosystem, allowing you to build complex data-driven apps without fighting your architecture.

**Current Version:** 0.4.0

## 📚 Documentation

For full documentation and API reference, visit:  
**[https://shafi.dev/fasq/bloc](https://shafi.dev/fasq/bloc)**

## ✨ Features

- **🧟 Zombie-proof Caching**: Data is cached, deduplicated, and garbage collected automatically. No more stale data bugs.
- **🛡️ Resilience Built-in**: **Circuit Breakers** protect your app from crashing backends.
- **🔌 Offline-First**: Use the core durable mutation contract for actions that must survive offline time and app restarts.
- **🚀 Native Feel**: Zero friction. It's just a `Cubit` where `QueryClient` is auto-injected.
- **🧩 Composition**: Solve "Bloc Hell" by composing multiple queries in a single Bloc with `FasqSubscriptionMixin`.

## 📦 Installation

```yaml
dependencies:
  fasq_bloc: ^0.4.0
  flutter_bloc: ^8.0.0
```

## 🚀 Quick Start

### 1. Setup the Provider

Wrap your app (or feature) with `FasqBlocProvider`. It automatically handles the `QueryClient` lifecycle.

```dart
void main() {
  runApp(
    FasqBlocProvider(
      child: MyApp(),
    ),
  );
}
```

For durable offline mutations, use `@FasqMutation` and the core
`MutationBuilder` inside `FasqProvider`. `fasq_bloc` remains the Bloc state
adapter; it does not provide the legacy `queueWhenOffline` option.

### 2. Create a QueryCubit

Extend `QueryCubit` for a 1-to-1 mapping between a Bloc and a Query.

```dart
class UserCubit extends QueryCubit<User> {
  final int userId;

  UserCubit(this.userId);

  @override
  QueryKey get queryKey => QueryKey('user', args: userId);

  @override
  Future<User> Function() get queryFn => () => api.fetchUser(userId);
}
```

## 🔗 Repository Links

- [Source repository](https://github.com/ishafiul/fasq)
- [Issue tracker](https://github.com/ishafiul/fasq/issues)
- [Pull requests](https://github.com/ishafiul/fasq/pulls)

### 3. Use in UI

Consume it like any other Bloc.

```dart
BlocBuilder<UserCubit, QueryState<User>>(
  builder: (context, state) {
    if (state.isLoading) return CircularProgressIndicator();
    if (state.hasData) return Text('Hello ${state.data!.name}');
    return Text('Error: ${state.error}');
  },
)
```

## 🛠️ Advanced Usage

### Composition (Multiple Queries)

Need to fetch a User and their Posts in the _same_ Bloc? Use the `FasqSubscriptionMixin`.

```dart
class DashboardBloc extends Cubit<DashboardState> with FasqSubscriptionMixin {
  DashboardBloc() : super(DashboardState.loading()) {
    // 1. Fetch User
    final userQuery = client.getQuery<User>('user'.toQueryKey(), ...);

    subscribeToQuery(userQuery, (state) {
       // Update internal state based on User query
       emit(state.copyWith(user: state.data));
    });

    // 2. Fetch Posts
    final postsQuery = client.getQuery<List<Post>>('posts'.toQueryKey(), ...);

    subscribeToQuery(postsQuery, (state) {
       emit(state.copyWith(posts: state.data));
    });
  }
}
```

### Optimistic Updates

Update your UI _before_ the server responds for a snappy experience.

```dart
class TodosCubit extends MutationCubit<Todo, String> {
  // ... configuration ...

  void addTodo(String text) {
    mutate(
      text,
      onMutate: () async {
        // 1. Cancel outgoing refetches
        await queryClient.cancelQueries('todos');

        // 2. Snapshot previous value
        final previous = queryClient.getQueryData<List<Todo>>('todos');

        // 3. Optimistically update cache
        queryClient.setQueryData<List<Todo>>(
          'todos',
          [...previous ?? [], Todo(id: 'temp', text: text)]
        );

        return { 'previous': previous };
      },
      onError: (error, context) {
        // 4. Rollback on error
        queryClient.setQueryData('todos', context['previous']);
      },
      onSettled: () {
        // 5. Always refetch to ensure sync
        queryClient.invalidateQueries('todos');
      }
    );
  }
}
```
