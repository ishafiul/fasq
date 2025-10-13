# Phase 4: Advanced Features

**Project:** Flutter Query  
**Phase:** 4 of 6  
**Timeline:** Weeks 7-9  
**Dependencies:** Phases 1, 2, 3 Complete  
**Status:** Planning

---

## 1. Phase Overview

### Purpose

Phase 4 adds sophisticated query patterns that enable complex real-world use cases: infinite scrolling, dependent data fetching, optimistic UI updates, parallel queries, and offline-first workflows. These features transform Flutter Query from a simple data fetcher into a comprehensive solution for complex application requirements.

### What We Will Build

Four major feature categories:
1. Infinite queries for pagination and infinite scroll
2. Dependent queries that wait for prerequisite data
3. Mutations with optimistic updates and automatic rollback
4. Offline mutation queue with automatic retry

Each feature must work seamlessly across all three adapters (Hooks, Bloc, Riverpod) from Phase 3.

---

## 2. Goals and Success Criteria

### Primary Goals

**Enable Pagination Without Boilerplate**

Infinite scroll is common but tedious to implement correctly. Developers should be able to add pagination with minimal code, getting proper loading states, error handling, and memory management automatically.

**Support Complex Data Dependencies**

Real applications often need data A before fetching data B. The library should make these dependency chains explicit and handle them correctly, including error propagation and loading states.

**Make Optimistic Updates Safe**

Optimistic updates improve perceived performance but are risky. The library should make them easy to implement correctly, with automatic rollback on failure and proper conflict handling.

**Enable Offline-First Workflows**

Mobile apps need to work offline. Mutations should queue when offline and sync automatically when connectivity returns, without data loss or corruption.

### Success Criteria

**Infinite Queries:**
- Smooth infinite scroll with no UI flicker
- Proper loading indicators between pages
- Error on page N doesn't lose pages 1..N-1
- Memory efficient for hundreds of pages
- Works identically across all adapters

**Dependent Queries:**
- Queries wait for dependencies correctly
- Error in dependency prevents dependent query
- Loading states cascade properly
- Type-safe dependency access
- No race conditions in dependency chains

**Optimistic Updates:**
- UI updates instantly on mutation
- Automatic rollback on error
- Server data merges on success
- Concurrent mutations handled correctly
- Cache consistency maintained

**Offline Queue:**
- Mutations persist across app restarts
- Queue processes in order
- Retries on network restoration
- Handles conflicts gracefully
- User feedback for pending mutations

---

## 3. Infinite Queries

### The Problem

Traditional pagination requires tracking page numbers, loading states, errors, and accumulated data manually. Fetching page 5 means somehow preserving pages 1-4 while loading 5. Errors on page 5 shouldn't lose earlier pages. Infinite scroll needs to know when to fetch the next page.

### The Solution

InfiniteQuery maintains a list of pages instead of single data value. It knows how to fetch the next page, how to determine if more pages exist, and how to accumulate pages efficiently.

### Architecture

**Page Structure**

Each page contains:
- The page data
- The page parameter used to fetch it
- Whether this page has errors
- When this page was fetched

The query maintains an ordered list of pages.

**Fetching Next Page**

When fetchNextPage() is called:
1. Determine next page parameter using getNextPageParam function
2. If it returns null, no more pages exist
3. Otherwise, fetch using the page parameter
4. When data arrives, append to pages list
5. Update hasNextPage based on getNextPageParam result

**Fetching Previous Page**

Similar to next page but prepends to list. Useful for bidirectional infinite scroll.

**Error Handling**

If page N fails to load:
- Store error in page N's entry
- Keep pages 1..N-1 intact
- Allow retry of page N specifically
- Don't prevent fetching page N+1 later

This prevents the all-or-nothing problem where any error loses all data.

### State Shape

InfiniteQueryState contains:
- pages: List<PageData>
- hasNextPage: bool
- hasPreviousPage: bool
- isFetchingNextPage: bool
- isFetchingPreviousPage: bool
- All normal QueryState fields

### Configuration

Developers provide:
- `queryFn`: Function that takes page param and returns data
- `getNextPageParam`: Function that determines next page param from current page
- `getPreviousPageParam`: (Optional) for bidirectional scroll

Example flow:
```
Page 0: param = 0
Fetch returns {data: [...], nextCursor: 10}
getNextPageParam returns 10

Page 1: param = 10
Fetch returns {data: [...], nextCursor: 20}
getNextPageParam returns 20

And so on...
```

### Memory Management

