import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mutation_notifier.dart';

/// Creates a Riverpod provider backed by an immediate or durable mutation.
///
/// Pass exactly one of the positional [mutationFn] and named [mutationKey].
/// A durable key resolves its executor and queue from [runtime] or the
/// overridden [fasqRuntimeProvider].
AutoDisposeNotifierProvider<MutationNotifier<T, TVariables>, MutationState<T>>
mutationProvider<T, TVariables>(
  Future<T> Function(TVariables variables)? mutationFn, {
  FasqMutationKey<T, TVariables>? mutationKey,
  MutationOptions<T, TVariables>? options,
  QueryClient? client,
  FasqRuntime? runtime,
}) {
  _validateMutationSources(mutationFn, mutationKey);
  return AutoDisposeNotifierProvider<
    MutationNotifier<T, TVariables>,
    MutationState<T>
  >(() {
    final notifier = MutationNotifier<T, TVariables>();
    notifier.configure(
      mutationFn: mutationFn,
      mutationKey: mutationKey,
      options: options,
      client: client,
      runtime: runtime,
    );
    return notifier;
  });
}

/// Named alias for callers creating a provider from a durable key.
AutoDisposeNotifierProvider<MutationNotifier<T, TVariables>, MutationState<T>>
durableMutationProvider<T, TVariables>({
  required FasqMutationKey<T, TVariables> mutationKey,
  MutationOptions<T, TVariables>? options,
  QueryClient? client,
  FasqRuntime? runtime,
}) {
  return mutationProvider<T, TVariables>(
    null,
    mutationKey: mutationKey,
    options: options,
    client: client,
    runtime: runtime,
  );
}

void _validateMutationSources<T, TVariables>(
  Future<T> Function(TVariables variables)? mutationFn,
  FasqMutationKey<T, TVariables>? mutationKey,
) {
  if ((mutationFn == null) == (mutationKey == null)) {
    throw ArgumentError('Provide exactly one of mutationFn or mutationKey.');
  }
}
