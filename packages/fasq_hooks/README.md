# fasq_hooks

Flutter Hooks adapter for FASQ (Flutter Async State Query) - bringing powerful async state management to your hooks-based Flutter apps.

## Features

- 🎣 **`useQuery`** - Declarative data fetching with hooks
- ♾️ **`useInfiniteQuery`** - Infinite queries for pagination and load-more
- 🔄 **`useMutation`** - Server mutations made simple
- 🔀 **`useQueries`** - Execute multiple queries in parallel
- 🚀 **Automatic caching** - Built on FASQ's production-ready cache
- ⚡ **Background refetching** - Stale-while-revalidate pattern
- 🎯 **Type-safe** - Full TypeScript-like type safety

## Installation

```yaml
dependencies:
  fasq_hooks: ^0.1.0
```

## Usage
### Infinite Queries

```dart
final posts = useInfiniteQuery<List<Post>, int>(
  'posts',
  (page) => api.fetchPosts(page: page),
  InfiniteQueryOptions(
    getNextPageParam: (pages, last) => pages.length + 1,
  ),
);

if (posts.hasNextPage) {
  // trigger load more
}
```

### Parallel Queries

Execute multiple queries in parallel using `useQueries` or `useNamedQueries`:

```dart
// Index-based access
final queries = useQueries([
  QueryConfig('users', () => api.fetchUsers()),
  QueryConfig('posts', () => api.fetchPosts()),
  QueryConfig('comments', () => api.fetchComments()),
]);

// Named access (more ergonomic)
final queries = useNamedQueries({
  'users': QueryConfig('users', () => api.fetchUsers()),
  'posts': QueryConfig('posts', () => api.fetchPosts()),
  'comments': QueryConfig('comments', () => api.fetchComments()),
});

// Access by name
final users = queries['users']?.data;
final posts = queries['posts']?.data;
```

### Prefetching

Warm the cache before data is needed:

```dart
// Prefetch on demand
final prefetch = usePrefetchQuery();

onHover: () => prefetch('user-123', () => api.fetchUser('123'));

// Prefetch on mount
usePrefetchOnMount([
  PrefetchConfig(key: 'users', queryFn: () => api.fetchUsers()),
  PrefetchConfig(key: 'posts', queryFn: () => api.fetchPosts()),
]);

final allLoaded = queries.every((q) => q.hasData);
final anyError = queries.any((q) => q.hasError);

return Column(
  children: [
    if (!allLoaded) LinearProgressIndicator(),
    if (anyError) ErrorBanner(),
    UsersList(queries[0]),
    PostsList(queries[1]),
    CommentsList(queries[2]),
  ],
);

// Named access (better DX)
final queries = useNamedQueries([
  NamedQueryConfig(name: 'users', key: 'users', queryFn: () => api.fetchUsers()),
  NamedQueryConfig(name: 'posts', key: 'posts', queryFn: () => api.fetchPosts()),
  NamedQueryConfig(name: 'comments', key: 'comments', queryFn: () => api.fetchComments()),
]);

final allLoaded = queries.values.every((q) => q.hasData);
final anyError = queries.values.any((q) => q.hasError);

return Column(
  children: [
    if (!allLoaded) LinearProgressIndicator(),
    if (anyError) ErrorBanner(),
    UsersList(queries['users']!),
    PostsList(queries['posts']!),
    CommentsList(queries['comments']!),
  ],
);
```

### Dependent Queries

```dart
final user = useQuery('user', () => fetchUser());
final posts2 = useQuery(
  'posts:${user.data?.id}',
  () => fetchPosts(user.data!.id),
  options: QueryOptions(enabled: user.isSuccess),
);
```

### Basic Query

```dart
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fasq_hooks/fasq_hooks.dart';

class UsersScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final usersState = useQuery(
      'users',
      () => api.fetchUsers(),
      options: QueryOptions(
        staleTime: Duration(minutes: 5),
      ),
    );
    
    if (usersState.isLoading) {
      return CircularProgressIndicator();
    }
    
    if (usersState.hasError) {
      return Text('Error: ${usersState.error}');
    }
    
    if (usersState.hasData) {
      return UserList(users: usersState.data!);
    }
    
    return SizedBox();
  }
}
```

### Mutations

```dart
class CreateUserScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final createUser = useMutation<User, String>(
      (name) => api.createUser(name),
      onSuccess: (user) {
        print('Created user: ${user.name}');
        // Invalidate users query
        useQueryClient().invalidateQuery('users');
      },
    );
    
    return ElevatedButton(
      onPressed: createUser.isLoading 
        ? null 
        : () => createUser.mutate('John Doe'),
      child: Text('Create User'),
    );
  }
}
```

### Access QueryClient

```dart
class MyWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final queryClient = useQueryClient();
    
    return ElevatedButton(
      onPressed: () {
        // Invalidate specific query
        queryClient.invalidateQuery('users');
        
        // Set query data manually
        queryClient.setQueryData('user:1', User(id: 1, name: 'John'));
        
        // Get cache info
        final info = queryClient.getCacheInfo();
        print('Cache hit rate: ${info.metrics.hitRate}');
      },
      child: Text('Manage Cache'),
    );
  }
}
```

## API Reference

### useQuery

```dart
QueryState<T> useQuery<T>(
  String key,
  Future<T> Function() queryFn, {
  QueryOptions? options,
})
```

**Parameters:**
- `key` - Unique identifier for the query
- `queryFn` - Async function that fetches the data
- `options` - Optional configuration (staleTime, cacheTime, etc.)

**Returns:** `QueryState<T>` with:
- `isLoading` - Initial loading state
- `isFetching` - Background refetch in progress
- `hasData` - Whether data is available
- `data` - The fetched data
- `hasError` - Whether an error occurred
- `error` - The error object

### useMutation

```dart
MutationState<TData, TVariables> useMutation<TData, TVariables>(
  Future<TData> Function(TVariables) mutationFn, {
  void Function(TData)? onSuccess,
  void Function(Object)? onError,
})
```

**Parameters:**
- `mutationFn` - Function that performs the mutation
- `onSuccess` - Called when mutation succeeds
- `onError` - Called when mutation fails

**Returns:** `MutationState<TData, TVariables>` with:
- `mutate(variables)` - Execute the mutation
- `reset()` - Reset mutation state
- `isLoading` - Whether mutation is in progress
- `data` - Mutation result
- `error` - Mutation error

### useQueryClient

```dart
QueryClient useQueryClient()
```

Returns the global `QueryClient` instance for manual cache management.

## Why Hooks?

If you're already using `flutter_hooks`, this adapter provides the most natural integration with Flutter Query. The hooks API is:

- **Concise** - Less boilerplate than StatefulWidget
- **Composable** - Easy to create custom hooks
- **Familiar** - Similar to React Query hooks
- **Testable** - Hooks are easy to test

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

**Hooks Adapter (useQuery):**
```dart
final usersState = useQuery('users', () => api.fetchUsers());
if (usersState.isLoading) return Loading();
return UserList(usersState.data!);
```

Both approaches use the same underlying query engine, so they have identical performance and caching behavior.

## Learn More

- [FASQ Documentation](../fasq/README.md)
- [Flutter Hooks Documentation](https://pub.dev/packages/flutter_hooks)
- [React Query (inspiration)](https://tanstack.com/query/latest)

## License

MIT
