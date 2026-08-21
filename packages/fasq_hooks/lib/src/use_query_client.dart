import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Returns the ambient [QueryClient] instance for hook-enabled widgets.
///
/// A specific client can be provided for testing or isolated composition.
/// Otherwise the nearest [QueryClientProvider] is used, with the legacy
/// singleton retained as the compatibility fallback.
QueryClient useQueryClient({QueryClient? client}) {
  final context = useContext();
  return client ?? context.queryClient ?? QueryClient();
}
