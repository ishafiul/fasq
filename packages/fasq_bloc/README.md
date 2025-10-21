# fasq_bloc

Bloc/Cubit adapter for FASQ (Flutter Async State Query) - bringing powerful async state management to your Bloc-based Flutter apps.

## Features

- 🧊 **QueryCubit** - Cubit wrapper for queries
- ♾️ **InfiniteQueryCubit** - Infinite queries for pagination
- 🔄 **MutationCubit** - Cubit for server mutations
- 🔀 **MultiQueryBuilder** - Execute multiple queries in parallel
- 🚀 **Automatic caching** - Built on FASQ's production-ready cache
- ⚡ **Background refetching** - Stale-while-revalidate pattern
- 🎯 **Type-safe** - Full type safety with Bloc

## Installation

```yaml
dependencies:
  fasq_bloc: ^0.1.0
```

## Usage
### Infinite Queries with InfiniteQueryCubit

```dart
BlocProvider(
  create: (_) => InfiniteQueryCubit<List<Post>, int>(
    key: 'posts',
    queryFn: (page) => api.fetchPosts(page: page),
    options: InfiniteQueryOptions(
      getNextPageParam: (pages, last) => pages.length + 1,
    ),
  ),
  child: BlocBuilder<InfiniteQueryCubit<List<Post>, int>, InfiniteQueryState<List<Post>, int>>(
    builder: (context, state) {
      return ListView.builder(
        itemCount: state.pages.expand((p) => p.data ?? []).length,
        itemBuilder: (_, i) => Text('Item #$i'),
      );
    },
  ),
)
```

### Parallel Queries with MultiQueryBuilder

```dart
MultiQueryBuilder(
  configs: [
    MultiQueryConfig(key: 'users', queryFn: () => api.fetchUsers()),
    MultiQueryConfig(key: 'posts', queryFn: () => api.fetchPosts()),
    MultiQueryConfig(key: 'comments', queryFn: () => api.fetchComments()),
  ],
  builder: (context, state) {
    return Column(
      children: [
        if (!state.isAllSuccess) LinearProgressIndicator(),
        if (state.hasAnyError) ErrorBanner(),
        UsersList(state.getState<List<User>>(0)),
        PostsList(state.getState<List<Post>>(1)),
        CommentsList(state.getState<List<Comment>>(2)),
      ],
    );
  },
)
```

### Dependent Queries

```dart
final userCubit = QueryCubit<User>(key: 'user', queryFn: fetchUser);
final postsCubit = QueryCubit<List<Post>>(
  key: 'posts:user:${userCubit.state.data?.id}',
  queryFn: () => fetchPosts(userCubit.state.data!.id),
  options: const QueryOptions(enabled: false),
);

// Enable when user loaded
if (userCubit.state.isSuccess) {
  // You can recreate with enabled true or structure initialization post user
}
```

### Basic Query with QueryCubit

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fasq_bloc/fasq_bloc.dart';

class UsersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QueryCubit<List<User>>(
        key: 'users',
        queryFn: () => api.fetchUsers(),
        options: QueryOptions(
          staleTime: Duration(minutes: 5),
        ),
      ),
      child: BlocBuilder<QueryCubit<List<User>>, QueryState<List<User>>>(
        builder: (context, state) {
          if (state.isLoading) {
            return CircularProgressIndicator();
          }
          
          if (state.hasError) {
            return Text('Error: ${state.error}');
          }
          
          if (state.hasData) {
            return UserList(users: state.data!);
          }
          
          return SizedBox();
        },
      ),
    );
  }
}
```

### Manual Refetch

```dart
class UserList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            // Refetch the query
            context.read<QueryCubit<List<User>>>().refetch();
          },
          child: Text('Refresh'),
        ),
        // ... list content
      ],
    );
  }
}
```

### Mutations with MutationCubit

```dart
class CreateUserScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MutationCubit<User, String>(
        mutationFn: (name) => api.createUser(name),
        onSuccessCallback: (user) {
          print('Created user: ${user.name}');
          // Invalidate users query
          QueryClient().invalidateQuery('users');
        },
        onErrorCallback: (error) {
          print('Error: $error');
        },
      ),
      child: BlocBuilder<MutationCubit<User, String>, MutationState<User>>(
        builder: (context, state) {
          return Column(
            children: [
              if (state.isLoading)
                CircularProgressIndicator(),
              
              if (state.hasError)
                Text('Error: ${state.error}'),
              
              if (state.hasData)
                Text('Created: ${state.data!.name}'),
              
              ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () {
                        context
                            .read<MutationCubit<User, String>>()
                            .mutate('John Doe');
                      },
                child: Text('Create User'),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

### Cache Invalidation

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final cubit = context.read<QueryCubit<List<User>>>();
        
        // Invalidate and refetch this query
        cubit.invalidate();
        
        // Or use QueryClient directly
        QueryClient().invalidateQuery('users');
        QueryClient().invalidateQueriesWithPrefix('user:');
      },
      child: Text('Invalidate Cache'),
    );
  }
}
```

## API Reference

### QueryCubit

```dart
class QueryCubit<T> extends Cubit<QueryState<T>> {
  QueryCubit({
    required String key,
    required Future<T> Function() queryFn,
    QueryOptions? options,
  });
  