Infinite queries can grow large. We add max pages configuration:
- `maxPages`: Maximum pages to keep in memory
- When limit reached, evict oldest pages
- Evicted pages can be refetched if user scrolls back
- Configurable per query based on data size

### Adapter Integration

Each adapter exposes infinite queries idiomatically:

**Hooks:** useInfiniteQuery()  
**Bloc:** InfiniteQueryCubit  
**Riverpod:** infiniteQueryProvider

Same behavior, different syntax.

---

## 4. Dependent Queries

### The Problem

Fetching user's posts requires the user ID, which comes from a previous query. Fetching products in a category requires the category, which comes from navigation. Dependencies must be explicit, typed, and handled correctly.

### The Solution

Queries can specify dependencies that must resolve before fetching. Dependencies can be other queries or any data that might not be available yet.

### Implementation Approaches

**Simple Approach: enabled Flag**

Query doesn't fetch until enabled becomes true:

```
useQuery(
  'posts',
  () => fetchPosts(userId),
  enabled: userId != null,
)
```

When userId is null, query stays idle. When userId becomes available, query fetches automatically.

**Advanced Approach: Chained Queries**

One query's result feeds into the next:

```
final userQuery = useQuery('user', () => fetchUser());
final postsQuery = useQuery(
  'posts:${userQuery.data?.id}',
  () => fetchPosts(userQuery.data!.id),
  enabled: userQuery.isSuccess,
);
```

Posts query waits for user query to succeed, then fetches using user ID.

### Error Propagation

If dependency query errors:
- Dependent query remains idle
- Dependent query shows no error (it never tried)
- UI can check dependency error state and display appropriately

This prevents cascade failures where one error triggers many errors.

### Loading States

Loading states cascade naturally:
- Dependency loading → dependent shows idle
- Dependency succeeds → dependent starts loading
- Dependent succeeds → both show data

This gives users appropriate feedback at each stage.

### Type Safety

Dependencies must be type-safe:
- If depending on query data, check data exists before accessing
- Enabled flag prevents query when dependency isn't ready
- TypeScript/Dart's type system prevents null reference errors

---

## 5. Mutations

### The Problem

Queries fetch data, but mutations change data. Mutations need different behavior:
- Only execute when explicitly called (not automatic)
- Update cache after success
- Show loading state during mutation
- Handle errors from mutation
- Support optimistic updates

### The Solution

Mutation is a new primitive, similar to Query but for writes instead of reads.

### Mutation Lifecycle

Idle → start mutation → Loading → Success or Error → Idle

Unlike queries, mutations don't auto-execute. They wait for explicit call.

### Basic Mutation

Mutation signature:

```
useMutation(
  (variables) => mutationFn(variables),
  options: MutationOptions(
    onSuccess: (data, variables) => handleSuccess(),
    onError: (error, variables) => handleError(),
  ),
)
```

Calling `mutate(variables)` triggers the mutation.

### Cache Integration

After successful mutation, related queries should refetch:

```
useMutation(
  (user) => updateUser(user),
  options: MutationOptions(
    onSuccess: () => queryClient.invalidateQuery('users'),
  ),
)
```

This ensures UI shows fresh data after mutation.

### Optimistic Updates

For instant UI feedback, update cache before server responds:

**Process:**
1. Save current cache state (for rollback)
2. Update cache with expected result
3. Start mutation
4. On success: keep optimistic update
5. On error: restore previous cache state

**Implementation:**

```
useMutation(
  (user) => updateUser(user),
  options: MutationOptions(
    onMutate: (user) async {
      // Save previous state
      final previous = queryClient.getQueryData('user');
      
      // Optimistic update
      queryClient.setQueryData('user', user);
      
      // Return context for rollback
      return {'previous': previous};
    },
    onError: (error, variables, context) {
      // Rollback
      queryClient.setQueryData('user', context['previous']);
    },
    onSuccess: () {
      // Refetch for server truth
      queryClient.invalidateQuery('user');
    },
  ),
)
```

### Concurrent Mutations

Multiple simultaneous mutations on same resource need coordination:
- Track mutation queue per resource
- Process mutations in order
- Each mutation sees result of previous
- Rollback propagates correctly

This prevents lost updates and race conditions.

---

## 6. Offline Mutation Queue

### The Problem

Mobile apps work offline. Users expect to perform actions offline and have them sync when connectivity returns. Without queueing, offline actions are lost.

### The Solution

Failed mutations persist to queue and retry automatically when network returns.

### Queue Architecture

**Queue Entry Structure:**

