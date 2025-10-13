# Phase 2: Caching Layer

**Project:** Flutter Query  
**Phase:** 2 of 6  
**Timeline:** Weeks 3-4  
**Dependencies:** Phase 1 Complete  
**Status:** Planning

---

## 1. Phase Overview

### Purpose

Phase 2 transforms Flutter Query from a simple async operation manager into a sophisticated caching system. This phase adds the intelligence that makes the library practical for production use: knowing when data is fresh versus stale, automatically refetching when needed, managing memory limits, and deduplicating duplicate operations.

### What We Will Build

A comprehensive caching layer that sits between queries and their async operations. The cache stores results from any async source (APIs, databases, files, computations), tracks metadata about each entry, enforces staleness rules, manages memory consumption, and provides inspection tools for debugging. The caching behavior is identical whether you're caching API responses, database query results, or file contents.

### What Makes This Phase Critical

Without caching, every query execution repeats the async operation—hitting the network, re-querying the database, or re-reading files—wasting resources and degrading user experience. With intelligent caching, apps feel instant because data is served from memory while fresh data loads in the background.

**Caching Benefits Across Async Operation Types:**
- **API calls:** Reduce bandwidth, server load, and network latency
- **Database queries:** Avoid expensive queries, reduce battery drain
- **File operations:** Skip disk I/O, improve responsiveness
- **Computations:** Avoid repeating heavy calculations

This phase is where Flutter Query becomes truly valuable regardless of your data source.

---

## 2. Goals and Success Criteria

### Primary Goals

**Implement Intelligent Caching**

Build a cache that knows the difference between fresh data (serve immediately), stale data (serve but refetch), and missing data (fetch and wait). The intelligence comes from time-based staleness tracking and configurable thresholds.

**Manage Memory Effectively**

Ensure the cache doesn't grow without bounds. Implement eviction policies that remove least-used data when memory limits are reached. Handle platform memory pressure signals to avoid out-of-memory errors.

**Deduplicate Network Requests**

When multiple widgets request the same data simultaneously, make only one network request. All requesters wait for the same result, eliminating wasted bandwidth and ensuring consistency.

**Maintain Phase 1 API Compatibility**

Add caching without breaking the API from Phase 1. Developers should be able to enable caching through configuration, not by rewriting their code.

### Success Criteria

**Functional:**
- Queries serve cached data when available
- Stale data triggers background refetch
- Cache entries respect staleness configuration
- Memory usage stays within configured limits
- Duplicate requests are deduplicated
- Cache invalidation works correctly

**Performance:**
- Cache hit: data served in <5ms
- Cache miss: fetch initiated immediately
- Memory overhead: <100 bytes per cache entry metadata
- Eviction: <10ms to evict entries when limit reached

**Quality:**
- Test coverage >85% for cache module
- Zero memory leaks in 24-hour test
- Cache behavior matches React Query patterns
- Clear documentation of caching concepts

**Developer Experience:**
- Caching works with zero configuration (sensible defaults)
- Advanced users can tune staleness and cache time
- Cache inspection tools help debugging
- Migration from Phase 1 requires no code changes

---

## 3. Core Caching Concepts

### Fresh vs Stale vs Missing Data

Understanding these three states is fundamental to how the cache works:

**Fresh Data**

Data is fresh when it was fetched recently enough that we trust it's still accurate. The threshold is configured via `staleTime`. When data is fresh, it's served immediately with no refetch.

Examples:
- User profile from API with staleTime of 5 minutes. If fetched 2 minutes ago, it's fresh.
- Database query with staleTime of 1 minute. If executed 30 seconds ago, serve from cache.
- Config file with staleTime of 1 hour. If read 10 minutes ago, use cached version.

Requesting any of these again serves the cached version immediately without re-executing the async operation.

**Stale Data**

Data is stale when it's older than staleTime but still exists in cache. Stale data is served immediately to avoid loading states, but a background refetch is triggered to get fresh data.

Example: Same profile data, now 7 minutes old. It's stale, so we show it immediately but refetch in background. When fresh data arrives, UI updates seamlessly.

**Missing Data**

Data is missing when it's not in the cache at all, or when it's been evicted. Missing data requires a fetch, and the query shows a loading state until data arrives.

Example: User never viewed this profile before, or it was evicted due to memory limits. We must fetch and wait.

### Cache Time vs Stale Time

Two different time windows control cache behavior:

**Stale Time**

How long data is considered fresh. Default: 0 (immediately stale). This is the window where we trust cached data without refetching.

Setting staleTime: 5 minutes means "this data doesn't change often, trust it for 5 minutes." Perfect for relatively static data like user profiles or configuration.

Setting staleTime: 0 means "always refetch." Perfect for real-time data like live scores or stock prices.

