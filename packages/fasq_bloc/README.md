# fasq_bloc

> **Bloc/Cubit adapter for FASQ (Flutter Async State Query).**

Bring the power of caching, auto-refetching, and offline mutations to your Bloc-based applications.

**Current Version:** 0.2.4+1

## 📚 Documentation

For full documentation and API reference, visit:  
**[https://fasq.shafi.dev/adapters/bloc](https://fasq.shafi.dev/adapters/bloc)**

## ✨ Features

- **🧊 QueryCubit**: A pre-built Cubit for handling async queries with caching.
- **♾️ InfiniteQueryCubit**: Infinite scrolling and pagination made easy.
- **🔄 MutationCubit**: Handle server mutations with optimistic updates.
- **🔀 MultiQueryBuilder**: Execute multiple queries in parallel.
- **⚡ Bloc Integration**: Seamlessly works with `BlocBuilder`, `BlocConsumer`, and `BlocProvider`.

## 📦 Installation

```yaml
dependencies:
  fasq_bloc: ^0.2.4+1
```

## 🚀 Quick Start

### 1. Create a QueryCubit

Extend `QueryCubit` and define your query logic.

```dart
class UsersQueryCubit extends QueryCubit<List<User>> {
  @override
  String get key => 'users';

  @override
  Future<List<User>> Function() get queryFn => () => api.fetchUsers();

  @override
  QueryOptions? get options => QueryOptions(
    staleTime: Duration(minutes: 5), // Data stays fresh for 5 mins
  );
}
```

### 2. Use in UI

Use `BlocProvider` and `BlocBuilder` as you normally would.

```dart
class UsersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UsersQueryCubit(),
      child: BlocBuilder<UsersQueryCubit, QueryState<List<User>>>(
        builder: (context, state) {
          if (state.isLoading) return CircularProgressIndicator();
          if (state.hasError) return Text('Error: ${state.error}');
          
          return ListView.builder(
            itemCount: state.data!.length,
            itemBuilder: (context, index) => Text(state.data![index].name),
          );
        },
      ),
    );
  }
}
```

## 🧩 Other Components

- **MutationCubit**: For `POST`/`PUT`/`DELETE` operations.
- **InfiniteQueryCubit**: For paginated lists.
- **MultiQueryBuilder**: For fetching multiple independent queries.

See the [main documentation](https://fasq.shafi.dev) for advanced usage like optimistic updates and cache invalidation.

## 📄 License

MIT
