## 0.4.1

 - **FEAT**: Leak Detection (#51).
 - **FEAT**: Memory Management with Pressure Handling & Leak Detection (#50).
 - **FEAT**(fasq): add performance metrics, optimize IsolatePool, and improve lifecycle (#49).
 - **FEAT**: Built-in Logging for Query and Mutation Lifecycle Events (#48).

## 0.4.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal (#47).

## 0.3.8

 - **FEAT**(circuit-breaker): Implement circuit breaker pattern for query protection (#45).

## 0.3.7+1

 - **DOCS**: Update READMEs with new features, documentation links, usage examples, and remove production warnings. (#44).

## 0.3.7

 - **FIX**: wait for persistence initialization before creating queries (#41).
 - **FEAT**: Add automatic serializer generator for type-safe persistence (#42).
 - **DOCS**: Update README files across packages to indicate active development status and not ready for production use.

## 0.3.6

 - **FIX**: ensure query cache cleanup and proper disposal.
 - **FEAT**: introduce cache data codec (#38).

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
