import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class EffectMessenger {
  EffectMessenger({GlobalKey<ScaffoldMessengerState>? key})
      : _key = key ?? GlobalKey<ScaffoldMessengerState>();

  final GlobalKey<ScaffoldMessengerState> _key;

  GlobalKey<ScaffoldMessengerState> get key => _key;

  void show(String message) {
    final state = _key.currentState;
    state
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class GlobalQueryEffects extends QueryClientObserver {
  GlobalQueryEffects._({
    required this.client,
    this.messenger,
    this.resolveMessage,
    this.onMutationCritical,
    this.onQueryCritical,
  });

  final QueryClient client;
  final EffectMessenger? messenger;
  final String Function(String messageId)? resolveMessage;
  final void Function(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta meta,
  )? onMutationCritical;
  final void Function(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta meta,
  )? onQueryCritical;

  static GlobalQueryEffects install({
    required QueryClient client,
    EffectMessenger? messenger,
    String Function(String messageId)? resolveMessage,
    void Function(
      MutationSnapshot<dynamic, dynamic> snapshot,
      MutationMeta meta,
    )? onMutationCritical,
    void Function(
      QuerySnapshot<dynamic> snapshot,
      QueryMeta meta,
    )? onQueryCritical,
  }) {
    final effects = GlobalQueryEffects._(
      client: client,
      messenger: messenger,
      resolveMessage: resolveMessage,
      onMutationCritical: onMutationCritical,
      onQueryCritical: onQueryCritical,
    );

    client.addObserver(effects);
    return effects;
  }

  @override
  void onMutationSuccess(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    _showMessage(meta?.successMessageId, context);
    _invalidate(meta);
    _refetch(meta);
  }

  @override
  void onMutationError(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    _showMessage(meta?.errorMessageId, context);
    _maybeTriggerCritical(snapshot, meta);
  }

  @override
  void onMutationSettled(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    _refetch(meta);
  }

  @override
  void onQuerySuccess(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    _showMessage(meta?.successMessageId, context);
    _invalidate(meta);
  }

  @override
  void onQueryError(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    _showMessage(meta?.errorMessageId, context);
    _maybeTriggerCriticalQuery(snapshot, meta);
  }

  void _showMessage(String? messageId, BuildContext? context) {
    if (messageId == null) return;
    final resolved = resolveMessage?.call(messageId) ?? messageId;

    final contextualMessenger = _messengerFromContext(context);
    if (contextualMessenger != null) {
      contextualMessenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(resolved)));
      return;
    }

    messenger?.show(resolved);
  }

  ScaffoldMessengerState? _messengerFromContext(BuildContext? context) {
    if (context == null || !context.mounted) {
      return null;
    }
    return ScaffoldMessenger.maybeOf(context);
  }

  void _invalidate(dynamic meta) {
    if (meta is MutationMeta) {
      for (final key in meta.invalidateKeys) {
        client.invalidateQuery(key);
      }
    } else if (meta is QueryMeta) {
      for (final key in meta.invalidateKeys) {
        client.invalidateQuery(key);
      }
    }
  }

  void _refetch(MutationMeta? meta) {
    if (meta == null) return;
    for (final key in meta.refetchKeys) {
      client.getQueryByKey(key)?.fetch();
    }
  }

  void _maybeTriggerCritical(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
  ) {
    if (meta == null || !meta.triggerCriticalHandler) {
      return;
    }
    onMutationCritical?.call(snapshot, meta);
  }

  void _maybeTriggerCriticalQuery(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
  ) {
    if (meta == null || !meta.triggerCriticalHandler) {
      return;
    }
    onQueryCritical?.call(snapshot, meta);
  }
}
