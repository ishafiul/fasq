class MutationOptions<T, TVariables> {
  final void Function(T data)? onSuccess;
  final void Function(Object error)? onError;
  final void Function(T data, TVariables variables)? onMutate;

  const MutationOptions({
    this.onSuccess,
    this.onError,
    this.onMutate,
  });
}