Each entry contains:
- Mutation function
- Variables passed to mutation
- Timestamp when queued
- Number of retry attempts
- Error from last attempt

**Queue Storage:**

Queue persists to disk (using simple JSON storage). Survives app restart, background eviction, everything.

**Queue Processing:**

When network becomes available:
1. Load queue from disk
2. Process entries in order
3. On success: remove from queue
4. On failure: increment retry count
5. If retry limit reached: mark as failed, notify user
6. Continue to next entry

### Network Detection

The library monitors network status:
- Online: process queue immediately
- Offline: hold queue, notify user
- Transition offline→online: start processing

Platform-specific network detection:
- iOS: Reachability
- Android: ConnectivityManager  
- Web: navigator.onLine

### User Feedback

Users need to know about pending mutations:

**Pending Count:**
```
final pendingCount = queryClient.offlineQueue.length;
```

**Mutation Status:**
Each mutation tracks whether it's queued, processing, or failed.

**UI Patterns:**
- Show badge with pending count
- "Syncing..." indicator when processing
- Retry button for failed mutations

### Conflict Resolution

What if mutation was queued offline but server data changed meanwhile?

**Simple Approach:**
Apply mutation regardless. Last write wins.

**Advanced Approach (Phase 5):**
Version checking, merge strategies, conflict detection.

For Phase 4, we use simple approach with documentation about limitations.

---

## 7. Parallel Queries

### The Problem

Fetching multiple related resources (users, posts, comments) requires multiple queries. Developers want to wait for all before rendering, or render progressively as each completes.

### The Solution

**useQueries** (Hooks) or equivalent takes an array of query configurations and returns an array of states:

```
final queries = useQueries([
  QueryConfig('users', () => fetchUsers()),
  QueryConfig('posts', () => fetchPosts()),
  QueryConfig('comments', () => fetchComments()),
]);

if (queries.every((q) => q.isSuccess)) {
  // All loaded, render full UI
}
```

Each query executes independently. States update independently. Developers decide how to handle partial loading.

---

## 8. Testing Strategy

### Infinite Query Tests

- Page accumulation correctness
- hasNextPage calculation
- Error handling per page
- Memory limits respected
- Bidirectional scroll works

### Dependent Query Tests

- Dependencies block correctly
- Enabled flag prevents fetch
- Re-enabling triggers fetch
- Error propagation works
- Loading states cascade

### Mutation Tests

- Mutations execute on command
- Don't execute automatically
- Cache invalidation works
- Optimistic updates apply
- Rollback on error works
- Concurrent mutations ordered

### Offline Queue Tests

- Queue persists across restart
- Mutations retry on reconnect
- Queue processes in order
- Failed mutations handled
- Network detection works

---

## 9. Risks and Mitigation

### Risk: Infinite Query Memory Usage

Hundreds of pages could consume excessive memory.

Mitigation: Max pages limit. Eviction of old pages. Testing with large datasets. Memory profiling.

### Risk: Optimistic Update Complexity

Optimistic updates with rollback are complex and error-prone.

Mitigation: Comprehensive testing of success, error, and concurrent cases. Clear documentation of edge cases. Simple default behavior.

### Risk: Offline Queue Data Loss

Bugs in persistence could lose queued mutations.

Mitigation: Rigorous persistence testing. Atomic writes. Backup mechanisms. Testing on real devices.

### Risk: Complex Feature Interactions

Infinite queries + dependent queries + optimistic updates = many edge cases.

Mitigation: Integration tests covering combinations. Clear separation of concerns. Careful state management.

---

## 10. Deliverables

### Code Deliverables

- InfiniteQuery implementation
- Dependent query enabled flag
- Mutation primitive
- Optimistic update system
- Offline mutation queue
- Network status detection
- Parallel query utilities
- Integration with all adapters

### Documentation Deliverables

- Infinite query guide with examples
- Dependent query patterns
- Mutations and optimistic updates guide
- Offline-first best practices
- Parallel query patterns

---

## 11. Timeline

### Week 7
**Days 1-2:** Infinite queries  
**Days 3-4:** Mutations basics  
**Day 5:** Dependent queries

### Week 8
**Days 1-2:** Optimistic updates  
**Days 3-4:** Offline queue  
**Day 5:** Parallel queries

### Week 9
**Days 1-3:** Testing all features  
**Days 4-5:** Documentation, examples, review

---

**Phase Owner:** Development Team  
**Phase Status:** Planning  
**Dependencies:** Phases 1, 2, 3 Complete  
**Next Milestone:** Advanced Features Design Review

