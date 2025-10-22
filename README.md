# FASQ

**FASQ (Flutter Async State Query)** - A powerful async state management library for Flutter. Handles API calls, database queries, file operations, and any async operation with intelligent caching, automatic refetching, and error recovery.

Inspired by React Query and SWR, built specifically for Flutter.


## 📦 Packages

This monorepo contains the following packages:

### Core Package
- **[fasq](./packages/fasq/)** - The core async state management library with queries, mutations, and caching

### State Management Adapters
- **[fasq_hooks](./packages/fasq_hooks/)** - Flutter Hooks adapter (useQuery, useMutation)
- **[fasq_bloc](./packages/fasq_bloc/)** - Bloc/Cubit adapter (QueryCubit, MutationCubit)
- **[fasq_riverpod](./packages/fasq_riverpod/)** - Riverpod adapter (queryProvider, mutationProvider)

### Security Package
- **[fasq_security](./packages/fasq_security/)** - Security plugin with encryption and secure storage

### Examples
- **[fasq_example](./examples/fasq_example/)** - Comprehensive examples with caching, mutations, forms, and infinite queries

## 🚀 Getting Started

FASQ is production-ready and actively maintained. 

### Prerequisites

- Flutter SDK: `>=3.10.0`
- Dart SDK: `>=3.7.0`
- Melos: for managing the monorepo

### Quick Start (For Users)

**Option 1: Core Package Only**
```yaml
dependencies:
  fasq:
    git:
      url: https://github.com/yourusername/fasq
      path: packages/fasq
```

**Option 2: With Your Favorite Adapter**
```yaml
dependencies:
  fasq_hooks:  # For Flutter Hooks users
  # OR
  fasq_bloc:   # For Bloc/Cubit users
  # OR
  fasq_riverpod: # For Riverpod users
    git:
      url: https://github.com/yourusername/fasq
      path: packages/fasq_riverpod
```

### Developer Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd fasq
   ```

2. **Install Melos** (if not already installed)
   ```bash
   dart pub global activate melos
   ```

3. **Bootstrap the workspace**
   ```bash
   melos bootstrap
   ```

This will install all dependencies and link local packages.

## 🛠️ Development

### Available Melos Scripts

```bash
# Run flutter analyze in all packages
melos analyze

# Format all packages
melos format

# Run tests in all packages
melos test

# Clean all packages
melos clean

