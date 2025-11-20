import 'dart:async';

import 'package:ecommerce/core/services/navigator_key_service.dart';
import 'package:ecommerce/core/widgets/snackbar.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

@singleton
class SnackbarManager extends QueryClientObserver {
  final NavigatorKeyService _navigatorKeyService;

  SnackbarManager(this._navigatorKeyService);

  BuildContext? get _context {
    return _navigatorKeyService.navigatorKey.currentContext;
  }

  ScaffoldMessengerState? _getMessenger(BuildContext? context) {
    if (context != null && context.mounted) {
      return ScaffoldMessenger.maybeOf(context);
    }
    final navigatorContext = _context;
    if (navigatorContext != null && navigatorContext.mounted) {
      return ScaffoldMessenger.maybeOf(navigatorContext);
    }
    return null;
  }

  @override
  void onQueryError(QuerySnapshot<dynamic> snapshot, QueryMeta? meta, BuildContext? context) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;

    final errorMessage = meta?.errorMessage;
    if (errorMessage == null || errorMessage.isEmpty) return;

    final effectiveContext = context ?? _context;
    if (effectiveContext == null) return;

    unawaited(showSnackBar(context: effectiveContext, type: SnackBarType.error, message: errorMessage, withIcon: true));
  }

  @override
  void onMutationError(MutationSnapshot<dynamic, dynamic> snapshot, MutationMeta? meta, BuildContext? context) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;

    final errorMessage = meta?.errorMessage;
    if (errorMessage == null || errorMessage.isEmpty) return;

    final effectiveContext = context ?? _context;
    if (effectiveContext == null) return;

    unawaited(showSnackBar(context: effectiveContext, type: SnackBarType.error, message: errorMessage, withIcon: true));
  }

  @override
  void onQuerySuccess(QuerySnapshot<dynamic> snapshot, QueryMeta? meta, BuildContext? context) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;

    final successMessage = meta?.successMessage;
    if (successMessage == null || successMessage.isEmpty) return;

    final effectiveContext = context ?? _context;
    if (effectiveContext == null) return;

    unawaited(
      showSnackBar(context: effectiveContext, type: SnackBarType.info, message: successMessage, withIcon: true),
    );
  }

  @override
  void onMutationSuccess(MutationSnapshot<dynamic, dynamic> snapshot, MutationMeta? meta, BuildContext? context) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;

    final successMessage = meta?.successMessage;
    if (successMessage == null || successMessage.isEmpty) return;

    final effectiveContext = context ?? _context;
    if (effectiveContext == null) return;

    unawaited(
      showSnackBar(context: effectiveContext, type: SnackBarType.info, message: successMessage, withIcon: true),
    );
  }
}
