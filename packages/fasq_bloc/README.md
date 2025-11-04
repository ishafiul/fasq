# fasq_bloc

Bloc/Cubit adapter for FASQ (Flutter Async State Query) - bringing powerful async state management to your Bloc-based Flutter apps.

## Features

- 🧊 **QueryCubit** - Abstract base cubit for queries
- ♾️ **InfiniteQueryCubit** - Abstract base cubit for infinite queries
- 🔄 **MutationCubit** - Abstract base cubit for server mutations
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

### Basic Query with QueryCubit

Extend `QueryCubit` and implement the required getters:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fasq_bloc/fasq_bloc.dart';

class UsersQueryCubit extends QueryCubit<List<User>> {
  @override
  String get key => 'users';

  @override
  Future<List<User>> Function() get queryFn => () => api.fetchUsers();

  @override
  QueryOptions? get options => QueryOptions(
    staleTime: Duration(minutes: 5),
  );
}

class UsersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UsersQueryCubit(),
      child: BlocBuilder<UsersQueryCubit, QueryState<List<User>>>(
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

### Infinite Queries with InfiniteQueryCubit

Extend `InfiniteQueryCubit` for pagination:

```dart
class PostsInfiniteQueryCubit extends InfiniteQueryCubit<List<Post>, int> {
  @override
  String get key => 'posts';

  @override
  Future<List<Post>> Function(int param) get queryFn => 
    (page) => api.fetchPosts(page: page);

  @override
  InfiniteQueryOptions<List<Post>, int>? get options => InfiniteQueryOptions(
    getNextPageParam: (pages, last) => pages.length + 1,
  );
}

BlocProvider(
  create: (_) => PostsInfiniteQueryCubit(),
  child: BlocBuilder<PostsInfiniteQueryCubit, InfiniteQueryState<List<Post>, int>>(
    builder: (context, state) {
      final allPosts = state.pages.expand((p) => p.data ?? []).toList();
      return ListView.builder(
        itemCount: allPosts.length,
        itemBuilder: (_, i) => PostItem(allPosts[i]),
      );
    },
  ),
)
```

### Mutations with MutationCubit

Extend `MutationCubit` for server mutations:

```dart
class CreateUserMutationCubit extends MutationCubit<User, String> {
  @override
  Future<User> Function(String variables) get mutationFn => 
    (name) => api.createUser(name);

  @override
  MutationOptions<User, String>? get options => MutationOptions(
    onSuccess: (user) {
      QueryClient().invalidateQuery('users');
    },
    onError: (error) {
      print('Error: $error');
    },
  );
}

class CreateUserScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CreateUserMutationCubit(),
      child: BlocBuilder<CreateUserMutationCubit, MutationState<User>>(
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
                            .read<CreateUserMutationCubit>()
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

### Parallel Queries with MultiQueryBuilder

Execute multiple queries in parallel using `MultiQueryBuilder` or `NamedMultiQueryBuilder`:

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

NamedMultiQueryBuilder(
  configs: [
    NamedQueryConfig(name: 'users', key: 'users', queryFn: () => api.fetchUsers()),
    NamedQueryConfig(name: 'posts', key: 'posts', queryFn: () => api.fetchPosts()),
    NamedQueryConfig(name: 'comments', key: 'comments', queryFn: () => api.fetchComments()),
  ],
  builder: (context, state) {
    return Column(
      children: [
        if (!state.isAllSuccess) LinearProgressIndicator(),
        if (state.hasAnyError) ErrorBanner(),
        UsersList(state.getState<List<User>>('users')),
        PostsList(state.getState<List<Post>>('posts')),
        CommentsList(state.getState<List<Comment>>('comments')),
      ],
    );
  },
)
```

### Prefetching

Warm the cache before data is needed:

```dart
PrefetchBuilder(
  configs: [
    PrefetchConfig(key: 'users', queryFn: () => api.fetchUsers()),
    PrefetchConfig(key: 'posts', queryFn: () => api.fetchPosts()),
  ],
  child: YourScreen(),
)

final prefetchCubit = PrefetchQueryCubit();
await prefetchCubit.prefetch('users', () => api.fetchUsers());
```

### Dependent Queries

Create dependent queries by implementing conditional logic:

```dart
class UserPostsQueryCubit extends QueryCubit<List<Post>> {
  final String userId;

  UserPostsQueryCubit(this.userId);

  @override
  String get key => 'posts:user:$userId';

  @override
  Future<List<Post>> Function() get queryFn => 
    () => api.fetchUserPosts(userId);

  @override
  QueryOptions? get options => QueryOptions(
    enabled: userId.isNotEmpty,
  );
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
            context.read<UsersQueryCubit>().refetch();
          },
          child: Text('Refresh'),
        ),
      ],
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
        final cubit = context.read<UsersQueryCubit>();
        
        cubit.invalidate();
        
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
abstract class QueryCubit<T> extends Cubit<QueryState<T>> {
  String get key;
  Future<T> Function() get queryFn;
  QueryOptions? get options => null;
  QueryClient? get client => null;
  
  void refetch();
  void invalidate();
}
```

**Emits:** `QueryState<T>` with:
- `isLoading` - Initial loading state
- `isFetching` - Background refetch in progress
- `hasData` - Whether data is available
- `data` - The fetched data
- `hasError` - Whether an error occurred
- `error` - The error object

### InfiniteQueryCubit

```dart
abstract class InfiniteQueryCubit<TData, TParam> 
    extends Cubit<InfiniteQueryState<TData, TParam>> {
  String get key;
  Future<TData> Function(TParam param) get queryFn;
  InfiniteQueryOptions<TData, TParam>? get options => null;
  
  Future<void> fetchNextPage([TParam? param]);
  Future<void> fetchPreviousPage();
  Future<void> refetchPage(int index);
  void reset();
}
```

### MutationCubit

```dart
abstract class MutationCubit<TData, TVariables> 
    extends Cubit<MutationState<TData>> {
  Future<TData> Function(TVariables variables) get mutationFn;
  MutationOptions<TData, TVariables>? get options => null;
  QueryClient? get client => null;
  
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
class UsersQueryCubit extends QueryCubit<List<User>> {
  @override
  String get key => 'users';
  
  @override
  Future<List<User>> Function() get queryFn => () => api.fetchUsers();
}

BlocProvider(
  create: (_) => UsersQueryCubit(),
  child: BlocBuilder<UsersQueryCubit, QueryState<List<User>>>(
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
BlocConsumer<UsersQueryCubit, QueryState<List<User>>>(
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
    return UserList(users: state.data ?? []);
  },
)
```

### Multiple Queries in One Screen

```dart
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => UsersQueryCubit()),
    BlocProvider(create: (_) => PostsQueryCubit()),
  ],
  child: MyScreen(),
)
```

### Custom QueryClient

```dart
class SecureUsersQueryCubit extends QueryCubit<String> {
  @override
  String get key => 'auth-token';
  
  @override
  Future<String> Function() get queryFn => () => api.getAuthToken();
  
  @override
  QueryOptions? get options => QueryOptions(
    isSecure: true,
    maxAge: Duration(minutes: 15),
    staleTime: Duration(minutes: 5),
  );
  
  @override
  QueryClient? get client => QueryClient();
}
```

## Security Features 🔒

fasq_bloc supports all FASQ security features through QueryClient configuration and options:

### Secure Queries

```dart
class SecureTokenQueryCubit extends QueryCubit<String> {
  @override
  String get key => 'auth-token';
  
  @override
  Future<String> Function() get queryFn => () => api.getAuthToken();
  
  @override
  QueryOptions? get options => QueryOptions(
    isSecure: true,
    maxAge: Duration(minutes: 15),
    staleTime: Duration(minutes: 5),
  );
}
```

### Secure Mutations

```dart
class SecureMutationCubit extends MutationCubit<String, String> {
  @override
  Future<String> Function(String variables) get mutationFn => 
    (data) => api.secureMutation(data);
  
  @override
  MutationOptions<String, String>? get options => MutationOptions(
    queueWhenOffline: true,
    maxRetries: 3,
  );
}
```

**Security Benefits:**
- ✅ Secure cache entries with automatic cleanup
- ✅ Encrypted persistence for sensitive data
- ✅ Input validation preventing injection attacks
- ✅ Platform-specific secure key storage

## Learn More

- [FASQ Documentation](../fasq/README.md)
- [Bloc Documentation](https://bloclibrary.dev)
- [React Query (inspiration)](https://tanstack.com/query/latest)

## License

MIT
