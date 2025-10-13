# Phase 1: MVP - Core Query System

**Project:** Flutter Query  
**Phase:** 1 of 6  
**Timeline:** Weeks 1-2  
**Status:** Planning

---

## 1. Phase Overview

### Purpose

This phase establishes the foundational architecture of Flutter Query. The goal is to prove the core concept works: executing async operations (primarily API calls, but also database queries, file operations, or any Future-based task), managing state transitions, and providing a clean API for Flutter developers. We intentionally exclude caching, advanced features, and optimizations to focus on getting the basics right.

### What We Will Build

A minimal but functional query system that developers can use to execute any async operation and display results in Flutter widgets. The system will handle loading states, errors, and successful data retrieval through a simple, predictable API. While designed primarily for API calls, it works with any Future-returning function.

### What We Will NOT Build

No caching mechanism, no request deduplication, no background refetching, no persistence, no advanced error recovery. These come in later phases. This phase is purely about the query lifecycle and state management for async operations.

---

## 2. Goals and Success Criteria

### Primary Goals

**Prove the Architecture Works**

Validate that our chosen architecture for separating query logic from UI logic is sound. The Query class should be a pure logic object that widgets can subscribe to without tight coupling.

**Establish Clean API Surface**

Define the basic API that all future features will build upon. This API must be intuitive, type-safe, and flexible enough to accommodate future enhancements without breaking changes.

**Create Foundation for Future Phases**

Every decision in this phase should consider how it will support caching, adapters, and advanced features in later phases. We're building a foundation that must remain stable.

### Success Criteria

**Functional:**
- Developer can create a query with a key and fetch function
- Query automatically executes and manages state transitions
- Widget can subscribe to query state and rebuild on changes
- Loading, error, and success states all work correctly
- Multiple widgets can subscribe to same query
- Query cleanup happens when no widgets are subscribed

**Quality:**
- Test coverage exceeds 80%
- All public APIs have documentation
- Example app demonstrates basic usage
- Code passes strict lint rules
- Zero memory leaks in basic usage

**Developer Experience:**
- From project setup to working query: under 10 minutes
- API feels natural to Flutter developers
- Error messages are clear and actionable
- Documentation explains core concepts

---

## 3. Architecture Design

### Core Components

**Query Class**

The Query class is the heart of the system. It represents a single async operation and manages the complete lifecycle of that operation.

Responsibilities:
- Store the query key (unique identifier)
- Store the async function (any Future-returning function)
- Manage current state (loading, error, success, data)
- Emit state changes through a stream
- Track active subscribers
- Handle disposal when no longer needed

The Query class is completely independent of Flutter widgets. It's pure Dart logic that works with any async operation: API calls, database queries, file I/O, local computations, or any other Future-based task. This happens to work perfectly with Flutter's reactive paradigm.

**Query State**

Query state represents the current status of a query at any point in time. It's an immutable data class with these fields:

- Current data (if any)
- Current error (if any)
- Loading flag (is initial fetch happening?)
- Status (idle, loading, success, error)

State transitions follow a predictable pattern:
- Idle → Loading (when fetch starts)
- Loading → Success (when data arrives)
- Loading → Error (when fetch fails)
- Any → Loading (when refetch happens)

**Query Client**

The QueryClient is a registry of all queries in the application. It's responsible for creating queries, retrieving existing queries by key, and managing the global query lifecycle.

For this phase, the QueryClient is very simple - just a map of keys to Query instances. It will become more sophisticated in Phase 2 when caching is added.

**QueryBuilder Widget**

QueryBuilder is the Flutter widget that bridges the query system with the UI. It subscribes to a query's state stream and rebuilds when state changes.

The widget takes:
- Query key
- Fetch function
- Builder function (how to render each state)

It handles:
- Creating or retrieving the query from QueryClient
- Subscribing to state changes
- Rebuilding when state changes
- Unsubscribing on disposal
- Incrementing/decrementing query reference count

### State Management Flow

When a QueryBuilder widget is created:
1. Widget asks QueryClient for query with given key
2. If query doesn't exist, QueryClient creates it
3. Widget subscribes to query's state stream
4. Query starts fetching (if not already fetching)
5. Widget builds UI based on current state

When query state changes:
1. Query updates internal state
2. Query emits new state to stream
3. All subscribed widgets receive state update
4. Widgets rebuild with new state

When a QueryBuilder widget is disposed:
1. Widget unsubscribes from query's state stream
2. Query decrements reference count
3. If reference count reaches zero, query marks itself for disposal
4. QueryClient removes query after brief delay

### Thread Safety Considerations

For this phase, we assume all operations happen on the main isolate. We don't need complex synchronization because:
- Dart is single-threaded by default
- All state updates happen in response to futures completing
- Stream subscriptions handle concurrency naturally

