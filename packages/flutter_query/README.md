# Flutter Query

A powerful async state management library for Flutter. Handles API calls, database queries, file operations, and any async operation with intelligent caching, automatic refetching, and error recovery.

**Current Version:** 0.1.0 (Phase 2 - Caching Layer)  
**Status:** In Development

## Features

- ✅ **Simple API** - Works with any Future-returning function
- ✅ **Automatic State Management** - Loading, error, and success states handled automatically
- ✅ **Intelligent Caching** - Automatic caching with staleness detection and configurable freshness
- ✅ **Request Deduplication** - Concurrent requests for same data trigger only one network call
- ✅ **Background Refetching** - Stale data served instantly while fresh data loads in background
- ✅ **Memory Management** - LRU/LFU/FIFO eviction policies with configurable limits
- ✅ **Cache Invalidation** - Flexible patterns for invalidating cached data
- ✅ **Shared Queries** - Multiple widgets share the same query and cache
- ✅ **Type Safe** - Full generic type support for your data
- ✅ **Thread Safe** - Concurrent access protection with async locks
- ✅ **Production Ready** - Comprehensive testing and error handling
- 🔄 **State Management Adapters** - Coming in Phase 3 (Hooks, Bloc, Riverpod)
- 🔄 **Offline Support** - Coming in Phase 4

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_query: ^0.0.1
```

## Quick Start

### 1. Create a Query

Use `QueryBuilder` to execute any async operation and display the results:

```dart
import 'package:flutter_query/flutter_query.dart';

QueryBuilder<List<User>>(
  queryKey: 'users',
  queryFn: () => api.fetchUsers(),
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
)
```

### 2. Handle Different Async Operations

Flutter Query works with any Future-returning function:

**API Calls:**
```dart
QueryBuilder<List<User>>(
  queryKey: 'users',
  queryFn: () async {
    final response = await http.get(Uri.parse('https://api.example.com/users'));
    return parseUsers(response.body);
  },
  builder: (context, state) => buildUI(state),
)
```

**Database Queries:**
```dart
QueryBuilder<List<Todo>>(
  queryKey: 'todos',
  queryFn: () => database.getTodos(),
  builder: (context, state) => buildUI(state),
)
```

**File Operations:**
```dart
QueryBuilder<String>(
  queryKey: 'config',
  queryFn: () => File('config.json').readAsString(),
  builder: (context, state) => buildUI(state),
)
```

**Heavy Computations:**
```dart
QueryBuilder<int>(
  queryKey: 'computation',
  queryFn: () => compute(heavyCalculation, data),
  builder: (context, state) => buildUI(state),
)
```

### 3. Share Queries Across Widgets

Multiple widgets using the same `queryKey` share the same query instance:

```dart
// Widget A
QueryBuilder<Data>(
  queryKey: 'shared-data',
  queryFn: () => fetchData(),
  builder: (context, state) => WidgetA(state),
)

// Widget B (shares the same query!)
QueryBuilder<Data>(
  queryKey: 'shared-data',
  queryFn: () => fetchData(),
  builder: (context, state) => WidgetB(state),
)
```

Only ONE fetch happens, both widgets receive the same state.

### 4. Configure Caching Behavior

Control how long data stays fresh and cached:

```dart
QueryBuilder<UserProfile>(
  queryKey: 'userProfile',
  queryFn: () => api.fetchProfile(),
  options: QueryOptions(
    staleTime: Duration(minutes: 5),  // Data fresh for 5 minutes
    cacheTime: Duration(minutes: 10), // Cached for 10 minutes when inactive
  ),
  builder: (context, state) => buildUI(state),
)
```

**What happens:**
- First fetch: loads from network, caches for 5 minutes
- Within 5 min: serves instantly from cache, no refetch
- After 5 min: serves from cache, refetches in background
- After 10 min inactive: cache cleared, next access fetches fresh

### 5. Cache Invalidation

Invalidate cached data when you know it's changed:

```dart
// After updating data
await api.updateUser(user);

// Invalidate the cache
QueryClient().invalidateQuery('user:123');

// Or invalidate multiple
QueryClient().invalidateQueriesWithPrefix('user:');

// Or use custom logic
QueryClient().invalidateQueriesWhere((key) => key.contains('stale'));
```

### 6. Manual Cache Updates

Set cache data manually for optimistic updates:

```dart
// Optimistically update cache
QueryClient().setQueryData('user:123', updatedUser);

// Make API call
await api.updateUser(updatedUser);

