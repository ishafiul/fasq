/// Entry point for the FASQ (Flutter Async State Query) package.
///
/// Exported APIs cover query/mutation primitives, caching, pagination,
/// performance tooling, persistence, and Flutter widgets for integrating
/// async data flows into applications.
library;

export 'src/cache/cache_config.dart';
export 'src/cache/cache_entry.dart';
export 'src/cache/cache_metrics.dart';
export 'src/cache/eviction_policy.dart';
export 'src/cache/hot_cache.dart';
export 'src/cache/query_cache.dart';
export 'src/core/mutation.dart';
export 'src/core/mutation_meta.dart';
export 'src/core/mutation_options.dart';
export 'src/core/mutation_snapshot.dart';
export 'src/core/mutation_state.dart';
export 'src/core/mutation_status.dart';
export 'src/core/query.dart';
export 'src/core/query_client.dart';
export 'src/core/query_client_observer.dart';
export 'src/core/query_key.dart';
export 'src/core/query_meta.dart';
export 'src/core/query_options.dart';
export 'src/core/query_snapshot.dart';
export 'src/core/query_state.dart';
export 'src/core/query_status.dart';
export 'src/core/typed_query_key.dart';
export 'src/core/infinite_query.dart';
export 'src/core/infinite_query_state.dart';
export 'src/core/infinite_query_options.dart';
export 'src/core/prefetch_config.dart';
export 'src/core/dependent.dart';
export 'src/core/network_status.dart';
export 'src/core/offline_queue.dart';
export 'src/pagination/page_number_pagination.dart';
export 'src/pagination/cursor_pagination.dart';
export 'src/performance/isolate_pool.dart';
export 'src/performance/isolate_task.dart';
export 'src/performance/performance_monitor.dart';
export 'src/persistence/cache_data_codec.dart';
export 'src/persistence/persistence_options.dart';
export 'src/security/security_plugin.dart';
export 'src/security/security_provider.dart';
export 'src/security/encryption_provider.dart';
export 'src/security/persistence_provider.dart';
export 'src/widgets/mutation_builder.dart';
export 'src/widgets/query_builder.dart';
export 'src/widgets/query_client_provider.dart';
