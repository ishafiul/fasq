/// Riverpod integration helpers for FASQ queries, mutations, and prefetching.
///
/// Provides idiomatic Riverpod APIs that return `AsyncValue<T>` and use
/// `AutoDisposeAsyncNotifier` for full Riverpod integration with dependency injection.
///
/// ## Core APIs
/// - [queryProvider] - Creates queries that return `AsyncValue<T>`
/// - [infiniteQueryProvider] - Creates paginated queries
/// - [mutationProvider] - Creates mutations with imperative API
/// - [PrefetchExtension] - Extension methods for prefetching
///
/// ## Configuration
/// - [fasqClientProvider] - Main QueryClient provider
/// - Configuration providers for cache, persistence, security, etc.
///
/// ## Legacy APIs
/// Legacy StateNotifier-based APIs are available in `package:fasq_riverpod/legacy.dart`
/// for backward compatibility.
library;

export 'package:fasq/fasq.dart';
export 'package:flutter_riverpod/flutter_riverpod.dart';

export 'src/mutation/index.dart';
export 'src/prefetch/index.dart';
// Core APIs - Idiomatic Riverpod with AsyncValue and AutoDisposeAsyncNotifier
export 'src/provider/index.dart';
export 'src/query/index.dart';