// Get cached data
final cachedUser = QueryClient().getQueryData<User>('user:123');
```

### 7. Monitor Cache Performance

```dart
final info = QueryClient().getCacheInfo();
print('Cache entries: ${info.entryCount}');
print('Cache size: ${info.sizeBytes} bytes');
print('Hit rate: ${info.metrics.hitRate * 100}%');
print('Hits: ${info.metrics.hits}');
print('Misses: ${info.metrics.misses}');
```

### 8. Manual Refetch

Trigger a refetch manually:

```dart
final query = QueryClient().getQueryByKey<List<User>>('users');
query?.fetch();
```

### 5. Control Query Execution

Disable automatic fetching with the `enabled` option:

```dart
QueryBuilder<UserPosts>(
  queryKey: 'posts',
  queryFn: () => api.fetchPosts(userId),
  options: QueryOptions(
    enabled: userId != null,  // Only fetch when userId is available
  ),
  builder: (context, state) => buildUI(state),
)
```

## Core Concepts

### Caching and Staleness

Flutter Query uses intelligent caching to dramatically improve app performance and user experience.

**Three Data States:**

1. **Fresh Data** (age < staleTime)
   - Served instantly from cache
   - No refetch triggered
   - Perfect for data that doesn't change often

2. **Stale Data** (age >= staleTime)
   - Served instantly from cache (no loading state!)
   - Background refetch triggered automatically
   - `state.isFetching` indicates background activity
   - UI updates when fresh data arrives

3. **Missing Data** (not in cache)
   - Must fetch from source
   - Shows loading state
   - Caches result for future requests

**Key Timing Concepts:**

- **staleTime** - How long data is considered fresh (default: 0 = always stale)
- **cacheTime** - How long inactive data stays in cache (default: 5 minutes)

**Example:**
```dart
QueryOptions(
  staleTime: Duration(minutes: 5),  // Fresh for 5 min
  cacheTime: Duration(minutes: 30), // Kept in cache for 30 min
)
```

Timeline:
- 0-5 min: Fresh (instant, no refetch)
- 5-30 min: Stale (instant + background refetch)
- 30+ min (inactive): Garbage collected

### Request Deduplication

When 100 widgets request the same data simultaneously:
- **Without Flutter Query:** 100 network requests
- **With Flutter Query:** 1 network request, all widgets get the result

This happens automatically, no configuration needed.

### Query State

Every query has a state with these properties:

- `data` - The result of the async operation (null if not loaded)
- `error` - The error if the operation failed (null otherwise)
- `stackTrace` - Stack trace for debugging errors
- `status` - Current status: idle, loading, success, or error
- `isLoading` - Boolean flag for loading state
- `hasData` - Boolean flag indicating data is available
- `hasError` - Boolean flag indicating an error occurred
- `isSuccess` - Boolean flag for successful completion

### Query Lifecycle

1. **Creation:** Query is created when first widget with that key mounts
2. **Fetching:** Query automatically fetches on first subscriber
3. **State Updates:** All subscribed widgets rebuild when state changes
4. **Sharing:** Additional widgets with same key share the query instance
5. **Cleanup:** Query is disposed 5 seconds after last widget unmounts

### Query Key

The `queryKey` is a unique string identifier for a query. Widgets with the same key share the same query instance and state.

**Best Practices:**
- Use descriptive keys: `'users'`, `'user:123'`, `'posts:user:123'`
- Include parameters in key for parameterized queries
- Keep keys consistent across your app

## Mutations

Mutations are used for creating, updating, or deleting data (POST, PUT, DELETE operations). Unlike queries, mutations:
- Don't cache results (each execution is unique)
- Are manually triggered (not auto-fetch)
- Are perfect for form submissions and server modifications

### Basic Mutation with MutationBuilder

```dart
MutationBuilder<User, CreateUserInput>(
  mutationFn: (input) => api.createUser(input),
  builder: (context, state, mutate) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: state.isLoading
              ? null
              : () => mutate(CreateUserInput(
                    name: 'John Doe',
                    email: 'john@example.com',
                  )),
          child: state.isLoading
              ? CircularProgressIndicator()
              : Text('Create User'),
        ),
        
        if (state.hasError)
          Text('Error: ${state.error}', style: TextStyle(color: Colors.red)),
        
        if (state.hasData)
          Text('Created: ${state.data!.name}'),
      ],
    );
  },
)
```

### Form Submission Example

```dart
class CreateUserForm extends StatefulWidget {
  @override
  State<CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormState extends State<CreateUserForm> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return MutationBuilder<User, Map<String, String>>(
      mutationFn: (data) async {
        final response = await http.post(
          Uri.parse('https://api.example.com/users'),
          body: json.encode(data),
        );
        return User.fromJson(json.decode(response.body));
      },
      options: MutationOptions(
        onSuccess: (user) {
          QueryClient().invalidateQuery('users');
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User created: ${user.name}')),
          );
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        },
      ),
      builder: (context, state, mutate) {
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
            
            SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : () {
                      mutate({
                        'name': _nameController.text,
                        'email': _emailController.text,
                      });
                    },
              child: state.isLoading
                  ? CircularProgressIndicator()
                  : Text('Create User'),
            ),
            