  void refetch(); // Manually refetch
  void invalidate(); // Invalidate and refetch
}
```

**Emits:** `QueryState<T>` with:
- `isLoading` - Initial loading state
- `isFetching` - Background refetch in progress
- `hasData` - Whether data is available
- `data` - The fetched data
- `hasError` - Whether an error occurred
- `error` - The error object

### MutationCubit

```dart
class MutationCubit<TData, TVariables> extends Cubit<MutationState<TData>> {
  MutationCubit({
    required Future<TData> Function(TVariables) mutationFn,
    void Function(TData)? onSuccessCallback,
    void Function(Object)? onErrorCallback,
  });
  
  Future<void> mutate(TVariables variables);
  void reset();
}
```

**Emits:** `MutationState<TData>` with:
- `isLoading` - Whether mutation is in progress
- `data` - Mutation result
- `error` - Mutation error
- `hasData` - Whether mutation succeeded
- `hasError` - Whether mutation failed

## Why Bloc?

If you're already using `flutter_bloc`, this adapter provides seamless integration with Flutter Query:

- **Structured** - Bloc's explicit state management
- **Testable** - Easy to test cubits
- **Familiar** - Use BlocBuilder/BlocConsumer as usual
- **Debuggable** - Bloc DevTools integration

## Comparison with Core Package

**Core Package (QueryBuilder):**
```dart
QueryBuilder<List<User>>(
  queryKey: 'users',
  queryFn: () => api.fetchUsers(),
  builder: (context, state) {
    if (state.isLoading) return Loading();
    return UserList(state.data!);
  },
)
```

**Bloc Adapter (QueryCubit):**
```dart
BlocProvider(
  create: (_) => QueryCubit(
    key: 'users',
    queryFn: () => api.fetchUsers(),
  ),
  child: BlocBuilder<QueryCubit<List<User>>, QueryState<List<User>>>(
    builder: (context, state) {
      if (state.isLoading) return Loading();
      return UserList(state.data!);
    },
  ),
)
```

Both approaches use the same underlying query engine and have identical performance.

## Advanced Usage

### Using BlocConsumer for Side Effects

```dart
BlocConsumer<QueryCubit<User>, QueryState<User>>(
  listener: (context, state) {
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${state.error}')),
      );
    }
    
    if (state.isFetching) {
      print('Background refresh in progress...');
    }
  },
  builder: (context, state) {
    // Build UI
  },
)
```

### Multiple Queries in One Screen

```dart
MultiBlocProvider(
  providers: [
    BlocProvider(
      create: (_) => QueryCubit<List<User>>(
        key: 'users',
        queryFn: () => api.fetchUsers(),
      ),
    ),
    BlocProvider(
      create: (_) => QueryCubit<List<Post>>(
        key: 'posts',
        queryFn: () => api.fetchPosts(),
      ),
    ),
  ],
  child: MyScreen(),
)
```

## Learn More

- [FASQ Documentation](../fasq/README.md)
- [Bloc Documentation](https://bloclibrary.dev)
- [React Query (inspiration)](https://tanstack.com/query/latest)

## License

MIT