# Get dependencies for all packages
melos get
```

### Working on the Core Package

```bash
cd packages/fasq
flutter test
```

### Running the Example App

```bash
cd examples/fasq_example
flutter run
```

## 📁 Project Structure

```
fasq/
├── packages/
│   ├── fasq/          # Core package
│   ├── fasq_hooks/    # Hooks adapter
│   ├── fasq_bloc/     # Bloc adapter
│   ├── fasq_riverpod/ # Riverpod adapter
│   └── fasq_security/ # Security plugin
├── examples/
│   └── fasq_example/  # Example app with comprehensive demos
├── melos.yaml         # Melos configuration
├── pubspec.yaml       # Root workspace configuration
└── README.md          # This file
```

## ✅ Features (Implemented)

**Core Features:**

- ✅ **Simple API** - Works with any Future-returning function
- ✅ **Automatic State Management** - Loading, error, success states handled automatically
- ✅ **Intelligent Caching** - Automatic caching with staleness detection and configurable freshness
- ✅ **Background Refetching** - Stale-while-revalidate pattern (instant cache hits + background updates)
- ✅ **Request Deduplication** - Concurrent requests for same data trigger only one network call
- ✅ **Memory Management** - LRU/LFU/FIFO eviction policies with configurable limits
- ✅ **Cache Invalidation** - Flexible patterns for invalidating cached data
- ✅ **Mutations** - Full mutation support with MutationBuilder and state management
- ✅ **Form Submissions** - Built-in support for POST/PUT/DELETE operations
- ✅ **State Management Adapters** - Works with Hooks, Bloc, Riverpod
- ✅ **Thread Safe** - Concurrent access protection with async locks
- ✅ **Type Safe** - Full generic type support

**Advanced Features:**

- ✅ **Infinite Queries** - Pagination and infinite scroll with memory management
- ✅ **Dependent Queries** - Chain queries using enabled gating
- ✅ **Offline Mutation Queue** - Persist mutations offline and sync when online
- ✅ **Security Plugin Architecture** - Modular security with encryption and secure storage
- ✅ **Encrypted Persistence** - AES-GCM encryption with platform-specific secure storage
- ✅ **Performance Optimization** - Hot cache, isolate pool, performance monitoring
- ✅ **Isolate Support** - Background processing for large data operations
- ✅ **Performance Metrics** - Comprehensive tracking and reporting

## 🔄 Future Enhancements

**Reliability Improvements:**
- 🔄 **Intelligent Retry Logic** - Exponential backoff with jitter for transient failures
- 🔄 **Circuit Breaker Pattern** - Prevent cascade failures when services are down
- 🔄 **Request Cancellation** - Robust cancellation system with resource cleanup

**Memory Management:**
- 🔄 **Memory Pressure Handling** - Automatic cache eviction on low-memory devices
- 🔄 **Leak Prevention** - Multi-layered leak detection and prevention system
- 🔄 **Reference Counting** - Enhanced reference counting with validation

**Developer Tools:**
- 🔄 **DevTools Extension** - Query inspector, cache visualizer, network timeline
- 🔄 **Testing Utilities** - Mock QueryClient, time control, comprehensive test helpers
- 🔄 **Enhanced Debugging** - Better logging, performance profiling, error tracking

**Production Monitoring:**
- 🔄 **Logging Strategy** - Configurable logging levels for dev vs production
- 🔄 **Performance Metrics** - Exposed metrics for monitoring and analytics
- 🔄 **Error Tracking** - Integration guidance for crash reporting services

## 💡 What You Can Build Today

**✅ Data Fetching Apps:**
- API-driven applications with automatic caching
- Real-time dashboards with background refresh
- Offline-capable apps (cache-first, then update)
- Multi-screen apps with shared query state

**✅ Form-Heavy Apps:**
- User registration and login flows
- CRUD applications (Create, Read, Update, Delete)
- Multi-step forms with server validation
- File upload with progress tracking

**✅ Complex State Management:**
- Choose your stack: Core, Hooks, Bloc, or Riverpod
- Mix and match adapters in same app
- Migrate between adapters incrementally
- Share query state across architecture boundaries

**✅ Advanced Features:**
- Infinite scroll (social feeds, product catalogs)
- Dependent queries (user → posts, category → products)
- Offline mutation queue (queue actions when offline, sync when online)
- Encrypted persistence for sensitive data
- Performance monitoring and optimization

### Infinite Queries (overview)

```dart
// Hooks
final state = useInfiniteQuery<List<Post>, int>(
  'posts',
  (page) => api.fetchPosts(page: page),
  InfiniteQueryOptions(
    getNextPageParam: (pages, last) => pages.length + 1,
  ),
);

// Bloc
final cubit = InfiniteQueryCubit<List<Post>, int>(
  key: 'posts',
  queryFn: (page) => api.fetchPosts(page: page),
);

// Riverpod
final provider = infiniteQueryProvider<List<Post>, int>(
  'posts',
  (page) => api.fetchPosts(page: page),
);
```

### Dependent Queries (overview)

```dart
// Hooks
final userQuery = useQuery<User>('user-1', () => api.fetchUser(1));
final postsQuery = useQuery<List<Post>>(
  'posts-${userQuery.data?.id}',
  () => api.fetchUserPosts(userQuery.data!.id),
  QueryOptions(enabled: userQuery.hasData),
);

// Bloc
final userCubit = QueryCubit<User>('user-1', () => api.fetchUser(1));
final postsCubit = QueryCubit<List<Post>>(
  'posts-${userCubit.state.data?.id}',
  () => api.fetchUserPosts(userCubit.state.data!.id),
  QueryOptions(enabled: userCubit.state.hasData),
);
```

### Offline Mutation Queue (overview)

```dart
// Hooks
final mutation = useMutation<String, String>(
  mutationFn: (data) => api.createPost(data),
  options: const MutationOptions(
    queueWhenOffline: true,
    maxRetries: 3,
  ),
);

// Bloc
final mutationCubit = MutationCubit<String, String>(
  mutationFn: (data) => api.createPost(data),
  options: const MutationOptions(queueWhenOffline: true),
);

// Riverpod
final mutationProvider = mutationProvider<String, String>(
  mutationFn: (data) => api.createPost(data),
  options: const MutationOptions(queueWhenOffline: true),
);
```

## 🤝 Contributing

Contributions are welcome! Please read the contributing guidelines before submitting a PR.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by [TanStack Query](https://tanstack.com/query) (React Query)
- Inspired by [SWR](https://swr.vercel.app/)
- Built for the Flutter community

---


