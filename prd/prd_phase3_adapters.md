# Phase 3: State Management Adapters

**Project:** Flutter Query  
**Phase:** 3 of 6  
**Timeline:** Weeks 5-6  
**Dependencies:** Phases 1 & 2 Complete  
**Status:** Planning

---

## 1. Phase Overview

### Purpose

Phase 3 makes Flutter Query accessible to developers regardless of their state management preference. By building adapters for Flutter Hooks, Bloc, and Riverpod, we ensure the library integrates naturally with existing codebases and development workflows.

### What We Will Build

Three separate adapter packages, each providing an idiomatic API for its ecosystem while sharing the same underlying query engine from Phases 1 and 2. Developers choose the adapter that matches their state management approach.

### Why This Matters

The Flutter community is divided on state management. By supporting multiple approaches, we maximize adoption and prevent developers from feeling locked into a specific pattern. The adapter architecture validates that our core is truly state-management-agnostic.

---

## 2. Goals and Success Criteria

### Primary Goals

**Create Idiomatic APIs for Each Ecosystem**

Hooks users should get hooks. Bloc users should get Cubits. Riverpod users should get Providers. Each adapter must feel natural within its ecosystem, not like a foreign object.

**Maintain Consistent Behavior Across Adapters**

While the APIs differ, the behavior must be identical. Caching, staleness, deduplication, and all core features work the same way regardless of which adapter is used. Developers switching adapters should only change syntax, not logic.

**Validate Core Architecture**

Building three different adapters tests whether the core is truly flexible. If adapters require hacks or workarounds, the core architecture needs improvement. This phase validates our design choices.

**Enable Future Community Adapters**

The patterns established in these official adapters should guide community members building adapters for GetX, Provider, or other state management solutions. Clear adapter patterns make the ecosystem extensible.

### Success Criteria

**Functional:**
- Each adapter provides full access to core features
- Lifecycle management works correctly in each
- Memory cleanup happens properly
- Hot reload works without memory leaks

**API Quality:**
- APIs feel natural to users of each ecosystem
- Minimal boilerplate required
- Type safety maintained throughout
- Error messages are clear and specific

**Consistency:**
- Same query produces same results across all adapters
- Performance characteristics identical
- Caching behavior identical
- Edge cases handled identically

**Quality:**
- Test coverage >85% per adapter
- Example apps for each adapter
- Migration guides for each
- No adapter-specific bugs

---

## 3. Adapter Architecture Principles

### Separation of Concerns

Adapters handle two responsibilities:
1. Integrating with their state management system
2. Providing an idiomatic API surface

Adapters do NOT reimplement query logic, caching, or any core functionality. They delegate everything to the core and focus purely on the integration layer.

### Lifecycle Management

Each state management system has different lifecycle patterns. Adapters must:

- Subscribe to queries when components mount
- Unsubscribe when components unmount
- Handle hot reload correctly
- Prevent memory leaks from forgotten subscriptions
- Respect the lifecycle patterns of their ecosystem

### Minimal Overhead

Adapters should add minimal performance overhead. The cost of the adapter layer should be negligible compared to network operations and rendering.

Target: <1ms overhead for adapter operations, <100 bytes memory per query.

---

## 4. Flutter Hooks Adapter

### Package: flutter_query_hooks

### Design Philosophy

Hooks provide a clean, functional approach to state management. The adapter provides custom hooks that feel like built-in Flutter hooks.

### Core Hook: useQuery

The primary hook for fetching data. Signature:

```
QueryState<T> useQuery<T>(
  String key,
  Future<T> Function() fetchFn,
  {QueryOptions? options}
)
```

Usage feels natural to hooks users:
- Call useQuery in build method
- Receive current state
- State updates trigger rebuilds
- Cleanup happens automatically

### Implementation Details

The hook must:
- Create or retrieve query from QueryClient on first call
- Subscribe to query stream
- Convert stream updates to hook state
- Unsubscribe on widget disposal
- Handle hot reload by preserving query instance
- Track dependencies to avoid unnecessary refetches

