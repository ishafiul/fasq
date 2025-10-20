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

### Examples
- **[fasq_example](./examples/fasq_example/)** - Comprehensive examples with caching, mutations, forms, and infinite queries

## 🚀 Getting Started

FASQ is currently in active development. 

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
│   ├── fasq/          # Core package (Phases 1-3)
│   ├── fasq_hooks/    # Hooks adapter (Phase 3)
│   ├── fasq_bloc/     # Bloc adapter (Phase 3)
│   └── fasq_riverpod/ # Riverpod adapter (Phase 3)
├── examples/
│   └── fasq_example/  # Example app with 7 demos
├── prd/                        # Product Requirements Documents
├── melos.yaml                  # Melos configuration
├── pubspec.yaml               # Root workspace configuration
└── README.md                  # This file
```

## 📚 Documentation

See the [PRD folder](./prd/) for comprehensive product requirements and implementation phases:

- [Overview](./prd/README.md) - Project roadmap and phase overview
- ✅ Phase 1: MVP - Core Query System (Complete)
- ✅ Phase 2: Caching Layer (Complete)
- ✅ Phase 3: State Management Adapters (Complete)
- 🔄 Phase 4: Advanced Features (Planned)
- 🔄 Phase 5: Production Hardening (Planned)
- 🔄 Phase 6: Polish and Release (Planned)

## ✅ Features (Implemented)

**Phase 1-3 Complete:**

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

## 🔄 Features (Phases 4-5)

- **Phase 4 - Advanced Features:**

- ✅ **Infinite Queries** - Pagination and infinite scroll with memory management
- ✅ **Dependent Queries** - Chain queries using enabled gating
- 🔄 **Dependent Queries** - Type-safe query dependencies and chaining
- 🔄 **Optimistic Updates** - Advanced optimistic UI with automatic rollback
- 🔄 **Offline Mutation Queue** - Persist mutations offline and sync when online
- 🔄 **Parallel Queries** - Batch multiple queries with coordinated loading states

**Phase 5 - Production Hardening:**

- 🔄 **Security** - Encrypted storage, secure cache entries, input validation
- 🔄 **Performance** - Isolate support for large JSON, cache optimization
- 🔄 **Reliability** - Intelligent retry with exponential backoff, circuit breakers
- 🔄 **DevTools Extension** - Query inspector, cache visualizer, network timeline
- 🔄 **Testing Utilities** - Mock QueryClient, time control, test helpers
- 🔄 **Production Monitoring** - Logging strategy, performance metrics, error tracking

## 💡 What You Can Build Today

you can already build:

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

**New in Phase 4:**
- Infinite scroll (social feeds, product catalogs)

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


