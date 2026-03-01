import 'package:fasq/src/core/query_state.dart';

/// Represents a dependency value that is only usable when [enabled] is true.
///
/// Commonly created from a [QueryState] to gate downstream logic on successful
/// query completion.
class Dependent<T> {
  /// Creates a dependent value wrapper.
  const Dependent({required this.enabled, required this.value});

  /// Whether the dependent value is available for use.
  final bool enabled;

  /// The dependent value when available.
  final T? value;

  /// Creates a [Dependent] from a [QueryState].
  ///
  /// The returned value is enabled only when [state] is successful.
  static Dependent<T> of<T>(QueryState<T> state) {
    return Dependent<T>(enabled: state.isSuccess, value: state.data);
  }
}

/// Applies [selector] only when [state] is ready with non-null data.
///
/// Returns `null` when data is not available.
R? whenReady<T, R>(QueryState<T> state, R Function(T value) selector) {
  if (state.isSuccess && state.data != null) {
    return selector(state.data as T);
  }
  return null;
}
