import 'package:ecommerce/core/services/fasq_logger_service.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

/// QueryClientObserver that logs FASQ events using FasqLoggerService.
///
/// Integrates FASQ query lifecycle events with the application's logging system.
@singleton
class FasqQueryObserver implements QueryClientObserver {
  final FasqLoggerService _logger;

  FasqQueryObserver(this._logger);

  @override
  void onQueryLoading(QuerySnapshot snapshot, QueryMeta? meta, BuildContext? context) {
    final queryKey = snapshot.queryKey.key;
    _logger.logQueryFetch(queryKey);
  }

  @override
  void onQuerySuccess(QuerySnapshot snapshot, QueryMeta? meta, BuildContext? context) {
    final queryKey = snapshot.queryKey.key;
    // Note: Duration would need to be extracted from meta if available
    _logger.logQuerySuccess(queryKey);
  }

  @override
  void onQueryError(QuerySnapshot snapshot, QueryMeta? meta, BuildContext? context) {
    final queryKey = snapshot.queryKey.key;
    final state = snapshot.currentState;
    if (state.hasError) {
      _logger.logQueryError(
        queryKey,
        state.error ?? 'Unknown error',
        state.stackTrace,
      );
    }
  }

  @override
  void onQuerySettled(QuerySnapshot snapshot, QueryMeta? meta, BuildContext? context) {
    // Query settled - no specific logging needed
  }

  @override
  void onMutationLoading(MutationSnapshot snapshot, MutationMeta? meta, BuildContext? context) {
    // Mutation events - can be logged if needed
  }

  @override
  void onMutationSuccess(MutationSnapshot snapshot, MutationMeta? meta, BuildContext? context) {
    // Mutation events - can be logged if needed
  }

  @override
  void onMutationError(MutationSnapshot snapshot, MutationMeta? meta, BuildContext? context) {
    // Mutation events - can be logged if needed
  }

  @override
  void onMutationSettled(MutationSnapshot snapshot, MutationMeta? meta, BuildContext? context) {
    // Mutation events - can be logged if needed
  }
}