Key challenge: Hooks rebuild frequently. The adapter must distinguish between rebuilds (do nothing) and remounts (subscribe fresh).

### Additional Hooks

**useMutation** - For server mutations  
**useInfiniteQuery** - For pagination (Phase 4)  
**useQueryClient** - Access to QueryClient  
**useIsFetching** - Global fetching indicator

### Lifecycle Integration

Hooks already provide lifecycle management through useEffect. The adapter leverages this:

- useEffect subscribes to query stream
- Disposal callback unsubscribes
- Dependencies array prevents unnecessary resubscriptions
- Hot reload preservation through state persistence

### Testing Considerations

Hooks testing requires special setup. Tests must:
- Use HookBuilder or similar test harness
- Pump widgets to trigger rebuilds
- Verify subscription cleanup
- Test hot reload scenarios

---

## 5. Bloc Adapter

### Package: flutter_query_bloc

### Design Philosophy

Bloc provides structured state management through Cubits and Blocs. The adapter provides QueryCubits that integrate queries into Bloc architecture.

### Core Class: QueryCubit

A Cubit that wraps a Query. Signature:

```
class QueryCubit<T> extends Cubit<QueryState<T>> {
  QueryCubit(String key, Future<T> Function() fetchFn);
  
  void refetch();
  void invalidate();
}
```

Usage integrates with BlocBuilder/BlocConsumer:
- Create QueryCubit
- Provide it to widget tree
- Use BlocBuilder to render state
- Cubit disposal cleanup happens automatically

### Implementation Details

The Cubit must:
- Create or retrieve query from QueryClient
- Subscribe to query stream
- Emit stream updates as Cubit states
- Manage query reference counting
- Dispose properly through close() method
- Handle concurrent operations safely

Key challenge: Bloc's lifecycle differs from widgets. Cubits might live longer than widgets, so reference counting must be precise.

### Additional Classes

**MutationCubit** - For server mutations  
**InfiniteQueryCubit** - For pagination (Phase 4)  
**QueryBlocBuilder** - Specialized builder widget  
**QueryBlocListener** - For side effects

### Lifecycle Integration

Bloc provides explicit lifecycle hooks through close():

- Cubit constructor subscribes to query
- Subscription stored as StreamSubscription
- close() method cancels subscription and disposes query
- BlocProvider handles Cubit lifecycle automatically

### Testing Considerations

Bloc testing is straightforward. Tests must:
- Create QueryCubit instances
- Verify state emissions
- Test proper disposal
- Mock query responses

---

## 6. Riverpod Adapter

### Package: flutter_query_riverpod

### Design Philosophy

Riverpod provides compile-safe dependency injection. The adapter provides provider factories that create query providers.

### Core Function: queryProvider

A provider factory that creates StateNotifierProviders. Signature:

```
StateNotifierProvider<QueryNotifier<T>, QueryState<T>> queryProvider<T>(
  String key,
  Future<T> Function() fetchFn,
  {QueryOptions? options}
)
```

Usage integrates with ref.watch:
- Define provider with queryProvider
- Watch provider in widgets
- State updates trigger rebuilds
- Auto-dispose handles cleanup

### Implementation Details

The provider must:
- Create QueryNotifier (StateNotifier)
- QueryNotifier subscribes to query stream
- State changes propagate through Riverpod
- Auto-dispose properly through Riverpod lifecycle
- Support family for parameterized queries

Key challenge: Riverpod's auto-dispose must integrate with query reference counting to prevent premature disposal.

### Additional Providers

**mutationProvider** - For server mutations  
**infiniteQueryProvider** - For pagination (Phase 4)  
**queryClientProvider** - Global QueryClient access

### Lifecycle Integration

Riverpod handles lifecycle through auto-dispose:

- Provider creation initializes QueryNotifier
- QueryNotifier constructor subscribes to query
- When provider has no listeners, auto-dispose triggers
- Dispose method unsubscribes and decrements query reference
- Riverpod manages all timing automatically

### Family Support

Riverpod family enables parameterized queries:

```
final userProvider = queryProvider.family<User, String>(
  (id) => 'user:$id',
  (id) => fetchUser(id),
);
```

