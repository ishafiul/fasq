import 'query_state.dart';

class Dependent<T> {
  final bool enabled;
  final T? value;
  const Dependent({required this.enabled, required this.value});

  static Dependent<T> of<T>(QueryState<T> state) {
    return Dependent<T>(enabled: state.isSuccess, value: state.data);
  }
}

R? whenReady<T, R>(QueryState<T> state, R Function(T value) selector) {
  if (state.isSuccess && state.data != null) {
    return selector(state.data as T);
  }
  return null;
}
