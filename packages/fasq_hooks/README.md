# fasq_hooks

[![Pub Version](https://img.shields.io/pub/v/fasq_hooks?style=flat-square)](https://pub.dev/packages/fasq_hooks)
[![Repository](https://img.shields.io/badge/repository-GitHub-181717?style=flat-square)](https://github.com/ishafiul/fasq)
[![Issues](https://img.shields.io/github/issues/ishafiul/fasq?style=flat-square)](https://github.com/ishafiul/fasq/issues)

> **Flutter Hooks adapter for FASQ (Flutter Async State Query).**

The most natural way to use FASQ in Flutter. Bringing React Query-style hooks to your Flutter applications.

**Current Version:** 0.4.1

## 📚 Documentation

For full documentation and API reference, visit:  
**[https://shafi.dev/fasq/hooks](https://shafi.dev/fasq/hooks)**

## ✨ Features

- **🎣 useQuery**: Declarative data fetching with hooks.
- **♾️ useInfiniteQuery**: Infinite scrolling made simple.
- **🔄 useMutation**: Handle online mutations and side effects.
- **🔀 useQueries**: Execute multiple queries in parallel.
- **📦 Zero Configuration**: Works out of the box with `flutter_hooks`.

## 📦 Installation

```yaml
dependencies:
  fasq_hooks: ^0.4.1
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

For durable offline actions, use the core `@FasqMutation` contract and
`MutationBuilder` inside `FasqProvider`. See the [durable mutation documentation](https://shafi.dev/fasq/core/essentials/durable-mutations).

See the [main documentation](https://shafi.dev/fasq) for more.

## 🔗 Repository Links

- [Source repository](https://github.com/ishafiul/fasq)
- [Issue tracker](https://github.com/ishafiul/fasq/issues)
- [Pull requests](https://github.com/ishafiul/fasq/pulls)

## 📄 License

MIT
