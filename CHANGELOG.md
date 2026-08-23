# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2026-08-23

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.5.1`](#fasq---v051)
 - [`fasq_bloc` - `v0.4.1`](#fasq_bloc---v041)
 - [`fasq_hooks` - `v0.4.1`](#fasq_hooks---v041)
 - [`fasq_riverpod` - `v0.4.0+1`](#fasq_riverpod---v0401)
 - [`fasq_security` - `v0.3.1`](#fasq_security---v031)
 - [`fasq_serializer_generator` - `v0.1.3`](#fasq_serializer_generator---v013)

---

#### `fasq` - `v0.5.1`

 - **PERF**: Fix Fasq core performance hotspots ([#73](https://github.com/ishafiul/fasq/pull/73)). ([c998ecd0](https://github.com/ishafiul/fasq/commit/c998ecd069b6a8187cf055f8b1caa2f781a2fdfa))
 - **FEAT**: build offline-first mutation sync engine ([#61](https://github.com/ishafiul/fasq/pull/61)). ([cd0cff75](https://github.com/ishafiul/fasq/commit/cd0cff752cb6e4806803feb07eb93b05c8a0c821))

#### `fasq_bloc` - `v0.4.1`

 - **FEAT**: build offline-first mutation sync engine ([#61](https://github.com/ishafiul/fasq/pull/61)). ([cd0cff75](https://github.com/ishafiul/fasq/commit/cd0cff752cb6e4806803feb07eb93b05c8a0c821))

#### `fasq_hooks` - `v0.4.1`

 - **FEAT**: build offline-first mutation sync engine ([#61](https://github.com/ishafiul/fasq/pull/61)). ([cd0cff75](https://github.com/ishafiul/fasq/commit/cd0cff752cb6e4806803feb07eb93b05c8a0c821))

#### `fasq_riverpod` - `v0.4.0+1`


#### `fasq_security` - `v0.3.1`

 - **FEAT**: build offline-first mutation sync engine ([#61](https://github.com/ishafiul/fasq/pull/61)). ([cd0cff75](https://github.com/ishafiul/fasq/commit/cd0cff752cb6e4806803feb07eb93b05c8a0c821))

#### `fasq_serializer_generator` - `v0.1.3`

 - **FEAT**: build offline-first mutation sync engine ([#61](https://github.com/ishafiul/fasq/pull/61)). ([cd0cff75](https://github.com/ishafiul/fasq/commit/cd0cff752cb6e4806803feb07eb93b05c8a0c821))


## 2026-05-10

### Changes

---

Packages with breaking changes:

 - [`fasq` - `v0.5.0`](#fasq---v050)
 - [`fasq_bloc` - `v0.4.0`](#fasq_bloc---v040)
 - [`fasq_hooks` - `v0.4.0`](#fasq_hooks---v040)
 - [`fasq_riverpod` - `v0.4.0`](#fasq_riverpod---v040)
 - [`fasq_security` - `v0.3.0`](#fasq_security---v030)

Packages with other changes:

 - [`fasq_serializer_generator` - `v0.1.2`](#fasq_serializer_generator---v012)

---

#### `fasq` - `v0.5.0`

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

#### `fasq_bloc` - `v0.4.0`

 - **REFACTOR**: convert cubits to abstract base classes ([#26](https://github.com/ishafiul/fasq/pull/26)).
 - **FIX**: ensure query cache cleanup and proper disposal.
 - **FIX**: resolve all analysis issues and prepare packages for publishing ([#16](https://github.com/ishafiul/fasq/pull/16)).
 - **FIX**: security ([#9](https://github.com/ishafiul/fasq/pull/9)).
 - **FEAT**(fasq_bloc): Major Refactor - Composition, Lifecycle Hooks, and Feature Parity ([#53](https://github.com/ishafiul/fasq/pull/53)).
 - **FEAT**: introduce cache data codec ([#38](https://github.com/ishafiul/fasq/pull/38)).
 - **FEAT**: example app ([#23](https://github.com/ishafiul/fasq/pull/23)).
 - **FEAT**: add type-safe query keys support ([#28](https://github.com/ishafiul/fasq/pull/28)).
 - **FEAT**: prefetching ([#8](https://github.com/ishafiul/fasq/pull/8)).
 - **FEAT**: implement parallel queries across all adapters ([#6](https://github.com/ishafiul/fasq/pull/6)).
 - **FEAT**: offline mutation queue ([#5](https://github.com/ishafiul/fasq/pull/5)).
 - **FEAT**: dependent queries ([#4](https://github.com/ishafiul/fasq/pull/4)).
 - **FEAT**: infinite queries ([#3](https://github.com/ishafiul/fasq/pull/3)).
 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal ([#47](https://github.com/ishafiul/fasq/pull/47)).
 - **BREAKING** **FEAT**: Replace Fixed Combiners with Dynamic Query Combiners ([#7](https://github.com/ishafiul/fasq/pull/7)).

#### `fasq_hooks` - `v0.4.0`

 - **FIX**: ensure query cache cleanup and proper disposal.
 - **FIX**: resolve all analysis issues and prepare packages for publishing ([#16](https://github.com/ishafiul/fasq/pull/16)).
 - **FIX**: security ([#9](https://github.com/ishafiul/fasq/pull/9)).
 - **FEAT**: introduce cache data codec ([#38](https://github.com/ishafiul/fasq/pull/38)).
 - **FEAT**: add type-safe query keys support ([#28](https://github.com/ishafiul/fasq/pull/28)).
 - **FEAT**: prefetching ([#8](https://github.com/ishafiul/fasq/pull/8)).
 - **FEAT**: implement parallel queries across all adapters ([#6](https://github.com/ishafiul/fasq/pull/6)).
 - **FEAT**: dependent queries ([#4](https://github.com/ishafiul/fasq/pull/4)).
 - **FEAT**: infinite queries ([#3](https://github.com/ishafiul/fasq/pull/3)).
 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal ([#47](https://github.com/ishafiul/fasq/pull/47)).
 - **BREAKING** **FEAT**: Replace Fixed Combiners with Dynamic Query Combiners ([#7](https://github.com/ishafiul/fasq/pull/7)).

#### `fasq_riverpod` - `v0.4.0`

 - **REFACTOR**: fasq core files path and folder structure  ([#59](https://github.com/ishafiul/fasq/pull/59)).
 - **FIX**: ensure query cache cleanup and proper disposal.
 - **FIX**: resolve all analysis issues and prepare packages for publishing ([#16](https://github.com/ishafiul/fasq/pull/16)).
 - **FIX**: security ([#9](https://github.com/ishafiul/fasq/pull/9)).
 - **FEAT**: Riverpod Update ([#54](https://github.com/ishafiul/fasq/pull/54)).
 - **FEAT**: introduce cache data codec ([#38](https://github.com/ishafiul/fasq/pull/38)).
 - **FEAT**: add type-safe query keys support ([#28](https://github.com/ishafiul/fasq/pull/28)).
 - **FEAT**: prefetching ([#8](https://github.com/ishafiul/fasq/pull/8)).
 - **FEAT**: implement parallel queries across all adapters ([#6](https://github.com/ishafiul/fasq/pull/6)).
 - **FEAT**: offline mutation queue ([#5](https://github.com/ishafiul/fasq/pull/5)).
 - **FEAT**: dependent queries ([#4](https://github.com/ishafiul/fasq/pull/4)).
 - **FEAT**: infinite queries ([#3](https://github.com/ishafiul/fasq/pull/3)).
 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal ([#47](https://github.com/ishafiul/fasq/pull/47)).
 - **BREAKING** **FEAT**: Replace Fixed Combiners with Dynamic Query Combiners ([#7](https://github.com/ishafiul/fasq/pull/7)).

#### `fasq_security` - `v0.3.0`

 - **FIX**: resolve all analysis issues and prepare packages for publishing ([#16](https://github.com/ishafiul/fasq/pull/16)).
 - **FEAT**: Add automatic serializer generator for type-safe persistence ([#42](https://github.com/ishafiul/fasq/pull/42)).
 - **FEAT**: enhance CacheDatabase schema setup ([#39](https://github.com/ishafiul/fasq/pull/39)).
 - **FEAT**: introduce cache data codec ([#38](https://github.com/ishafiul/fasq/pull/38)).
 - **FEAT**: harden persistence across cache layers ([#36](https://github.com/ishafiul/fasq/pull/36)).
 - **FEAT**: example app ([#23](https://github.com/ishafiul/fasq/pull/23)).
 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal ([#47](https://github.com/ishafiul/fasq/pull/47)).
 - **BREAKING** **FEAT**: Extract security features to separate fasq_security package ([#11](https://github.com/ishafiul/fasq/pull/11)).

#### `fasq_serializer_generator` - `v0.1.2`

 - **FEAT**: Add automatic serializer generator for type-safe persistence ([#42](https://github.com/ishafiul/fasq/pull/42)).


## 2026-01-13

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.4.2+1`](#fasq---v0421)
 - [`fasq_bloc` - `v0.3.1+1`](#fasq_bloc---v0311)
 - [`fasq_security` - `v0.2.0+3`](#fasq_security---v0203)
 - [`fasq_hooks` - `v0.3.0+3`](#fasq_hooks---v0303)
 - [`fasq_serializer_generator` - `v0.1.1+7`](#fasq_serializer_generator---v0117)
 - [`fasq_riverpod` - `v0.3.1+1`](#fasq_riverpod---v0311)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `fasq_bloc` - `v0.3.1+1`
 - `fasq_security` - `v0.2.0+3`
 - `fasq_hooks` - `v0.3.0+3`
 - `fasq_serializer_generator` - `v0.1.1+7`
 - `fasq_riverpod` - `v0.3.1+1`

---

#### `fasq` - `v0.4.2+1`

 - **REFACTOR**: Improve query and mutation handling in widgets ([#56](https://github.com/ishafiul/fasq/pull/56)).


## 2026-01-11

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq_riverpod` - `v0.3.1`](#fasq_riverpod---v031)

---

#### `fasq_riverpod` - `v0.3.1`

 - **FEAT**: Riverpod Update ([#54](https://github.com/ishafiul/fasq/pull/54)).


## 2026-01-04

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.4.2`](#fasq---v042)
 - [`fasq_bloc` - `v0.3.1`](#fasq_bloc---v031)
 - [`fasq_security` - `v0.2.0+2`](#fasq_security---v0202)
 - [`fasq_hooks` - `v0.3.0+2`](#fasq_hooks---v0302)
 - [`fasq_serializer_generator` - `v0.1.1+6`](#fasq_serializer_generator---v0116)
 - [`fasq_riverpod` - `v0.3.0+2`](#fasq_riverpod---v0302)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `fasq_security` - `v0.2.0+2`
 - `fasq_hooks` - `v0.3.0+2`
 - `fasq_serializer_generator` - `v0.1.1+6`
 - `fasq_riverpod` - `v0.3.0+2`

---

#### `fasq` - `v0.4.2`

 - **REFACTOR**: Update LeakDetector to throw Exception instead of TestFailure.
 - **FEAT**: Error Tracking System for Production Diagnostics ([#52](https://github.com/ishafiul/fasq/pull/52)).

#### `fasq_bloc` - `v0.3.1`

 - **FEAT**(fasq_bloc): Major Refactor - Composition, Lifecycle Hooks, and Feature Parity ([#53](https://github.com/ishafiul/fasq/pull/53)).


## 2026-01-03

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.4.1`](#fasq---v041)
 - [`fasq_bloc` - `v0.3.0+1`](#fasq_bloc---v0301)
 - [`fasq_security` - `v0.2.0+1`](#fasq_security---v0201)
 - [`fasq_hooks` - `v0.3.0+1`](#fasq_hooks---v0301)
 - [`fasq_serializer_generator` - `v0.1.1+5`](#fasq_serializer_generator---v0115)
 - [`fasq_riverpod` - `v0.3.0+1`](#fasq_riverpod---v0301)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `fasq_bloc` - `v0.3.0+1`
 - `fasq_security` - `v0.2.0+1`
 - `fasq_hooks` - `v0.3.0+1`
 - `fasq_serializer_generator` - `v0.1.1+5`
 - `fasq_riverpod` - `v0.3.0+1`

---

#### `fasq` - `v0.4.1`

 - **FEAT**: Leak Detection ([#51](https://github.com/ishafiul/fasq/pull/51)).
 - **FEAT**: Memory Management with Pressure Handling & Leak Detection ([#50](https://github.com/ishafiul/fasq/pull/50)).
 - **FEAT**(fasq): add performance metrics, optimize IsolatePool, and improve lifecycle ([#49](https://github.com/ishafiul/fasq/pull/49)).
 - **FEAT**: Built-in Logging for Query and Mutation Lifecycle Events ([#48](https://github.com/ishafiul/fasq/pull/48)).


## 2025-12-29

### Changes

---

Packages with breaking changes:

 - [`fasq` - `v0.4.0`](#fasq---v040)
 - [`fasq_bloc` - `v0.3.0`](#fasq_bloc---v030)
 - [`fasq_hooks` - `v0.3.0`](#fasq_hooks---v030)
 - [`fasq_riverpod` - `v0.3.0`](#fasq_riverpod---v030)
 - [`fasq_security` - `v0.2.0`](#fasq_security---v020)

Packages with other changes:

 - [`fasq_serializer_generator` - `v0.1.1+4`](#fasq_serializer_generator---v0114)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `fasq_serializer_generator` - `v0.1.1+4`

---

#### `fasq` - `v0.4.0`

 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal ([#47](https://github.com/ishafiul/fasq/pull/47)).

#### `fasq_bloc` - `v0.3.0`

 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal ([#47](https://github.com/ishafiul/fasq/pull/47)).

#### `fasq_hooks` - `v0.3.0`

 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal ([#47](https://github.com/ishafiul/fasq/pull/47)).

#### `fasq_riverpod` - `v0.3.0`

 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal ([#47](https://github.com/ishafiul/fasq/pull/47)).

#### `fasq_security` - `v0.2.0`

 - **BREAKING** **FEAT**(core): Parent-Child Query Cancellation & Cascading Disposal ([#47](https://github.com/ishafiul/fasq/pull/47)).


## 2025-12-28

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.3.8`](#fasq---v038)
 - [`fasq_bloc` - `v0.2.4+3`](#fasq_bloc---v0243)
 - [`fasq_security` - `v0.1.4+2`](#fasq_security---v0142)
 - [`fasq_hooks` - `v0.2.4+3`](#fasq_hooks---v0243)
 - [`fasq_serializer_generator` - `v0.1.1+2`](#fasq_serializer_generator---v0112)
 - [`fasq_riverpod` - `v0.2.4+3`](#fasq_riverpod---v0243)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `fasq_bloc` - `v0.2.4+3`
 - `fasq_security` - `v0.1.4+2`
 - `fasq_hooks` - `v0.2.4+3`
 - `fasq_serializer_generator` - `v0.1.1+2`
 - `fasq_riverpod` - `v0.2.4+3`

---

#### `fasq` - `v0.3.8`

 - **FEAT**(circuit-breaker): Implement circuit breaker pattern for query protection ([#45](https://github.com/ishafiul/fasq/pull/45)).


## 2025-12-26

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.3.7+1`](#fasq---v0371)
 - [`fasq_bloc` - `v0.2.4+2`](#fasq_bloc---v0242)
 - [`fasq_hooks` - `v0.2.4+2`](#fasq_hooks---v0242)
 - [`fasq_riverpod` - `v0.2.4+2`](#fasq_riverpod---v0242)
 - [`fasq_security` - `v0.1.4+1`](#fasq_security---v0141)
 - [`fasq_serializer_generator` - `v0.1.1+1`](#fasq_serializer_generator---v0111)

---

#### `fasq` - `v0.3.7+1`


#### `fasq_bloc` - `v0.2.4+2`


#### `fasq_hooks` - `v0.2.4+2`


#### `fasq_riverpod` - `v0.2.4+2`


#### `fasq_security` - `v0.1.4+1`


#### `fasq_serializer_generator` - `v0.1.1+1`



## 2025-12-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq_serializer_generator` - `v0.1.1`](#fasq_serializer_generator---v011)

---

#### `fasq_serializer_generator` - `v0.1.1`

 - **FEAT**: Add automatic serializer generator for type-safe persistence ([#42](https://github.com/ishafiul/fasq/pull/42)).


## 2025-12-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ecommerce` - `v0.0.2`](#ecommerce---v002)
 - [`fasq` - `v0.3.7`](#fasq---v037)
 - [`fasq_bloc` - `v0.2.4+1`](#fasq_bloc---v0241)
 - [`fasq_hooks` - `v0.2.4+1`](#fasq_hooks---v0241)
 - [`fasq_riverpod` - `v0.2.4+1`](#fasq_riverpod---v0241)
 - [`fasq_security` - `v0.1.4`](#fasq_security---v014)

---

#### `ecommerce` - `v0.0.2`

 - **FEAT**(tests): add persistence check tests for promotional content and query client integration.
 - **FEAT**: Add automatic serializer generator for type-safe persistence ([#42](https://github.com/ishafiul/fasq/pull/42)).

#### `fasq` - `v0.3.7`

 - **FIX**: wait for persistence initialization before creating queries ([#41](https://github.com/ishafiul/fasq/pull/41)).
 - **FEAT**: Add automatic serializer generator for type-safe persistence ([#42](https://github.com/ishafiul/fasq/pull/42)).

#### `fasq_bloc` - `v0.2.4+1`


#### `fasq_hooks` - `v0.2.4+1`


#### `fasq_riverpod` - `v0.2.4+1`


#### `fasq_security` - `v0.1.4`

 - **FEAT**: Add automatic serializer generator for type-safe persistence ([#42](https://github.com/ishafiul/fasq/pull/42)).


## 2025-11-20

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.3.6`](#fasq---v036)
 - [`fasq_bloc` - `v0.2.4`](#fasq_bloc---v024)
 - [`fasq_hooks` - `v0.2.4`](#fasq_hooks---v024)
 - [`fasq_riverpod` - `v0.2.4`](#fasq_riverpod---v024)
 - [`fasq_security` - `v0.1.3`](#fasq_security---v013)

---

#### `fasq` - `v0.3.6`

 - **FIX**: ensure query cache cleanup and proper disposal.
 - **FEAT**: introduce cache data codec ([#38](https://github.com/ishafiul/fasq/pull/38)).

#### `fasq_bloc` - `v0.2.4`

 - **FIX**: ensure query cache cleanup and proper disposal.
 - **FEAT**: introduce cache data codec ([#38](https://github.com/ishafiul/fasq/pull/38)).

#### `fasq_hooks` - `v0.2.4`

 - **FIX**: ensure query cache cleanup and proper disposal.
 - **FEAT**: introduce cache data codec ([#38](https://github.com/ishafiul/fasq/pull/38)).

#### `fasq_riverpod` - `v0.2.4`

 - **FIX**: ensure query cache cleanup and proper disposal.
 - **FEAT**: introduce cache data codec ([#38](https://github.com/ishafiul/fasq/pull/38)).

#### `fasq_security` - `v0.1.3`

 - **FEAT**: enhance CacheDatabase schema setup ([#39](https://github.com/ishafiul/fasq/pull/39)).
 - **FEAT**: introduce cache data codec ([#38](https://github.com/ishafiul/fasq/pull/38)).


## 2025-11-09

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.3.5`](#fasq---v035)
 - [`fasq_security` - `v0.1.2`](#fasq_security---v012)
 - [`fasq_bloc` - `v0.2.3+1`](#fasq_bloc---v0231)
 - [`fasq_hooks` - `v0.2.3+1`](#fasq_hooks---v0231)
 - [`fasq_riverpod` - `v0.2.3+1`](#fasq_riverpod---v0231)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `fasq_bloc` - `v0.2.3+1`
 - `fasq_hooks` - `v0.2.3+1`
 - `fasq_riverpod` - `v0.2.3+1`

---

#### `fasq` - `v0.3.5`

 - **FEAT**: harden persistence across cache layers ([#36](https://github.com/ishafiul/fasq/pull/36)).

#### `fasq_security` - `v0.1.2`

 - **FEAT**: harden persistence across cache layers ([#36](https://github.com/ishafiul/fasq/pull/36)).


## 2025-11-08

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.3.4`](#fasq---v034)
 - [`fasq_bloc` - `v0.2.3`](#fasq_bloc---v023)
 - [`fasq_hooks` - `v0.2.3`](#fasq_hooks---v023)
 - [`fasq_riverpod` - `v0.2.3`](#fasq_riverpod---v023)
 - [`fasq_security` - `v0.1.1`](#fasq_security---v011)

---

#### `fasq` - `v0.3.4`

 - **FEAT**: allow typed meta messages ([#34](https://github.com/ishafiul/fasq/pull/34)).
 - **FEAT**: refine global query effects ([#33](https://github.com/ishafiul/fasq/pull/33)).
 - **FEAT**: add context-aware query observers ([#32](https://github.com/ishafiul/fasq/pull/32)).
 - **FEAT**: allow injecting manual query client ([#31](https://github.com/ishafiul/fasq/pull/31)).

#### `fasq_bloc` - `v0.2.3`

 - **FEAT**: example app ([#23](https://github.com/ishafiul/fasq/pull/23)).

#### `fasq_hooks` - `v0.2.3`


#### `fasq_riverpod` - `v0.2.3`


#### `fasq_security` - `v0.1.1`

 - **FEAT**: example app ([#23](https://github.com/ishafiul/fasq/pull/23)).


## 2025-11-06

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.3.2`](#fasq---v032)
 - [`fasq_bloc` - `v0.2.1`](#fasq_bloc---v021)
 - [`fasq_hooks` - `v0.2.1`](#fasq_hooks---v021)
 - [`fasq_riverpod` - `v0.2.1`](#fasq_riverpod---v021)
 - [`fasq_security` - `v0.1.0+3`](#fasq_security---v0103)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `fasq_security` - `v0.1.0+3`

---

#### `fasq` - `v0.3.2`

 - **FEAT**: add type-safe query keys support ([#28](https://github.com/ishafiul/fasq/pull/28)).

#### `fasq_bloc` - `v0.2.1`

 - **FEAT**: add type-safe query keys support ([#28](https://github.com/ishafiul/fasq/pull/28)).

#### `fasq_hooks` - `v0.2.1`

 - **FEAT**: add type-safe query keys support ([#28](https://github.com/ishafiul/fasq/pull/28)).

#### `fasq_riverpod` - `v0.2.1`

 - **FEAT**: add type-safe query keys support ([#28](https://github.com/ishafiul/fasq/pull/28)).


## 2025-11-06

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.3.1+1`](#fasq---v0311)
 - [`fasq_bloc` - `v0.2.0+2`](#fasq_bloc---v0202)
 - [`fasq_security` - `v0.1.0+2`](#fasq_security---v0102)
 - [`fasq_hooks` - `v0.2.0+2`](#fasq_hooks---v0202)
 - [`fasq_riverpod` - `v0.2.0+2`](#fasq_riverpod---v0202)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `fasq_security` - `v0.1.0+2`
 - `fasq_hooks` - `v0.2.0+2`
 - `fasq_riverpod` - `v0.2.0+2`

---

#### `fasq` - `v0.3.1+1`

 - **FIX**: resolve cache type safety issue by reconstructing CacheEntry instead of casting ([#27](https://github.com/ishafiul/fasq/pull/27)).
 - **FIX**: enhance infinite query options and state management ([#25](https://github.com/ishafiul/fasq/pull/25)).

#### `fasq_bloc` - `v0.2.0+2`

 - **REFACTOR**: convert cubits to abstract base classes ([#26](https://github.com/ishafiul/fasq/pull/26)).


## 2025-10-27

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`fasq` - `v0.3.1`](#fasq---v031)
 - [`fasq_bloc` - `v0.2.0+1`](#fasq_bloc---v0201)
 - [`fasq_security` - `v0.1.0+1`](#fasq_security---v0101)
 - [`fasq_hooks` - `v0.2.0+1`](#fasq_hooks---v0201)
 - [`fasq_riverpod` - `v0.2.0+1`](#fasq_riverpod---v0201)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `fasq_bloc` - `v0.2.0+1`
 - `fasq_security` - `v0.1.0+1`
 - `fasq_hooks` - `v0.2.0+1`
 - `fasq_riverpod` - `v0.2.0+1`

---

#### `fasq` - `v0.3.1`

 - **REFACTOR**(performance): simplify isolate pool initialization ([#24](https://github.com/ishafiul/fasq/pull/24)).
 - **FIX**: improve cache staleness handling and query state management ([#22](https://github.com/ishafiul/fasq/pull/22)).
 - **FIX**: comprehensive fixes for reference counting and loading state ([#21](https://github.com/ishafiul/fasq/pull/21)).
 - **FIX**: prevent negative reference count in Query and InfiniteQuery ([#18](https://github.com/ishafiul/fasq/pull/18)).
 - **FEAT**: clear cache when query is disposed to ensure fresh data on revisit ([#20](https://github.com/ishafiul/fasq/pull/20)).


## 2025-10-22

### Changes

---

Packages with breaking changes:

 - [`fasq` - `v0.3.0`](#fasq---v030)
 - [`fasq_bloc` - `v0.2.0`](#fasq_bloc---v020)
 - [`fasq_hooks` - `v0.2.0`](#fasq_hooks---v020)
 - [`fasq_riverpod` - `v0.2.0`](#fasq_riverpod---v020)
 - [`fasq_security` - `v0.1.0`](#fasq_security---v010)

Packages with other changes:

 - There are no other changes in this release.

---

#### `fasq` - `v0.3.0`

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

#### `fasq_bloc` - `v0.2.0`

 - **FIX**: resolve all analysis issues and prepare packages for publishing ([#16](https://github.com/ishafiul/fasq/pull/16)).
 - **FIX**: security ([#9](https://github.com/ishafiul/fasq/pull/9)).
 - **FEAT**: prefetching ([#8](https://github.com/ishafiul/fasq/pull/8)).
 - **FEAT**: implement parallel queries across all adapters ([#6](https://github.com/ishafiul/fasq/pull/6)).
 - **FEAT**: offline mutation queue ([#5](https://github.com/ishafiul/fasq/pull/5)).
 - **FEAT**: dependent queries ([#4](https://github.com/ishafiul/fasq/pull/4)).
 - **FEAT**: infinite queries ([#3](https://github.com/ishafiul/fasq/pull/3)).
 - **BREAKING** **FEAT**: Replace Fixed Combiners with Dynamic Query Combiners ([#7](https://github.com/ishafiul/fasq/pull/7)).

#### `fasq_hooks` - `v0.2.0`

 - **FIX**: resolve all analysis issues and prepare packages for publishing ([#16](https://github.com/ishafiul/fasq/pull/16)).
 - **FIX**: security ([#9](https://github.com/ishafiul/fasq/pull/9)).
 - **FEAT**: prefetching ([#8](https://github.com/ishafiul/fasq/pull/8)).
 - **FEAT**: implement parallel queries across all adapters ([#6](https://github.com/ishafiul/fasq/pull/6)).
 - **FEAT**: dependent queries ([#4](https://github.com/ishafiul/fasq/pull/4)).
 - **FEAT**: infinite queries ([#3](https://github.com/ishafiul/fasq/pull/3)).
 - **BREAKING** **FEAT**: Replace Fixed Combiners with Dynamic Query Combiners ([#7](https://github.com/ishafiul/fasq/pull/7)).

#### `fasq_riverpod` - `v0.2.0`

 - **FIX**: resolve all analysis issues and prepare packages for publishing ([#16](https://github.com/ishafiul/fasq/pull/16)).
 - **FIX**: security ([#9](https://github.com/ishafiul/fasq/pull/9)).
 - **FEAT**: prefetching ([#8](https://github.com/ishafiul/fasq/pull/8)).
 - **FEAT**: implement parallel queries across all adapters ([#6](https://github.com/ishafiul/fasq/pull/6)).
 - **FEAT**: offline mutation queue ([#5](https://github.com/ishafiul/fasq/pull/5)).
 - **FEAT**: dependent queries ([#4](https://github.com/ishafiul/fasq/pull/4)).
 - **FEAT**: infinite queries ([#3](https://github.com/ishafiul/fasq/pull/3)).
 - **BREAKING** **FEAT**: Replace Fixed Combiners with Dynamic Query Combiners ([#7](https://github.com/ishafiul/fasq/pull/7)).

#### `fasq_security` - `v0.1.0`

 - **FIX**: resolve all analysis issues and prepare packages for publishing ([#16](https://github.com/ishafiul/fasq/pull/16)).
 - **BREAKING** **FEAT**: Extract security features to separate fasq_security package ([#11](https://github.com/ishafiul/fasq/pull/11)).

