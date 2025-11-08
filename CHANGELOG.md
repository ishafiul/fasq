# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

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

 - **FEAT**: harden persistence across cache layers (#36).
 - **DOCS**: sync readme versions (#35).

#### `fasq_security` - `v0.1.2`

 - **FEAT**: harden persistence across cache layers (#36).
 - **DOCS**: sync readme versions (#35).


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

 - **FEAT**: allow typed meta messages (#34).
 - **FEAT**: refine global query effects (#33).
 - **FEAT**: add context-aware query observers (#32).
 - **FEAT**: allow injecting manual query client (#31).
 - **FEAT**: update SEO and metadata handling.

#### `fasq_bloc` - `v0.2.3`

 - **FEAT**: update SEO and metadata handling.
 - **FEAT**: example app (#23).

#### `fasq_hooks` - `v0.2.3`

 - **FEAT**: update SEO and metadata handling.

#### `fasq_riverpod` - `v0.2.3`

 - **FEAT**: update SEO and metadata handling.

#### `fasq_security` - `v0.1.1`

 - **FEAT**: example app (#23).


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

 - **FEAT**: add type-safe query keys support (#28).

#### `fasq_bloc` - `v0.2.1`

 - **FEAT**: add type-safe query keys support (#28).

#### `fasq_hooks` - `v0.2.1`

 - **FEAT**: add type-safe query keys support (#28).

#### `fasq_riverpod` - `v0.2.1`

 - **FEAT**: add type-safe query keys support (#28).


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

 - **FIX**: resolve cache type safety issue by reconstructing CacheEntry instead of casting (#27).
 - **FIX**: enhance infinite query options and state management (#25).

#### `fasq_bloc` - `v0.2.0+2`

 - **REFACTOR**: convert cubits to abstract base classes (#26).


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

 - **REFACTOR**(performance): simplify isolate pool initialization (#24).
 - **FIX**: improve cache staleness handling and query state management (#22).
 - **FIX**: comprehensive fixes for reference counting and loading state (#21).
 - **FIX**: prevent negative reference count in Query and InfiniteQuery (#18).
 - **FEAT**: clear cache when query is disposed to ensure fresh data on revisit (#20).


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

#### `fasq_bloc` - `v0.2.0`

 - **FIX**: resolve all analysis issues and prepare packages for publishing (#16).
 - **FIX**: security (#9).
 - **FEAT**: prefetching (#8).
 - **FEAT**: implement parallel queries across all adapters (#6).
 - **FEAT**: offline mutation queue (#5).
 - **FEAT**: dependent queries (#4).
 - **FEAT**: infinite queries (#3).
 - **BREAKING** **FEAT**: Replace Fixed Combiners with Dynamic Query Combiners (#7).

#### `fasq_hooks` - `v0.2.0`

 - **FIX**: resolve all analysis issues and prepare packages for publishing (#16).
 - **FIX**: security (#9).
 - **FEAT**: prefetching (#8).
 - **FEAT**: implement parallel queries across all adapters (#6).
 - **FEAT**: dependent queries (#4).
 - **FEAT**: infinite queries (#3).
 - **BREAKING** **FEAT**: Replace Fixed Combiners with Dynamic Query Combiners (#7).

#### `fasq_riverpod` - `v0.2.0`

 - **FIX**: resolve all analysis issues and prepare packages for publishing (#16).
 - **FIX**: security (#9).
 - **FEAT**: prefetching (#8).
 - **FEAT**: implement parallel queries across all adapters (#6).
 - **FEAT**: offline mutation queue (#5).
 - **FEAT**: dependent queries (#4).
 - **FEAT**: infinite queries (#3).
 - **BREAKING** **FEAT**: Replace Fixed Combiners with Dynamic Query Combiners (#7).

#### `fasq_security` - `v0.1.0`

 - **FIX**: resolve all analysis issues and prepare packages for publishing (#16).
 - **DOCS**: Clean up README by removing phase references and PRD mentions (#14).
 - **BREAKING** **FEAT**: Extract security features to separate fasq_security package (#11).