**Cache Time**

How long inactive data stays in cache before being garbage collected. Default: 5 minutes. This is the window where we keep unused data "just in case."

When a query has no active subscribers, its cache entry stays around for cacheTime. If someone requests it during this window, it's served immediately (though might be stale). After cacheTime expires, the entry is removed to free memory.

### The Mental Model

Think of the cache as a smart refrigerator:
- Fresh data: milk you just bought (safe to drink)
- Stale data: milk that's a few days old (probably fine, but check if you can get fresh)
- Missing data: no milk in fridge (must go to store)
- Cache time: how long to keep milk after opening (garbage collection)

---

## 4. Architecture Design

### Cache Entry Structure

Each cache entry contains both data and metadata. The metadata is crucial for intelligent cache management.

Entry components:
- The actual data
- Timestamp when data was fetched
- Timestamp when data was last accessed
- Number of times accessed (for LFU eviction)
- Reference count (how many queries currently using this)
- Staleness configuration (staleTime for this entry)
- Mark for persistence (should this survive app restart?)

The cache is a map from query keys to cache entries. Keys are strings, making lookups fast and predictable.

### Cache Operations

**Get Operation**

When a query requests data:
1. Check if entry exists for this key
2. If not, return null (cache miss)
3. If exists, update "last accessed" timestamp
4. Increment access count
5. Check if data is fresh (compare age to staleTime)
6. Return data with metadata indicating fresh/stale status

**Set Operation**

When a query receives new data:
1. Create or update cache entry for this key
2. Store data and current timestamp
3. Apply staleness configuration
4. Check if cache size exceeds limit
5. If over limit, evict entries based on policy
6. Emit cache change event for inspection tools

**Remove Operation**

When invalidating data:
1. Find entries matching the key pattern
2. Remove from cache map
3. Notify any active queries to refetch
4. Emit cache change event

**Clear Operation**

When clearing entire cache:
1. Remove all entries
2. Notify all active queries
3. Emit cache cleared event

### Request Deduplication

The cache maintains a separate map of in-flight requests. This is distinct from the cache itself because in-flight requests don't have data yet.

When a fetch is initiated:
1. Check if identical fetch is already in progress
2. If yes, return the existing future
3. If no, store the future in in-flight map
4. When future completes, remove from in-flight map
5. Store result in cache

This ensures that 100 widgets requesting the same data simultaneously trigger only one network request.

### Memory Management

Memory management has three layers:

**Configured Limit**

Developers set a maximum cache size in bytes (default: 50MB). When adding an entry would exceed this limit, we evict entries until we're under the limit.

**Eviction Policies**

Three policies supported:

LRU (Least Recently Used): Evict entries that haven't been accessed recently. Best for general use where recent data is more likely to be needed again.

LFU (Least Frequently Used): Evict entries that are rarely accessed. Best when some data is frequently reused while other data is one-off.

FIFO (First In First Out): Evict oldest entries. Simplest policy but least intelligent.

Default is LRU because it works well for most access patterns.

**Memory Pressure Handling**

The cache listens to platform memory pressure events. When the system signals low memory:
- Low pressure: evict 25% of cache
- Medium pressure: evict 50% of cache  
- Critical pressure: evict everything except active queries

This prevents the OS from killing the app due to memory issues.

### Thread Safety

For Phase 2, we still assume single-isolate operation. However, we add synchronization primitives that will enable multi-isolate support in Phase 5.

Each cache operation is protected by a lock keyed to the query key. This prevents race conditions if multiple async operations try to modify the same cache entry simultaneously.

The lock implementation uses Dart's Completer pattern to create async locks. When an operation needs exclusive access, it acquires the lock, performs the operation, and releases the lock.

---

## 5. Implementation Details

### Staleness Checking

Staleness is checked at the moment data is requested, not proactively. This is important because:
- No background timers needed
- No wasted work checking staleness of unused data
- Predictable behavior tied to user actions

When checking staleness:
1. Get entry from cache
2. Calculate age: now - entry.timestamp
3. Compare age to entry.staleTime
4. If age < staleTime: fresh
5. If age >= staleTime: stale

Simple time comparison, very fast.

### Background Refetching

When serving stale data, we trigger a background refetch without blocking the caller. This requires careful coordination:

