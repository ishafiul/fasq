## 0.3.5

 - **FEAT**: harden persistence across cache layers (#36).
 - **DOCS**: sync readme versions (#35).

## 0.3.4

 - **FEAT**: allow typed meta messages (#34).
 - **FEAT**: refine global query effects (#33).
 - **FEAT**: add context-aware query observers (#32).
 - **FEAT**: allow injecting manual query client (#31).
 - **FEAT**: update SEO and metadata handling.

## 0.3.3

- **FIX**: align docs, entrypoints, and tests around typed QueryKey usage (#30).
- **FIX**: add Flutter example apps for fasq, bloc, hooks, and riverpod packages (#30).

## 0.3.2

 - **FEAT**: add type-safe query keys support (#28).

## 0.3.1+1

 - **FIX**: resolve cache type safety issue by reconstructing CacheEntry instead of casting (#27).
 - **FIX**: enhance infinite query options and state management (#25).

## 0.3.1

 - **REFACTOR**(performance): simplify isolate pool initialization (#24).
 - **FIX**: improve cache staleness handling and query state management (#22).
 - **FIX**: comprehensive fixes for reference counting and loading state (#21).
 - **FIX**: prevent negative reference count in Query and InfiniteQuery (#18).
 - **FEAT**: clear cache when query is disposed to ensure fresh data on revisit (#20).

## 0.3.0

> Note: This release has breaking changes.

 - **FIX**: resolve all analysis issues and prepare packages for publishing (#16).
 - **FIX**: resolve critical issues and improve code quality (#15).
 - **FIX**: security (#9).
 - **FEAT**: implement comprehensive performance optimization system (#13).
 - **FEAT**: integrate SecurityPlugin with QueryCache (#12).
 - **FEAT**: complete updateEncryptionKey implementation with real persistence (#10).
 - **FEAT**: prefetching (#8).
 - **FEAT**: implement parallel queries across all adapters (#6).
 - **FEAT**: offline mutation queue (#5).
 - **FEAT**: dependent queries (#4).
 - **FEAT**: infinite queries (#3).
 - **DOCS**: Clean up README by removing phase references and PRD mentions (#14).
 - **BREAKING** **FEAT**: Extract security features to separate fasq_security package (#11).

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-01-14

### Added - Security Package Extraction

**Security Plugin Architecture:**
- Abstract security interfaces for modular security implementation
- `SecurityPlugin` interface for pluggable security providers
- `SecurityProvider` interface for secure key storage
- `EncryptionProvider` interface for encryption/decryption operations
- `PersistenceProvider` interface for encrypted data persistence

**New Security Package:**
- `fasq_security` package with complete security implementation
- `DefaultSecurityPlugin` with production-ready security features
- `CryptoEncryptionProvider` with AES-GCM encryption and isolate support
- `SecureStorageProvider` with platform-specific secure storage
- `DriftPersistenceProvider` with efficient batch operations

### Changed

**Breaking Changes:**
- Removed built-in security dependencies (`encrypt`, `flutter_secure_storage`, `shared_preferences`)
- Security functionality moved to separate `fasq_security` package
- `PersistenceOptions.encrypt` and `PersistenceOptions.encryptionKey` marked as deprecated

**Migration Required:**
- Install `fasq_security` package for security features
- Update QueryClient to use `SecurityPlugin` instead of `PersistenceOptions`
- See migration guide in `fasq_security` package documentation

### Removed

- `EncryptionService` class (moved to `fasq_security`)
- `SecureStorage` class (moved to `fasq_security`)
- `EncryptedCachePersister` class (moved to `fasq_security`)
- Security-related dependencies from core package

### Performance

- **Bundle Size**: 75% reduction in core package size
- **Dependencies**: Core package now has zero security dependencies
- **Modularity**: Security features are now optional and pluggable

## [0.1.0] - 2025-01-14

### Added - Phase 2: Production-Ready Caching Layer

**Intelligent Caching:**
- `CacheEntry` class for storing data with metadata
- `QueryCache` for cache storage and management
- Staleness detection with configurable `staleTime`
- Automatic garbage collection with configurable `cacheTime`
- Fresh vs stale vs missing data states
- Background refetching for stale data

**Memory Management:**
- Configurable cache size limits (default: 50MB)
- Three eviction policies: LRU (default), LFU, FIFO
- Automatic eviction when cache exceeds limits
- Active query preservation during eviction
- Memory pressure handling (ready for Phase 5 platform integration)

**Request Deduplication:**
- Concurrent requests for same key return same Future
- Eliminates duplicate network calls
- Automatic cleanup of completed requests

**Cache Invalidation:**
- `invalidateQuery(key)` - invalidate single query
- `invalidateQueries(keys)` - invalidate multiple queries
- `invalidateQueriesWithPrefix(prefix)` - pattern matching
- `invalidateQueriesWhere(predicate)` - custom logic

**Cache Inspection & Metrics:**
- `CacheMetrics` tracking hits, misses, hit rate
- `CacheInfo` for cache state snapshots
- `getCacheInfo()` - inspect cache state
- `getCacheKeys()` - list all cached keys
- `inspectEntry(key)` - examine specific entry

**Thread Safety:**
- `AsyncLock` for preventing race conditions
- Lock-per-key for concurrent access safety
- Timeout protection (30s) for deadlock prevention

**Configuration:**
- `CacheConfig` for global cache settings
- `QueryOptions` extended with `staleTime`, `cacheTime`, `refetchOnMount`
- Sensible production defaults

**QueryState Enhancements:**
- Added `isFetching` field for background refetch indication
- Added `dataUpdatedAt` timestamp
- Added `isStale` computed property

**Developer Experience:**
- Zero breaking changes from Phase 1
- Caching works automatically with zero configuration
- Advanced users can tune all parameters
- Comprehensive documentation

### Changed

- `QueryClient` now manages a `QueryCache` instance
- `Query.fetch()` now checks cache before fetching
- `QueryState` includes cache-related metadata
- `QueryOptions` extended with caching fields (all optional)

### Performance

- Cache get operations: <5ms
- Cache set operations: <10ms
- Request deduplication: 100 widgets = 1 request
- Memory overhead: <100 bytes per cache entry
- Handles 10,000+ cache entries efficiently

### Testing

- 34 new cache-specific tests
- Staleness detection tests
- Eviction policy tests
- Request deduplication tests
- Cache metrics tests
- Thread safety tests

### Backward Compatibility

✅ **Zero Breaking Changes**
- All Phase 1 code works without modification
- All new QueryOptions fields are optional
- Cache is transparent to Phase 1 users
- Default configuration provides good behavior

## [0.0.1] - 2025-01-13

### Added - Phase 1 MVP

**Core Components:**
- `Query` class for managing async operations and state
- `QueryState` immutable state class with comprehensive state tracking
- `QueryStatus` enum for lifecycle states (idle, loading, success, error)
- `QueryClient` singleton for global query registry
- `QueryBuilder` widget for declarative UI based on query state
- `QueryOptions` for configuring query behavior

**Features:**
- Automatic state management for any async operation
- Support for API calls, database queries, file operations, and any Future-based task
- Query sharing across multiple widgets with the same key
- Automatic cleanup with reference counting
- Manual refetch capability
- Lifecycle callbacks (onSuccess, onError)
- Conditional query execution with `enabled` option

**Developer Experience:**
- Comprehensive dartdoc documentation
- Type-safe generic APIs
- Clean, minimal boilerplate
- Example app with multiple async operation types

**Testing:**
- 60 unit, widget, and integration tests
- >85% test coverage
- Memory leak detection tests
- Lifecycle and state transition tests

### Known Limitations

This is the Phase 1 MVP release. The following features are planned for future phases:

- **Phase 2:** Intelligent caching with staleness detection
- **Phase 2:** Request deduplication for concurrent queries
- **Phase 2:** Automatic background refetching
- **Phase 3:** State management adapters (Hooks, Bloc, Riverpod)
- **Phase 4:** Infinite queries for pagination
- **Phase 4:** Mutations with optimistic updates
- **Phase 4:** Offline mutation queue
- **Phase 5:** Production hardening (security, performance optimization)
- **Phase 5:** DevTools extension
- **Phase 5:** Testing utilities package

## [Unreleased]

Future releases will add caching, request deduplication, state management adapters, and production-ready features according to the phased development plan.

---

For the complete development roadmap, see the [PRD documentation](../../prd/).
