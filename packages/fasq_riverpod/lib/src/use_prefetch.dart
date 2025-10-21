import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hook that prefetches queries on mount.
///
/// Example:
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     ref.prefetchQueries([
///       PrefetchConfig(key: 'users', queryFn: () => api.fetchUsers()),
///     ]);
///     
///     return YourWidget();
///   }
/// }
/// ```
void usePrefetch(WidgetRef ref, List<PrefetchConfig> configs) {
  final client = QueryClient();
  
  // Use a simple approach without hooks since hooks_riverpod isn't available
  client.prefetchQueries(configs);
}
