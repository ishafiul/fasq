import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aggregated [AsyncValue] state for several Riverpod providers.
class CombinedQueriesState {
  /// Creates a combined state from the supplied provider states.
  CombinedQueriesState(Iterable<AsyncValue<dynamic>> states)
    : states = List.unmodifiable(states);

  /// Individual states in the same order as the input providers.
  final List<AsyncValue<dynamic>> states;

  /// Whether every provider is in its initial loading state.
  bool get isAllLoading => states.every(_isLoading);

  /// Whether any provider is loading, including background refresh.
  bool get isAnyLoading => states.any((state) => state.isLoading);

  /// Whether every provider completed successfully.
  bool get isAllSuccess => states.every(_isSuccess);

  /// Whether at least one provider has an error.
  bool get hasAnyError => states.any((state) => state.hasError);

  /// Whether every provider currently has a value.
  bool get isAllData => states.every((state) => state.hasValue);

  /// Number of combined providers.
  int get length => states.length;

  /// Gets one provider state with the requested value type.
  AsyncValue<T> getState<T>(int index) => _typedAsyncValue(states[index]);

  static bool _isLoading(AsyncValue<dynamic> state) => state.isLoading;

  static bool _isSuccess(AsyncValue<dynamic> state) =>
      state is AsyncData<dynamic>;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CombinedQueriesState && _listEquals(states, other.states);
  }

  @override
  int get hashCode => Object.hashAll(states);
}

/// Aggregated named [AsyncValue] state for several Riverpod providers.
class NamedQueriesState {
  /// Creates a named combined state.
  NamedQueriesState(Map<String, AsyncValue<dynamic>> states)
    : states = Map.unmodifiable(states);

  /// Individual states keyed by the names supplied to [combineNamedQueries].
  final Map<String, AsyncValue<dynamic>> states;

  /// Whether every provider is in its initial loading state.
  bool get isAllLoading => states.values.every(_isLoading);

  /// Whether any provider is loading, including background refresh.
  bool get isAnyLoading => states.values.any((state) => state.isLoading);

  /// Whether every provider completed successfully.
  bool get isAllSuccess => states.values.every(_isSuccess);

  /// Whether at least one provider has an error.
  bool get hasAnyError => states.values.any((state) => state.hasError);

  /// Whether every provider currently has a value.
  bool get isAllData => states.values.every((state) => state.hasValue);

  /// Number of combined providers.
  int get length => states.length;

  /// Gets one named provider state with the requested value type.
  AsyncValue<T> getState<T>(String name) => _typedAsyncValue(states[name]!);

  /// Whether a named provider is loading.
  bool isLoading(String name) => states[name]?.isLoading ?? false;

  /// Whether a named provider has an error.
  bool hasError(String name) => states[name]?.hasError ?? false;

  static bool _isLoading(AsyncValue<dynamic> state) => state.isLoading;

  static bool _isSuccess(AsyncValue<dynamic> state) =>
      state is AsyncData<dynamic>;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NamedQueriesState && _mapEquals(states, other.states);
  }

  @override
  int get hashCode => Object.hashAll(
    states.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}

/// Combines several query-like Riverpod providers into one provider.
///
/// The inputs may be [queryProvider] instances, ordinary `FutureProvider`s,
/// or any other provider that returns [AsyncValue]. The returned provider
/// watches every input, so updates and errors remain independent.
Provider<CombinedQueriesState> combineQueries(
  List<ProviderListenable<dynamic>> providers,
) {
  return Provider<CombinedQueriesState>((ref) {
    final states = <AsyncValue<dynamic>>[];
    for (final provider in providers) {
      final value = ref.watch(provider);
      if (value is! AsyncValue<dynamic>) {
        throw StateError('combineQueries inputs must return AsyncValue.');
      }
      states.add(value);
    }
    return CombinedQueriesState(states);
  });
}

/// Combines named query-like Riverpod providers into one provider.
Provider<NamedQueriesState> combineNamedQueries(
  Map<String, ProviderListenable<dynamic>> providers,
) {
  return Provider<NamedQueriesState>((ref) {
    final states = <String, AsyncValue<dynamic>>{};
    providers.forEach((name, provider) {
      final value = ref.watch(provider);
      if (value is! AsyncValue<dynamic>) {
        throw StateError('combineNamedQueries inputs must return AsyncValue.');
      }
      states[name] = value;
    });
    return NamedQueriesState(states);
  });
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> left, Map<K, V> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

AsyncValue<T> _typedAsyncValue<T>(AsyncValue<dynamic> source) {
  if (source.hasError) {
    final errorState = AsyncError<T>(
      source.error!,
      source.stackTrace ?? StackTrace.current,
    );
    if (source.hasValue) {
      return errorState.copyWithPrevious(AsyncData<T>(source.value as T));
    }
    return errorState;
  }
  if (source.hasValue) {
    final dataState = AsyncData<T>(source.value as T);
    if (source.isLoading) {
      return AsyncLoading<T>().copyWithPrevious(dataState);
    }
    return dataState;
  }
  return const AsyncLoading<Never>() as AsyncValue<T>;
}
