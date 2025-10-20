# fasq_riverpod

Riverpod adapter for FASQ (Flutter Async State Query) - bringing powerful async state management to your Riverpod-based Flutter apps.

## Features

- 🔌 **queryProvider** - Provider factory for queries
- 🔄 **QueryNotifier** - StateNotifier for query state
- 🚀 **Automatic caching** - Built on FASQ's production-ready cache
- ⚡ **Background refetching** - Stale-while-revalidate pattern
- 🎯 **Type-safe** - Compile-time safety with Riverpod

## Installation

```yaml
dependencies:
  fasq_riverpod: ^0.1.0
```

## Usage

### Basic Query with queryProvider

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fasq_riverpod/fasq_riverpod.dart';

final usersProvider = queryProvider<List<User>>(
  'users',
  () => api.fetchUsers(),
  options: QueryOptions(
    staleTime: Duration(minutes: 5),
  ),
);

class UsersScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(usersProvider);
    
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

### Manual Refetch

```dart
class UserList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            // Refetch the query
            ref.read(usersProvider.notifier).refetch();
          },
          child: Text('Refresh'),
        ),
        // ... list content
      ],
    );
  }
}
```

### Parameterized Queries with Family

```dart
final userProvider = queryProvider.family<User, String>(
  (id) => 'user:$id',
  (id) => api.fetchUser(id),
  options: QueryOptions(
    staleTime: Duration(minutes: 5),
  ),
);

class UserProfile extends ConsumerWidget {
  final String userId;
  
  const UserProfile({required this.userId});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProvider(userId));
    
    if (userState.hasData) {
      return Text('User: ${userState.data!.name}');
    }
    
    return CircularProgressIndicator();
  }
}
```

### Cache Invalidation

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () {
        // Invalidate specific query
        ref.read(usersProvider.notifier).invalidate();
        
        // Or use QueryClient directly
        QueryClient().invalidateQuery('users');
        QueryClient().invalidateQueriesWithPrefix('user:');
      },
      child: Text('Invalidate Cache'),
    );
  }
}
```

### Mutations

For creating, updating, or deleting data:

```dart
final createUserProvider = mutationProvider<User, String>(
  (name) => api.createUser(name),
  options: MutationOptions(
    onSuccess: (user) {
      // Invalidate users query to refetch
      QueryClient().invalidateQuery('users');
    },
    onError: (error) {
      print('Error creating user: $error');
    },
  ),
);

class CreateUserScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutation = ref.watch(createUserProvider);
    
    return Column(
      children: [
        ElevatedButton(
          onPressed: mutation.isLoading
              ? null
              : () => ref.read(createUserProvider.notifier).mutate('John Doe'),
          child: mutation.isLoading
              ? CircularProgressIndicator()
              : Text('Create User'),
        ),
        
        if (mutation.hasError)
          Text('Error: ${mutation.error}', style: TextStyle(color: Colors.red)),
        
        if (mutation.hasData)
          Text('Created: ${mutation.data!.name}'),
      ],
    );
  }
}
```

### Form Submission

```dart
class CreateUserForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormState extends ConsumerState<CreateUserForm> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  late final createUserProvider;
  
  @override
  void initState() {
    super.initState();
    createUserProvider = mutationProvider<User, Map<String, String>>(
      (data) => api.createUser(data['name']!, data['email']!),
      options: MutationOptions(
        onSuccess: (user) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User created: ${user.name}')),
          );
          _nameController.clear();
          _emailController.clear();
        },
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final mutation = ref.watch(createUserProvider);
    
    return Column(
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'Name'),
        ),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(labelText: 'Email'),
        ),
        
        ElevatedButton(
          onPressed: mutation.isLoading
              ? null
              : () {
                  ref.read(createUserProvider.notifier).mutate({
                    'name': _nameController.text,
                    'email': _emailController.text,
                  });
                },
          child: mutation.isLoading
              ? CircularProgressIndicator()
              : Text('Create User'),
        ),
      ],
    );
  }
}
```

### Background Refetch Indicator

```dart
class UsersScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(usersProvider);
    
    return Column(
      children: [
        if (usersState.isFetching)
          LinearProgressIndicator(), // Background refresh indicator
        
        if (usersState.hasData)
          Expanded(
            child: UserList(users: usersState.data!),
          ),
      ],
    );
  }
}
```

## API Reference

### queryProvider

```dart
StateNotifierProvider<QueryNotifier<T>, QueryState<T>> queryProvider<T>(
  String key,
  Future<T> Function() queryFn, {
  QueryOptions? options,
})
```

**Parameters:**
- `key` - Unique identifier for the query
- `queryFn` - Async function that fetches the data
- `options` - Optional configuration (staleTime, cacheTime, etc.)

**Returns:** `StateNotifierProvider` with `QueryState<T>`

### QueryNotifier

```dart
class QueryNotifier<T> extends StateNotifier<QueryState<T>> {
  void refetch(); // Manually refetch
  void invalidate(); // Invalidate and refetch
}
```

**State:** `QueryState<T>` with:
- `isLoading` - Initial loading state
- `isFetching` - Background refetch in progress
- `hasData` - Whether data is available
- `data` - The fetched data
- `hasError` - Whether an error occurred
- `error` - The error object

## Why Riverpod?

If you're already using `flutter_riverpod`, this adapter provides seamless integration:

- **Compile-safe** - Type errors caught at compile time
- **No context** - Access providers anywhere
- **Auto-dispose** - Automatic cleanup
- **DevTools** - Riverpod DevTools integration
- **Family** - Parameterized queries

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

**Riverpod Adapter (queryProvider):**
```dart
final usersProvider = queryProvider('users', () => api.fetchUsers());

class UsersScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usersProvider);
    if (state.isLoading) return Loading();
    return UserList(state.data!);
  }
}
```

Both approaches use the same underlying query engine and have identical performance.

## Advanced Usage

### Combining Multiple Queries

```dart
class Dashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    final posts = ref.watch(postsProvider);
    final stats = ref.watch(statsProvider);
    
    return Column(
      children: [
        UserSection(users),
        PostSection(posts),
        StatsSection(stats),
      ],
    );
  }
}
```

### Conditional Queries

```dart
final conditionalQueryProvider = queryProvider<Data>(
  'conditional',
  () => api.fetchData(),
  options: QueryOptions(
    enabled: someCondition, // Only fetches when true
  ),
);
```

### Using ref.listen for Side Effects

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(usersProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${next.error}')),
        );
      }
    });
    
    // Build UI
  }
}
```

## Learn More

- [FASQ Documentation](../fasq/README.md)
- [Riverpod Documentation](https://riverpod.dev)
- [React Query (inspiration)](https://tanstack.com/query/latest)

## License

MIT
