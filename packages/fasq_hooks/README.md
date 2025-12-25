# fasq_hooks

> **Flutter Hooks adapter for FASQ (Flutter Async State Query).**

The most natural way to use FASQ in Flutter. Bringing React Query-style hooks to your Flutter applications.

**Current Version:** 0.2.4+1

## 📚 Documentation

For full documentation and API reference, visit:  
**[https://fasq.shafi.dev/adapters/hooks](https://fasq.shafi.dev/adapters/hooks)**

## ✨ Features

- **🎣 useQuery**: Declarative data fetching with hooks.
- **♾️ useInfiniteQuery**: Infinite scrolling made simple.
- **🔄 useMutation**: Handle server mutations and side effects.
- **🔀 useQueries**: Execute multiple queries in parallel.
- **📦 Zero Configuration**: Works out of the box with `flutter_hooks`.

## 📦 Installation

```yaml
dependencies:
  fasq_hooks: ^0.2.4+1
```

## 🚀 Quick Start

### 1. Simple Query

Use `useQuery` inside a `HookWidget`.

```dart
class UsersScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useQuery(
      'users',
      () => api.fetchUsers(),
      options: QueryOptions(
        staleTime: Duration(minutes: 5),
      ),
    );
    
    if (state.isLoading) return CircularProgressIndicator();
    if (state.hasError) return Text('Error: ${state.error}');
    
    return ListView.builder(
      itemCount: state.data!.length,
      itemBuilder: (context, index) => Text(state.data![index].name),
    );
  }
}
```

### 2. Mutation

Use `useMutation` for actions.

```dart
final mutation = useMutation<User, String>(
  (name) => api.createUser(name),
  onSuccess: (user) {
    // Invalidate users query to trigger auto-refetch
    useQueryClient().invalidateQuery('users');
  },
);
```

### 3. Infinite List

Use `useInfiniteQuery` for pagination.

```dart
final posts = useInfiniteQuery<List<Post>, int>(
  'posts',
  (page) => api.fetchPosts(page: page),
  options: InfiniteQueryOptions(
    getNextPageParam: (pages, last) => pages.length + 1,
  ),
);
```

## 🧩 Advanced Features

- **Prefetching**: `usePrefetch`.
- **Global Cache Access**: `useQueryClient`.
- **Dependent Queries**: `enabled: otherQuery.isSuccess`.

See the [main documentation](https://fasq.shafi.dev) for more.

## 📄 License

MIT