Each parameter combination creates a separate query instance, perfect for entity queries.

### Testing Considerations

Riverpod testing uses ProviderContainer. Tests must:
- Create ProviderContainer
- Read providers
- Verify state changes
- Test disposal behavior

---

## 7. Cross-Adapter Consistency

### Ensuring Identical Behavior

All adapters must produce identical results for identical queries. We ensure this through:

**Shared Test Suite**

A parameterized test suite runs against all adapters. Same tests, different adapter implementations. Any behavioral difference fails the tests.

**Integration Tests**

Tests that switch between adapters mid-session verify behavior consistency. If switching adapters changes behavior, something is wrong.

**Benchmark Comparison**

Performance benchmarks run against all adapters to verify overhead is similar. One adapter being 10x slower indicates a problem.

### Common Patterns

All adapters follow common patterns:

- Query creation delegated to core
- State updates flow from query stream
- Cleanup happens on disposal
- Reference counting maintained correctly
- Error handling consistent

These patterns are documented as guidelines for community adapters.

---

## 8. Testing Strategy

### Per-Adapter Tests

Each adapter has its own test suite covering:

- Basic query lifecycle
- State updates propagate correctly
- Proper disposal and cleanup
- Memory leak prevention
- Hot reload behavior
- Error scenarios
- Edge cases specific to that adapter

### Cross-Adapter Tests

Shared tests verify consistency:

- Same query data across adapters
- Same timing characteristics
- Same error messages
- Same edge case handling

### Integration Tests

Complete application scenarios:

- Multiple queries in one app
- Query sharing across widgets
- Navigation and lifecycle events
- Memory usage over time
- Performance under load

---

## 9. Developer Experience

### Choosing an Adapter

Documentation guides developers to the right adapter:

- Already using Hooks? Use flutter_query_hooks
- Already using Bloc? Use flutter_query_bloc
- Already using Riverpod? Use flutter_query_riverpod
- Not using any? Start with Hooks (simplest)

### Migration Between Adapters

Migration guide shows parallel implementations:

- Same query in Hooks, Bloc, Riverpod
- Highlighting syntax differences
- Noting behavior similarities
- Step-by-step migration process

Developers can migrate incrementally, with both adapters coexisting during transition.

### Example Applications

Each adapter has a complete example app showing:

- Basic queries
- Error handling
- Manual refetch
- Cache invalidation
- Multiple queries
- Real API integration

Examples are realistic, not trivial.

---

## 10. Risks and Mitigation

### Risk: Adapter Overhead Too High

If adapters add significant overhead, they negate benefits.

Mitigation: Benchmark early. Profile each adapter. Optimize hot paths. Target <1ms overhead per operation.

### Risk: Lifecycle Management Bugs

Incorrect lifecycle management causes memory leaks.

Mitigation: Comprehensive leak testing. Hot reload testing. Long-running tests. Memory profiling.

### Risk: API Feels Unnatural

If adapters don't feel natural, adoption will be low.

Mitigation: Get feedback from users of each ecosystem. Iterate on API design. Match conventions of each ecosystem.

### Risk: Inconsistent Behavior

If adapters behave differently, it creates confusion.

Mitigation: Shared test suite. Integration tests. Careful review of edge cases.

---

## 11. Deliverables

### Code Deliverables

- flutter_query_hooks package
- flutter_query_bloc package
- flutter_query_riverpod package
- Test suites for each
- Example apps for each

### Documentation Deliverables

- Adapter selection guide
- Per-adapter documentation
- Migration guides
- Pattern guides for community adapters

---

## 12. Timeline

### Week 5

**Days 1-2:** Hooks adapter
**Days 3-4:** Bloc adapter
**Day 5:** Riverpod adapter start

### Week 6

**Days 1-2:** Complete Riverpod adapter
**Days 3-4:** Cross-adapter testing, examples
**Day 5:** Documentation, review, validation

---

**Phase Owner:** Development Team  
**Phase Status:** Planning  
**Dependencies:** Phases 1 & 2 Complete  
**Next Milestone:** Adapter Design Review

