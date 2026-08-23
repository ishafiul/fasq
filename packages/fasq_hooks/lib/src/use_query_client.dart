import 'package:fasq/fasq.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Returns the explicit, runtime-provided, or legacy singleton client.
QueryClient useQueryClient({QueryClient? client}) {
  final context = useContext();
  return client ?? context.queryClient ?? QueryClient();
}

/// Returns the nearest initialized FASQ runtime.
FasqRuntime useFasqRuntime({FasqRuntime? runtime}) {
  if (runtime != null) return runtime;
  return FasqProvider.of(useContext());
}
