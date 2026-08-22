import 'package:fasq/src/runtime/fasq_runtime.dart';
import 'package:fasq/src/widgets/query_client_provider.dart';
import 'package:flutter/widgets.dart';

/// Exposes one initialized query and durable-mutation runtime to a widget tree.
///
/// This provider borrows [runtime]. Initialization and disposal remain owned
/// by the application bootstrap. Security and persistence packages can supply
/// their own [FasqRuntime] implementation without becoming core dependencies.
class FasqProvider extends StatelessWidget {
  /// Creates the canonical Fasq widget-tree provider.
  const FasqProvider({
    required this.runtime,
    required this.child,
    super.key,
  });

  /// Initialized runtime supplied by the application bootstrap.
  final FasqRuntime runtime;

  /// Widget subtree that consumes the runtime.
  final Widget child;

  /// Returns the nearest runtime or throws a configuration error.
  static FasqRuntime of(BuildContext context) {
    final runtime = maybeOf(context);
    if (runtime == null) {
      throw FlutterError(
        'No FasqProvider found. Wrap the application in FasqProvider.',
      );
    }
    return runtime;
  }

  /// Returns the nearest runtime, or `null` when no provider exists.
  static FasqRuntime? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_FasqRuntimeInherited>()
        ?.runtime;
  }

  @override
  Widget build(BuildContext context) {
    return QueryClientProvider(
      client: runtime.queryClient,
      child: _FasqRuntimeInherited(
        runtime: runtime,
        child: child,
      ),
    );
  }
}

class _FasqRuntimeInherited extends InheritedWidget {
  const _FasqRuntimeInherited({
    required this.runtime,
    required super.child,
  });

  final FasqRuntime runtime;

  @override
  bool updateShouldNotify(_FasqRuntimeInherited oldWidget) {
    return !identical(runtime, oldWidget.runtime);
  }
}

/// Convenient access to the nearest core Fasq runtime.
extension FasqProviderContext on BuildContext {
  /// Returns the nearest runtime.
  FasqRuntime get fasqRuntime => FasqProvider.of(this);
}
