import 'mutation_status.dart';

class MutationState<T> {
  final MutationStatus status;
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;
  final bool isQueued;

  const MutationState._({
    required this.status,
    this.data,
    this.error,
    this.stackTrace,
    this.isQueued = false,
  });

  const MutationState.idle()
      : status = MutationStatus.idle,
        data = null,
        error = null,
        stackTrace = null,
        isQueued = false;

  const MutationState.loading()
      : status = MutationStatus.loading,
        data = null,
        error = null,
        stackTrace = null,
        isQueued = false;

  const MutationState.success(this.data)
      : status = MutationStatus.success,
        error = null,
        stackTrace = null,
        isQueued = false;

  const MutationState.error(this.error, [this.stackTrace])
      : status = MutationStatus.error,
        data = null,
        isQueued = false;

  const MutationState.queued()
      : status = MutationStatus.idle,
        data = null,
        error = null,
        stackTrace = null,
        isQueued = true;

  bool get isIdle => status == MutationStatus.idle;
  bool get isLoading => status == MutationStatus.loading;
  bool get isSuccess => status == MutationStatus.success;
  bool get isError => status == MutationStatus.error;
  bool get hasData => data != null;
  bool get hasError => error != null;

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