Phase 5 will add isolate support for heavy processing, which will require proper synchronization primitives.

---

## 4. API Design

### Creating a Query

Developers don't create Query objects directly. Instead, they use QueryBuilder widget which manages query creation and lifecycle.

The QueryBuilder widget requires:
- A unique string key identifying this query
- A function that returns a Future with the data (any async operation)
- A builder function that receives state and returns a widget

The widget signature:

```
QueryBuilder<DataType>(
  queryKey: string,
  queryFn: () async => anyAsyncOperation(),
  builder: (context, state) => buildWidget(state),
)
```

**Examples of async operations:**
- API calls: `() => api.getUsers()`
- Database queries: `() => database.getUserById(id)`
- File operations: `() => File(path).readAsString()`
- Local computations: `() => compute(heavyComputation, data)`
- Any Future: `() => Future.delayed(Duration(seconds: 2), () => 'data')`

The library doesn't care about the source of data—only that it's a Future.

### Accessing Query State

Inside the builder function, developers receive a QueryState object with:
- `data` - the fetched data (null if not loaded yet)
- `error` - the error (null if no error)
- `isLoading` - true during initial fetch
- `status` - current status enum value

Developers check these fields to determine what to render:
- If isLoading is true, show loading spinner
- If error is not null, show error message
- If data is not null, show the data

### Refetching Data

For this phase, refetching is manual. The builder function receives a refetch callback that developers can call when they want fresh data.

This is intentionally simple. Phase 2 will add automatic refetching based on staleness.

### Multiple Widgets, Same Query

If two widgets use the same query key, they share the same Query instance. This means:
- Only one fetch happens
- Both widgets see the same state
- When one widget refetches, both update
- Query lives as long as at least one widget needs it

This is the foundation for request deduplication (Phase 2) but in Phase 1 it's just natural sharing through the QueryClient registry.

---

## 5. Implementation Details

### Query Lifecycle Management

Each Query has a reference count tracking how many widgets are subscribed. This count is critical for determining when to dispose the query.

When reference count increases from zero to one:
- Query initializes
- Query starts fetching if not already fetched

When reference count remains above zero:
- Query continues normal operation
- State updates propagate to all subscribers

When reference count decreases to zero:
- Query marks itself as orphaned
- After a brief delay (5 seconds), query disposes if still orphaned
- This delay prevents dispose/recreate thrashing when navigating rapidly

### State Stream Implementation

Each Query maintains a StreamController that broadcasts state changes. We use a broadcast stream because multiple widgets might subscribe.

The stream must:
- Emit current state to new subscribers immediately
- Emit new states when query executes
- Close cleanly when query is disposed
- Handle errors gracefully

We use a BehaviorSubject pattern (manually implemented) where new subscribers immediately receive the current state before any future states.

### Error Handling

When the fetch function throws an error:
- Query catches the error
- Query transitions to error state
- Error is stored in state
- Error is emitted to stream
- UI shows error state

For this phase, no automatic retry happens. Developers must manually refetch if they want to recover from errors. Phase 5 will add automatic retry with exponential backoff.

### Memory Management

Memory leaks are prevented through careful lifecycle management:

- Query disposal happens when reference count is zero for 5 seconds
- Disposal closes the stream controller
- Closed streams release all subscribers
- QueryClient removes disposed queries
- No circular references exist

We validate this through memory profiling tests that create and dispose many queries over time.

### Testing Strategy

Unit tests cover:
- Query state transitions
- Stream emission patterns
- Reference counting logic
- Error handling
- Disposal cleanup

Widget tests cover:
- QueryBuilder lifecycle
- UI updates on state changes
- Multiple widgets sharing query
- Proper unsubscription

Integration tests cover:
- Complete flows from widget mount to data display
- Error scenarios
- Rapid navigation patterns

---

## 6. Developer Experience

### Getting Started

A developer's first experience should be smooth and successful. Documentation will guide them through:

1. Adding flutter_query dependency
2. Creating a QueryClient
3. Wrapping app with QueryClientProvider
4. Creating their first QueryBuilder
5. Seeing data appear

Total time: under 10 minutes.

### Example Usage

The example app will demonstrate various async operation types:

**API Call Example:**
- Fetching a list of users from REST API
- Displaying loading spinner during fetch
- Showing error message on failure
- Rendering list when successful
- Refetching data with pull-to-refresh

**Database Query Example:**
- Reading local database records
- Handling database errors
- Showing cached database results

**File Operation Example:**
- Reading configuration file
- Parsing JSON data
- Error handling for file not found

**Mixed Operations Example:**
- Multiple screens using different async operations
- Same query key pattern across different data sources

These examples demonstrate that the library handles any async operation, with APIs being the most common use case.

### Documentation Structure

Documentation for Phase 1 includes:
- Quick start guide
- Core concepts explanation
- API reference
- Common patterns
- Troubleshooting guide

