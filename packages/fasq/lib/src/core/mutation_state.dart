import 'package:fasq/src/core/mutation_status.dart';
import 'package:meta/meta.dart';

/// Immutable state model for a mutation lifecycle.
@immutable
class MutationState<T> {
  /// Internal constructor used by [copyWith].
  const MutationState._({
    required this.status,
    this.data,
    this.error,
    this.stackTrace,
    this.isQueued = false,
  });

  /// Creates an idle mutation state.
  const MutationState.idle()
      : status = MutationStatus.idle,
        data = null,
        error = null,
        stackTrace = null,
        isQueued = false;

  /// Creates a loading mutation state.
  const MutationState.loading()
      : status = MutationStatus.loading,
        data = null,
        error = null,
        stackTrace = null,
        isQueued = false;

  /// Creates a successful mutation state containing [data].
  const MutationState.success(this.data)
      : status = MutationStatus.success,
        error = null,
        stackTrace = null,
        isQueued = false;

  /// Creates an error mutation state with [error] and optional [stackTrace].
  const MutationState.error(this.error, [this.stackTrace])
      : status = MutationStatus.error,
        data = null,
        isQueued = false;

  /// Creates a queued mutation state for offline execution.
  const MutationState.queued()
      : status = MutationStatus.idle,
        data = null,
        error = null,
        stackTrace = null,
        isQueued = true;

  /// Current lifecycle status.
  final MutationStatus status;

  /// Mutation result data when successful.
  final T? data;

  /// Error captured when mutation fails.
  final Object? error;

  /// Stack trace associated with [error], if available.
  final StackTrace? stackTrace;

  /// Whether this mutation is queued for later execution.
  final bool isQueued;

  /// Whether the mutation is idle.
  bool get isIdle => status == MutationStatus.idle;

  /// Whether the mutation is currently running.
  bool get isLoading => status == MutationStatus.loading;

  /// Whether the mutation finished successfully.
  bool get isSuccess => status == MutationStatus.success;

  /// Whether the mutation finished with an error.
  bool get isError => status == MutationStatus.error;

  /// Whether successful data is currently available.
  bool get hasData => data != null;

  /// Whether an error is currently available.
  bool get hasError => error != null;

  /// Returns a copy of this state with selective overrides.
  MutationState<T> copyWith({
    MutationStatus? status,
    T? data,
    Object? error,
    StackTrace? stackTrace,
    bool? isQueued,
  }) {
    return MutationState._(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      isQueued: isQueued ?? this.isQueued,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MutationState<T> &&
        other.status == status &&
        other.data == data &&
        other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      data,
      error,
    );
  }

  @override
  String toString() {
    return 'MutationState<$T>(status: $status, data: $data, error: $error)';
  }
}