1. Return stale data immediately to caller
2. Start fetch asynchronously
3. When fetch completes, update cache
4. Emit new state to all subscribers
5. If fetch fails, keep stale data (don't remove it)

The query shows stale data while isFetching becomes true, indicating background activity. When fresh data arrives, isFetching becomes false and data updates.

### Cache Size Estimation

Dart doesn't provide a built-in way to measure object memory size. We estimate using heuristics:

- Each string: 2 bytes per character
- Each number: 8 bytes
- Each boolean: 1 byte
- Each list: 8 bytes + size of elements
- Each map: 16 bytes + size of entries
- Each object: 16 bytes + size of fields

These estimates aren't perfect but are good enough to prevent unbounded growth. We err on the side of overestimating to be conservative.

### Eviction Algorithm

When cache exceeds limit:
1. Calculate how much to evict (target: 10% below limit)
2. Sort entries by policy (LRU: by lastAccessed, LFU: by accessCount)
3. Skip entries with active subscribers (reference count > 0)
4. Remove entries from bottom of sorted list until target reached
5. Dispose removed entries properly

Eviction happens synchronously during the set operation that triggers it. This keeps cache size predictable.

### Cache Invalidation Patterns

Invalidation is how developers tell the cache that data is no longer trustworthy.

**Exact Match Invalidation**

Invalidate one specific query: `invalidateQuery('user:123')`

This removes the cache entry and tells the query to refetch if it's active.

**Prefix Match Invalidation**

Invalidate all queries with a key prefix: `invalidateQueriesWithPrefix('user:')`

This is useful for invalidating all user-related queries when user data changes.

**Predicate Invalidation**

Invalidate queries matching a custom condition: `invalidateQueriesWhere((key) => key.contains('users'))`

Maximum flexibility for complex invalidation needs.

All invalidation patterns notify affected queries immediately, so UIs update.

---

## 6. Configuration API

### Query-Level Configuration

Each query can configure its own caching behavior:

- `staleTime`: Duration - how long data stays fresh (default: 0)
- `cacheTime`: Duration - how long inactive data stays cached (default: 5 minutes)

Configuration is passed through QueryBuilder options. Phase 1 queries without configuration get sensible defaults.

### Global Configuration

QueryClient can set global defaults that apply to all queries unless overridden:

- `defaultStaleTime`: default staleness window
- `defaultCacheTime`: default cache retention
- `maxCacheSize`: maximum cache bytes (default: 50MB)
- `evictionPolicy`: which policy to use (default: LRU)

This allows application-wide tuning without modifying every query.

### Dynamic Reconfiguration

Cache configuration can change at runtime:

- Adjust cache size limit based on device capabilities
- Change eviction policy based on usage patterns
- Modify default staleness for offline mode

The cache responds to configuration changes immediately, potentially triggering eviction if limits are reduced.

---

## 7. Developer Experience

### Zero-Configuration Usage

Developers from Phase 1 get caching automatically without any code changes. Default configuration provides reasonable behavior for most use cases.

Adding a query remains the same:
```
QueryBuilder(
  queryKey: 'users',
  queryFn: () => fetchUsers(),
  builder: (context, state) => buildUI(state),
)
```

Caching happens transparently. First fetch hits network, subsequent fetches use cache.

### Configuring Staleness

For data that doesn't change often, developers can extend staleTime:

```
QueryBuilder(
  queryKey: 'userProfile',
  queryFn: () => fetchProfile(),
  options: QueryOptions(
    staleTime: Duration(minutes: 5),
  ),
  builder: (context, state) => buildUI(state),
)
```

Now the profile data stays fresh for 5 minutes. Accessing it within that window serves cached data with no refetch.

### Manual Invalidation

When developers know data has changed (after a mutation), they can invalidate:

```
await updateUserProfile(newData);
queryClient.invalidateQuery('userProfile');
```

This removes the cached profile, forcing a refetch on next access.

### Cache Inspection

For debugging, developers can inspect cache state:

```
final cacheInfo = queryClient.getCacheInfo();
print('Entries: ${cacheInfo.entryCount}');
print('Size: ${cacheInfo.sizeBytes}');
print('Hit rate: ${cacheInfo.hitRate}');
```

This helps diagnose caching issues and tune configuration.

---

## 8. Testing Strategy

### Unit Tests

**Cache Entry Management**
- Store and retrieve data correctly
- Metadata updates properly
- Staleness detection accurate
- Reference counting works

**Eviction Policies**
- LRU evicts least recently used
- LFU evicts least frequently used
- FIFO evicts oldest
- Active entries never evicted

**Request Deduplication**
- Simultaneous requests deduplicated
- Completed requests removed from in-flight map
- Failed requests removed properly
- Cancellation handled correctly

**Memory Management**
- Size estimation reasonably accurate
- Eviction triggers at correct threshold
- Memory pressure handling works
- No memory leaks

### Integration Tests

**Cache Lifecycle**
- Fresh data served without refetch
- Stale data serves then refetches
- Missing data fetches and waits
- Cache time cleanup works

**Multi-Widget Scenarios**
- Multiple widgets share cache
- Invalidation notifies all widgets
- Reference counting prevents premature disposal
- Memory doesn't grow with widget count

**Memory Pressure**
- Cache responds to pressure events
- Critical pressure preserves active queries
- App doesn't crash under pressure

### Performance Tests

**Cache Performance**
- Get operation: <5ms p99
- Set operation: <10ms p99
- Eviction: <10ms for 1000 entries
- Memory usage: <100 bytes metadata per entry

**Load Tests**
- 10,000 cache entries without degradation
- 1,000 simultaneous requests deduplicated correctly
- 24-hour continuous operation stable

---

## 9. What We're Not Building

### No Persistence Yet

Cache is in-memory only. Data is lost on app restart. Phase 5 adds optional persistence to disk.

### No Advanced Invalidation

No automatic invalidation based on mutations. Developers must manually invalidate. Phase 4 adds automatic invalidation on mutations.

### No Partial Updates

Can't update part of a cached entry. Must replace the entire entry. Phase 4 may add partial updates for complex use cases.

### No Multi-Isolate Support

Cache only works within one isolate. Phase 5 adds cross-isolate cache access for background processing.

---

## 10. Risks and Mitigation

### Risk: Incorrect Staleness Behavior

If staleness logic is buggy, apps might show stale data when they shouldn't, or refetch when they shouldn't.

Mitigation: Extensive time-based testing. Test clock manipulation to verify staleness detection at boundaries. Comprehensive test coverage of staleness paths.

### Risk: Memory Leaks from Cache Growth

If eviction doesn't work correctly, cache will grow without bounds until app crashes.

Mitigation: Memory profiling tests. Automated tests that add 10,000+ entries and verify eviction happens. 24-hour stress test monitoring memory usage.

### Risk: Deduplication Bugs

If deduplication fails, apps waste bandwidth with duplicate requests. If it's too aggressive, apps might not get fresh data when needed.

Mitigation: Test simultaneous request scenarios thoroughly. Verify in-flight map cleanup. Test with various timing and failure scenarios.

### Risk: Poor Performance

If cache operations are slow, they negate the benefits of caching.

Mitigation: Performance benchmarks for all cache operations. Profile with realistic data volumes. Optimize hot paths.

---

## 11. Success Validation

### How We Know Phase 2 Succeeded

**Functional Correctness:**
- All cache operations work correctly
- Staleness detection is accurate
- Deduplication eliminates duplicate requests
- Memory management prevents unbounded growth

**Performance:**
- Cache operations meet latency targets
- No perceptible delay from caching
- Memory usage is reasonable
- Load tests pass

**API Quality:**
- Phase 1 code works unchanged
- Configuration is intuitive
- Defaults work well for common cases
- Advanced tuning is possible

**Production Readiness:**
- 24-hour stress test passes
- Memory profiling shows no leaks
- Real app testing shows benefits
- Documentation is complete

---

## 12. Deliverables

### Code Deliverables

- Cache entry structure
- Cache storage implementation
- Staleness tracking
- Eviction policies (LRU, LFU, FIFO)
- Request deduplication
- Memory management
- Cache invalidation
- Configuration API
- Complete test suite

### Documentation Deliverables

- Caching concepts guide
- Configuration reference
- Best practices for staleness
- Cache inspection guide
- Migration guide from Phase 1
- Performance tuning guide

### Quality Deliverables

- Test coverage >85%
- Performance benchmarks
- Memory profiling results
- Load test results

---

## 13. Timeline

### Week 3

**Days 1-2:** Cache structure implementation
- Cache entry design
- Storage implementation
- Basic get/set operations

**Days 3-4:** Staleness and deduplication
- Staleness tracking
- Background refetch logic
- Request deduplication

**Day 5:** Memory management
- Size estimation
- Eviction policies
- Memory pressure handling

### Week 4

**Days 1-2:** Invalidation and configuration
- Invalidation patterns
- Configuration API
- Global defaults

**Days 3-4:** Testing and optimization
- Comprehensive test suite
- Performance testing
- Memory profiling
- Optimization

**Day 5:** Documentation and validation
- Documentation writing
- Migration guide
- Phase validation
- Prepare for Phase 3

---

## 14. Next Phase Preview

Phase 3 will build state management adapters (Hooks, Bloc, Riverpod) that make Flutter Query accessible to developers using different state management approaches. The caching layer from Phase 2 will work identically across all adapters, ensuring consistent behavior.

The cache API must be stable before Phase 3 begins, as adapters will build directly on it.

---

**Phase Owner:** Development Team  
**Phase Status:** Planning  
**Dependencies:** Phase 1 Complete  
**Next Milestone:** Cache Design Review  
**Approval Required:** Yes