Documentation emphasizes understanding over configuration. Developers should learn how the system works, not just copy-paste examples.

---

## 7. What We're Explicitly Not Building

### No Caching

Queries don't cache results between disposal and recreation. If a query is disposed and later recreated with the same key, it fetches fresh data. Phase 2 adds caching.

### No Staleness Detection

Queries don't know if their data is stale. They fetch once and that's it until manually refetched. Phase 2 adds staleness configuration.

### No Request Deduplication

If two queries with the same key start fetching simultaneously, two network requests happen. Phase 2 adds deduplication.

### No Background Refetching

Queries don't refetch when the app returns from background or when network reconnects. Phase 4 adds this.

### No Persistence

Query state is lost when the app restarts. Phase 5 adds optional persistence.

### No Optimizations

No isolate usage, no performance tuning, no memory optimizations beyond basic cleanup. Phase 5 adds optimizations.

---

## 8. Risks and Mitigation

### Risk: Architecture Doesn't Scale

If our core architecture is flawed, later phases will be painful. 

Mitigation: Extensive design review before implementation. Prototype key patterns. Get feedback from experienced Flutter developers. Be willing to refactor if issues emerge during Phase 1.

### Risk: API Too Restrictive

If our API design is too rigid, adding caching and advanced features will require breaking changes.

Mitigation: Design API with extensibility in mind. Use options objects that can grow. Review React Query's evolution for lessons. Build Phase 2 features as extensions, not modifications.

### Risk: Memory Leaks

If lifecycle management is incorrect, queries will leak memory.

Mitigation: Comprehensive leak testing. Memory profiling during development. Stress tests with thousands of queries. Clear disposal paths.

### Risk: Poor Developer Experience

If the API is confusing or error-prone, adoption will be low.

Mitigation: User testing with real developers. Clear documentation. Good error messages. Simple, predictable behavior.

---

## 9. Testing Requirements

### Unit Tests

- Query creation and initialization
- State transitions for all paths
- Stream emission correctness
- Reference counting accuracy
- Error handling completeness
- Disposal cleanup verification

Target: >85% coverage

### Widget Tests

- QueryBuilder lifecycle
- State-based rendering
- Subscription management
- Multiple widget scenarios
- Refetch functionality

Target: All public widgets tested

### Integration Tests

- Complete user flows
- Error recovery paths
- Navigation patterns
- Memory leak detection

Target: All critical paths covered

### Manual Testing

- Example app works smoothly
- Error messages are helpful
- Performance feels responsive
- No visible bugs

---

## 10. Success Validation

### How We Know Phase 1 Succeeded

**Code Quality:**
- All tests passing
- >80% coverage
- Zero lint errors
- Clean architecture

**Functionality:**
- Example app works perfectly
- All core features functional
- No critical bugs
- Memory usage stable

**Developer Experience:**
- External developers can use it
- Positive feedback on API
- Documentation is clear
- Getting started is easy

**Foundation:**
- Phase 2 can build on this
- No obvious architectural problems
- Extensibility paths clear

### What Success Looks Like

A developer can add flutter_query to their project, create a QueryBuilder, and successfully fetch and display data within 10 minutes. The code is clean, well-tested, and ready to support caching in Phase 2.

---

## 11. Deliverables

### Code Deliverables

- Core Query class with full lifecycle
- QueryState data class
- QueryClient registry
- QueryBuilder widget
- Basic error handling
- Complete test suite

### Documentation Deliverables

- Quick start guide
- Core concepts explanation
- API documentation
- Example application
- Architecture overview

### Quality Deliverables

- Test coverage report
- Performance baseline metrics
- Memory usage baseline
- Lint compliance report

---

## 12. Timeline

### Week 1

**Days 1-2:** Architecture and design finalization
- Detailed class designs
- API surface definition
- Test strategy planning

**Days 3-5:** Core implementation
- Query class implementation
- QueryState implementation
- QueryClient implementation
- Basic tests

### Week 2

**Days 1-2:** Widget integration
- QueryBuilder implementation
- Provider setup
- Widget tests

**Days 3-4:** Testing and polish
- Integration tests
- Memory leak testing
- Documentation
- Example app

**Day 5:** Review and validation
- Code review
- Test review
- Documentation review
- Prepare for Phase 2

---

## 13. Next Phase Preview

Phase 2 will add the caching layer that makes this library practical for production use. The cache will:
- Store query results by key
- Detect staleness based on time
- Deduplicate simultaneous requests
- Manage memory with eviction policies
- Provide cache inspection tools

The architecture from Phase 1 must support these features without major refactoring. We should validate during Phase 1 that the extension path is clear.

---

**Phase Owner:** Development Team  
**Phase Status:** Planning  
**Next Milestone:** Architecture Review Complete  
**Approval Required:** Yes, before implementation begins