            if (state.hasError)
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Error: ${state.error}',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

### Cache Invalidation After Mutation

After a mutation succeeds, you typically want to invalidate related queries:

```dart
MutationBuilder<User, String>(
  mutationFn: (userId) => api.deleteUser(userId),
  options: MutationOptions(
    onSuccess: (deletedUser) {
      QueryClient().invalidateQuery('users');
      QueryClient().invalidateQuery('user:${deletedUser.id}');
    },
  ),
  builder: (context, state, mutate) {
    return IconButton(
      icon: Icon(Icons.delete),
      onPressed: () => mutate('user-123'),
    );
  },
)
```

### Optimistic Updates

Update the cache immediately for instant UX, then rollback on error:

```dart
MutationBuilder<User, User>(
  mutationFn: (user) => api.updateUser(user),
  options: MutationOptions(
    onMutate: (updatedUser, _) {
      final users = QueryClient().getQueryData<List<User>>('users');
      final optimistic = users?.map((u) => 
        u.id == updatedUser.id ? updatedUser : u
      ).toList();
      
      QueryClient().setQueryData('users', optimistic);
    },
    onSuccess: (user) {
      QueryClient().invalidateQuery('users');
    },
    onError: (error) {
      QueryClient().invalidateQuery('users');
    },
  ),
  builder: (context, state, mutate) {
    return ElevatedButton(
      onPressed: () => mutate(updatedUser),
      child: Text('Update'),
    );
  },
)
```

### Manual Mutation Class

For more control, use the `Mutation` class directly:

```dart
class CreateUserScreen extends StatefulWidget {
  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  late final Mutation<User, String> _createUserMutation;
  
  @override
  void initState() {
    super.initState();
    
    _createUserMutation = Mutation<User, String>(
      mutationFn: (name) => api.createUser(name),
      options: MutationOptions(
        onSuccess: (user) {
          QueryClient().invalidateQuery('users');
        },
      ),
    );
    
    _createUserMutation.stream.listen((state) {
      if (mounted) setState(() {});
    });
  }
  
  @override
  void dispose() {
    _createUserMutation.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final state = _createUserMutation.state;
    
    return ElevatedButton(
      onPressed: state.isLoading
          ? null
          : () => _createUserMutation.mutate('John Doe'),
      child: Text(state.isLoading ? 'Creating...' : 'Create User'),
    );
  }
}
```

## API Reference

### QueryBuilder

Widget that executes an async operation and builds UI based on state.

```dart
QueryBuilder<T>(
  required String queryKey,
  required Future<T> Function() queryFn,
  required Widget Function(BuildContext, QueryState<T>) builder,
  QueryOptions? options,
)
```

**Parameters:**
- `queryKey` - Unique identifier for this query
- `queryFn` - Function that returns a Future with the data
- `builder` - Function that builds UI from query state
- `options` - Optional configuration

### MutationBuilder

Widget that executes a mutation and builds UI based on its state.

```dart
MutationBuilder<T, TVariables>(
  required Future<T> Function(TVariables) mutationFn,
  required Widget Function(BuildContext, MutationState<T>, Future<void> Function(TVariables)) builder,
  MutationOptions<T, TVariables>? options,
)
```

**Parameters:**
- `mutationFn` - Function that performs the mutation
- `builder` - Function that builds UI from mutation state and mutate function
- `options` - Optional callbacks (onSuccess, onError, onMutate)

**Builder Parameters:**
- `context` - BuildContext
- `state` - Current MutationState<T>
- `mutate` - Function to execute the mutation

### MutationState

Immutable state object representing the current mutation status.

**Properties:**
- `T? data` - The mutation result
- `Object? error` - The error if any
- `StackTrace? stackTrace` - Stack trace for errors
- `MutationStatus status` - Current status enum
- `bool isLoading` - True when mutation is executing
- `bool hasData` - True when mutation succeeded
- `bool hasError` - True when mutation failed
- `bool isSuccess` - True when mutation completed successfully
- `bool isIdle` - True when not yet executed

### MutationOptions

Configuration options for mutations.

```dart
MutationOptions<T, TVariables>({
  void Function(T data)? onSuccess,
  void Function(Object error)? onError,
  void Function(T data, TVariables variables)? onMutate,
})
```

**Callbacks:**
- `onSuccess` - Called when mutation succeeds
- `onError` - Called when mutation fails
- `onMutate` - Called with result and variables (for optimistic updates)

### QueryState

Immutable state object representing the current query status.

**Properties:**
- `T? data` - The fetched data
- `Object? error` - The error if any
- `StackTrace? stackTrace` - Stack trace for errors
- `QueryStatus status` - Current status enum
- `bool isLoading` - True when loading
- `bool hasData` - True when data is available
- `bool hasError` - True when error occurred
- `bool isSuccess` - True when successfully loaded
- `bool isIdle` - True when not yet fetched

### QueryOptions

Configuration options for queries.

```dart
QueryOptions({
  bool enabled = true,
  VoidCallback? onSuccess,
  void Function(Object error)? onError,
})
```

**Options:**
- `enabled` - Whether the query should execute (default: true)
- `onSuccess` - Callback called on successful fetch
- `onError` - Callback called on fetch error

### QueryClient

Global registry for all queries.

```dart
final client = QueryClient();

// Get or create a query
final query = client.getQuery<T>(key, queryFn, options: options);

// Get existing query
final query = client.getQueryByKey<T>('users');

// Manual fetch
query?.fetch();

// Remove a query
client.removeQuery('users');

// Clear all queries
client.clear();

// Check if query exists
bool exists = client.hasQuery('users');

// Get query count
int count = client.queryCount;
```

## Examples

See the [example app](../../examples/flutter_query_example) for complete working examples:

- API calls with error handling
- Heavy computations
- Multiple widgets sharing queries
- Error recovery patterns

## Advanced Configuration

### Global Cache Configuration

Configure the cache globally for all queries:

```dart
final client = QueryClient(
  config: CacheConfig(
    maxCacheSize: 100 * 1024 * 1024,  // 100MB
    maxEntries: 2000,
    defaultStaleTime: Duration(minutes: 1),
    defaultCacheTime: Duration(minutes: 10),
    evictionPolicy: EvictionPolicy.lru,  // or lfu, fifo
  ),
);
```

### Eviction Policies

Choose how the cache decides what to remove when full:

- **LRU (default)** - Removes least recently accessed entries
- **LFU** - Removes least frequently accessed entries  
- **FIFO** - Removes oldest entries

### Background Refetch Indicator

Use `state.isFetching` to show background activity:

```dart
QueryBuilder<Data>(
  queryKey: 'data',
  queryFn: () => fetchData(),
  options: QueryOptions(staleTime: Duration(minutes: 5)),
  builder: (context, state) {
    return Column(
      children: [
        if (state.isFetching)
          LinearProgressIndicator(),  // Show background activity
        if (state.hasData)
          DataWidget(state.data!),
      ],
    );
  },
)
```

## Phase 2 Complete - What's Next

Phase 2 caching layer is complete! The following features will be added in future phases:

- **Phase 3:** State management adapters (Hooks, Bloc, Riverpod)
- **Phase 4:** Infinite queries for pagination
- **Phase 4:** Mutations with optimistic updates
- **Phase 4:** Offline mutation queue
- **Phase 5:** Production hardening (security, DevTools, testing utilities)

## Architecture

Flutter Query separates async operation logic from UI concerns:

- **Query** - Pure logic class managing async operations
- **QueryState** - Immutable state representation
- **QueryClient** - Global query registry
- **QueryBuilder** - Flutter widget bridge

This separation enables:
- Easy testing (mock queries, not widgets)
- State sharing across widgets
- Clean architecture
- Future caching layer (Phase 2)

## Contributing

Contributions are welcome! This project is in active development.

## License

MIT License - see LICENSE file for details.

## Resources

- [PRD Documentation](../../prd/) - Detailed product requirements
- [Example App](../../examples/flutter_query_example) - Working examples
- [GitHub Repository](https://github.com/yourusername/flutter_query)

---

**Built with ❤️ for the Flutter community**
