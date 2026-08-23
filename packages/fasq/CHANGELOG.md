## 0.5.1

 - **PERF**: Fix Fasq core performance hotspots ([#73](https://github.com/ishafiul/fasq/pull/73)). ([c998ecd0](https://github.com/ishafiul/fasq/commit/c998ecd069b6a8187cf055f8b1caa2f781a2fdfa))
 - **FEAT**: build offline-first mutation sync engine ([#61](https://github.com/ishafiul/fasq/pull/61)). ([cd0cff75](https://github.com/ishafiul/fasq/commit/cd0cff752cb6e4806803feb07eb93b05c8a0c821))

## 0.5.0

> Note: This release has breaking changes.

 - **REFACTOR**: Improve query and mutation handling in widgets ([#56](https://github.com/ishafiul/fasq/pull/56)).
 - **REFACTOR**: Update LeakDetector to throw Exception instead of TestFailure.
 - **REFACTOR**: fasq core files path and folder structure  ([#59](https://github.com/ishafiul/fasq/pull/59)).
 - **REFACTOR**(performance): simplify isolate pool initialization ([#24](https://github.com/ishafiul/fasq/pull/24)).
 - **FIX**: security ([#9](https://github.com/ishafiul/fasq/pull/9)).
 - **FIX**(query_cache): Enhance cache entry management and eviction logic ([#57](https://github.com/ishafiul/fasq/pull/57)).
 - **FIX**: comprehensive fixes for reference counting and loading state ([#21](https://github.com/ishafiul/fasq/pull/21)).
 - **FIX**: wait for persistence initialization before creating queries ([#41](https://github.com/ishafiul/fasq/pull/41)).
 - **FIX**: ensure query cache cleanup and proper disposal.
 - **FIX**: resolve cache type safety issue by reconstructing CacheEntry instead of casting ([#27](https://github.com/ishafiul/fasq/pull/27)).
 - **FIX**: enhance infinite query options and state management ([#25](https://github.com/ishafiul/fasq/pull/25)).
 - **FIX**: improve cache staleness handling and query state management ([#22](https://github.com/ishafiul/fasq/pull/22)).
 - **FIX**: prevent negative reference count in Query and InfiniteQuery ([#18](https://github.com/ishafiul/fasq/pull/18)).
 - **FIX**: resolve all analysis issues and prepare packages for publishing ([#16](https://github.com/ishafiul/fasq/pull/16)).
 - **FIX**: resolve critical issues and improve code quality ([#15](https://github.com/ishafiul/fasq/pull/15)).
 - **FEAT**: introduce cache data codec ([#38](https://github.com/ishafiul/fasq/pull/38)).
 - **FEAT**: Error Tracking System for Production Diagnostics ([#52](https://github.com/ishafiul/fasq/pull/52)).
 - **FEAT**: harden persistence across cache layers ([#36](https://github.com/ishafiul/fasq/pull/36)).
 - **FEAT**: prefetching ([#8](https://github.com/ishafiul/fasq/pull/8)).
 - **FEAT**: allow typed meta messages ([#34](https://github.com/ishafiul/fasq/pull/34)).
 - **FEAT**: refine global query effects ([#33](https://github.com/ishafiul/fasq/pull/33)).
 - **FEAT**: add context-aware query observers ([#32](https://github.com/ishafiul/fasq/pull/32)).
 - **FEAT**: allow injecting manual query client ([#31](https://github.com/ishafiul/fasq/pull/31)).
 - **FEAT**: add type-safe query keys support ([#28](https://github.com/ishafiul/fasq/pull/28)).
 - **FEAT**: Built-in Logging for Query and Mutation Lifecycle Events ([#48](https://github.com/ishafiul/fasq/pull/48)).
 - **FEAT**: dependent queries ([#4](https://github.com/ishafiul/fasq/pull/4)).
 - **FEAT**(circuit-breaker): Implement circuit breaker pattern for query protection ([#45](https://github.com/ishafiul/fasq/pull/45)).
 - **FEAT**: offline mutation queue ([#5](https://github.com/ishafiul/fasq/pull/5)).
 - **FEAT**: infinite queries ([#3](https://github.com/ishafiul/fasq/pull/3)).
 - **FEAT**: clear cache when query is disposed to ensure fresh data on revisit ([#20](https://github.com/ishafiul/fasq/pull/20)).
 - **FEAT**: implement parallel queries across all adapters ([#6](https://github.com/ishafiul/fasq/pull/6)).
 - **FEAT**: Add automatic serializer generator for type-safe persistence ([#42](https://github.com/ishafiul/fasq/pull/42)).
 - **FEAT**: Leak Detection ([#51](https://github.com/ishafiul/fasq/pull/51)).
 - **FEAT**: Memory Management with Pressure Handling & Leak Detection ([#50](https://github.com/ishafiul/fasq/pull/50)).
 - **FEAT**: implement comprehensive performance optimization system ([#13](https://github.com/ishafiul/fasq/pull/13)).
 - **FEAT**: integrate SecurityPlugin with QueryCache ([#12](https://github.com/ishafiul/fasq/pull/12)).
 - **FEAT**: complete updateEncryptionKey implementation with real persistence ([#10](https://github.com/ishafiul/fasq/pull/10)).
 - **FEAT**(fasq): add performance metrics, optimize IsolatePool, and improve lifecycle ([#49](https://github.com/ishafiul/fasq/pull/49)).
 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal ([#47](https://github.com/ishafiul/fasq/pull/47)).
 - **BREAKING** **FEAT**: Extract security features to separate fasq_security package ([#11](https://github.com/ishafiul/fasq/pull/11)).

## 0.4.2+1

 - **REFACTOR**: Improve query and mutation handling in widgets ([#56](https://github.com/ishafiul/fasq/pull/56)).

## 0.4.2

 - **REFACTOR**: Update LeakDetector to throw Exception instead of TestFailure.
 - **FEAT**: Error Tracking System for Production Diagnostics ([#52](https://github.com/ishafiul/fasq/pull/52)).

## 0.4.1

 - **FEAT**: Leak Detection ([#51](https://github.com/ishafiul/fasq/pull/51)).
 - **FEAT**: Memory Management with Pressure Handling & Leak Detection ([#50](https://github.com/ishafiul/fasq/pull/50)).
 - **FEAT**(fasq): add performance metrics, optimize IsolatePool, and improve lifecycle ([#49](https://github.com/ishafiul/fasq/pull/49)).
 - **FEAT**: Built-in Logging for Query and Mutation Lifecycle Events ([#48](https://github.com/ishafiul/fasq/pull/48)).

## 0.4.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal ([#47](https://github.com/ishafiul/fasq/pull/47)).

## 0.3.8

 - **FEAT**(circuit-breaker): Implement circuit breaker pattern for query protection ([#45](https://github.com/ishafiul/fasq/pull/45)).

## 0.3.7

 - **FIX**: wait for persistence initialization before creating queries ([#41](https://github.com/ishafiul/fasq/pull/41)).
 - **FEAT**: Add automatic serializer generator for type-safe persistence ([#42](https://github.com/ishafiul/fasq/pull/42)).

## 0.3.6

 - **FIX**: ensure query cache cleanup and proper disposal.
 - **FEAT**: introduce cache data codec ([#38](https://github.com/ishafiul/fasq/pull/38)).

## 0.3.5

 - **FEAT**: harden persistence across cache layers ([#36](https://github.com/ishafiul/fasq/pull/36)).

## 0.3.4

 - **FEAT**: allow typed meta messages ([#34](https://github.com/ishafiul/fasq/pull/34)).
 - **FEAT**: refine global query effects ([#33](https://github.com/ishafiul/fasq/pull/33)).
 - **FEAT**: add context-aware query observers ([#32](https://github.com/ishafiul/fasq/pull/32)).
 - **FEAT**: allow injecting manual query client ([#31](https://github.com/ishafiul/fasq/pull/31)).

## 0.3.3

- **FIX**: align docs, entrypoints, and tests around typed QueryKey usage ([#30](https://github.com/ishafiul/fasq/pull/30)).
- **FIX**: add Flutter example apps for fasq, bloc, hooks, and riverpod packages ([#30](https://github.com/ishafiul/fasq/pull/30)).

## 0.3.2

 - **FEAT**: add type-safe query keys support ([#28](https://github.com/ishafiul/fasq/pull/28)).

## 0.3.1+1

 - **FIX**: resolve cache type safety issue by reconstructing CacheEntry instead of casting ([#27](https://github.com/ishafiul/fasq/pull/27)).
 - **FIX**: enhance infinite query options and state management ([#25](https://github.com/ishafiul/fasq/pull/25)).

## 0.3.1

 - **REFACTOR**(performance): simplify isolate pool initialization ([#24](https://github.com/ishafiul/fasq/pull/24)).
 - **FIX**: improve cache staleness handling and query state management ([#22](https://github.com/ishafiul/fasq/pull/22)).
 - **FIX**: comprehensive fixes for reference counting and loading state ([#21](https://github.com/ishafiul/fasq/pull/21)).
 - **FIX**: prevent negative reference count in Query and InfiniteQuery ([#18](https://github.com/ishafiul/fasq/pull/18)).
 - **FEAT**: clear cache when query is disposed to ensure fresh data on revisit ([#20](https://github.com/ishafiul/fasq/pull/20)).

## 0.3.0

> Note: This release has breaking changes.

 - **FIX**: resolve all analysis issues and prepare packages for publishing ([#16](https://github.com/ishafiul/fasq/pull/16)).
 - **FIX**: resolve critical issues and improve code quality ([#15](https://github.com/ishafiul/fasq/pull/15)).
 - **FIX**: security ([#9](https://github.com/ishafiul/fasq/pull/9)).
 - **FEAT**: implement comprehensive performance optimization system ([#13](https://github.com/ishafiul/fasq/pull/13)).
 - **FEAT**: integrate SecurityPlugin with QueryCache ([#12](https://github.com/ishafiul/fasq/pull/12)).
 - **FEAT**: complete updateEncryptionKey implementation with real persistence ([#10](https://github.com/ishafiul/fasq/pull/10)).
 - **FEAT**: prefetching ([#8](https://github.com/ishafiul/fasq/pull/8)).
 - **FEAT**: implement parallel queries across all adapters ([#6](https://github.com/ishafiul/fasq/pull/6)).
 - **FEAT**: offline mutation queue ([#5](https://github.com/ishafiul/fasq/pull/5)).
 - **FEAT**: dependent queries ([#4](https://github.com/ishafiul/fasq/pull/4)).
 - **FEAT**: infinite queries ([#3](https://github.com/ishafiul/fasq/pull/3)).
 - **BREAKING** **FEAT**: Extract security features to separate fasq_security package ([#11](https://github.com/ishafiul/fasq/pull/11)).
