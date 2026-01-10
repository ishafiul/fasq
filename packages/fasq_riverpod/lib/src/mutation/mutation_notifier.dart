import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/client_provider.dart';

/// Riverpod-native [AutoDisposeNotifier] that wraps a FASQ [Mutation].
///
/// This is the v2 implementation that provides a more idiomatic Riverpod API
/// while maintaining full compatibility with FASQ's mutation features.
///
/// Unlike queries, mutations don't return AsyncValue because they're triggered
/// imperatively (not declaratively). Instead, the notifier exposes the mutation
/// state directly and provides a `mutate()` method to trigger the mutation.
///
/// The notifier gets the [QueryClient] from [fasqClientProvider], enabling
/// full dependency injection and testability.
///
/// Example:
/// ```dart
/// final createPostMutation = mutationProviderV2<Post, CreatePostInput>(
///   (variables) => api.createPost(variables),
///   options: MutationOptions(
///     onSuccess: (data) => print('Post created: ${data.id}'),
///     onError: (error) => print('Error: $error'),
///   ),
/// );
///
/// // In your widget:
/// final mutation = ref.watch(createPostMutation);
///
/// // Show state
/// if (mutation.isLoading) {
///   return CircularProgressIndicator();
/// }
/// if (mutation.hasError) {
///   return Text('Error: ${mutation.error}');
/// }
///
/// // Trigger mutation
/// ElevatedButton(
///   onPressed: () {
///     ref.read(createPostMutation.notifier).mutate(
///       CreatePostInput(title: 'Hello', body: 'World'),
///     );
///   },
///   child: Text('Create Post'),
/// );
/// ```
class MutationNotifier<T, TVariables>
    extends AutoDisposeNotifier<MutationState<T>> {
  late final Future<T> Function(TVariables variables) _mutationFn;
  late final MutationOptions<T, TVariables>? _options;

  late Mutation<T, TVariables> _mutation;
  StreamSubscription<MutationState<T>>? _subscription;

  /// Initializes the notifier with the mutation configuration.
  ///
  /// This should be called from the provider factory before returning the notifier.
  void configure({
    required Future<T> Function(TVariables variables) mutationFn,
    MutationOptions<T, TVariables>? options,
  }) {
    _mutationFn = mutationFn;
    _options = options;
  }

  @override
  MutationState<T> build() {
    // Ensure QueryClient is available (will be used by Mutation internally)
    ref.watch(fasqClientProvider);

    // Create the mutation
    _mutation = Mutation<T, TVariables>(
      mutationFn: _mutationFn,
      options: _options,
    );

    // Register cleanup callback
    ref.onDispose(_cleanup);

    // Listen to mutation state changes
    _subscription = _mutation.stream.listen((newState) {
      state = newState;
    });

    // Return initial idle state
    return const MutationState.idle();
  }

  /// Triggers the mutation with the given variables.
  ///
  /// This is an imperative API - call it when you want to perform the mutation
  /// (e.g., in response to a button press).
  ///
  /// The state will automatically update to reflect loading, success, or error.
  ///
  /// Example:
  /// ```dart
  /// await ref.read(myMutation.notifier).mutate(variables);
  /// ```
  Future<void> mutate(TVariables variables) async {
    await _mutation.mutate(variables);
  }

  /// Resets the mutation to its idle state.
  ///
  /// Useful for clearing error states or success states before retrying.
  void reset() {
    _mutation.reset();
  }

  /// Cleanup method called by Riverpod framework.
  void _cleanup() {
    _subscription?.cancel();
    _mutation.dispose();
  }
}
