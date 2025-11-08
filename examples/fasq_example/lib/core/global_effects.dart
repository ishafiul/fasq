import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class GlobalQueryEffects extends QueryClientObserver {
  GlobalQueryEffects({
    required this.client,
    required this.scaffoldMessengerKey,
    this.onLogout,
    this.resolveMessage,
  });

  final QueryClient client;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final VoidCallback? onLogout;
  final String Function(String messageId)? resolveMessage;

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
    _maybeLogout(meta);
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
    _maybeLogout(meta);
  }

  void _showMessage(String? messageId, BuildContext? context) {
    if (messageId == null) return;
    final text = resolveMessage?.call(messageId) ?? messageId;
    final messenger = _scaffoldMessenger(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(text)));
  }

  ScaffoldMessengerState? _scaffoldMessenger(BuildContext? context) {
    if (context != null && context.mounted) {
      return ScaffoldMessenger.maybeOf(context);
    }
    return scaffoldMessengerKey.currentState;
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

  void _maybeLogout(dynamic meta) {
    final shouldLogout = (meta is MutationMeta && meta.logoutOnError) ||
        (meta is QueryMeta && meta.logoutOnError);
    if (shouldLogout) {
      onLogout?.call();
    }
  }
}
