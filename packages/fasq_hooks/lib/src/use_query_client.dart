import 'package:fasq_hooks/fasq_hooks.dart';

/// Returns the ambient [QueryClient] instance for hook-enabled widgets.
///
/// A specific client can be provided for testing; otherwise the global
/// singleton from `QueryClient()` is used.
QueryClient useQueryClient({QueryClient? client}) {
  return client ?? QueryClient();
}
