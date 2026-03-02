import 'package:fasq/src/query/keys/query_key.dart';
import 'package:fasq/src/query/query_meta.dart';
import 'package:fasq/src/query/query_options.dart';
import 'package:fasq/src/query/query_state.dart';

/// Immutable state transition snapshot emitted by a query update.
///
/// It contains the query identity, previous state, current state, and the
/// options used by the query when the transition occurred.
class QuerySnapshot<T> {
  /// Creates a [QuerySnapshot] for a query state change.
  const QuerySnapshot({
    required this.queryKey,
    required this.previousState,
    required this.currentState,
    required this.options,
  });

  /// Key that uniquely identifies the query.
  final QueryKey queryKey;

  /// Query state before the transition.
  final QueryState<T> previousState;

  /// Query state after the transition.
  final QueryState<T> currentState;

  /// Query configuration associated with this transition.
  final QueryOptions? options;

  /// Metadata attached to the query options, if available.
  QueryMeta? get meta => options?.meta;
}
