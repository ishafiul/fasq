import 'dart:developer' as developer;

import 'package:fasq/src/client/query_client_observer.dart';
import 'package:fasq/src/mutation/mutation_meta.dart';
import 'package:fasq/src/mutation/mutation_snapshot.dart';
import 'package:fasq/src/observability/error/error_context.dart';
import 'package:fasq/src/observability/error/error_reporter.dart';
import 'package:fasq/src/observability/logging/fasq_logger.dart';
import 'package:fasq/src/query/query_meta.dart';
import 'package:fasq/src/query/query_snapshot.dart';
import 'package:flutter/widgets.dart';

/// Encapsulates observer and error reporter dispatch for `QueryClient`.
final class QueryClientEvents {
  final List<QueryClientObserver> _observers = <QueryClientObserver>[];
  final List<FasqErrorReporter> _errorReporters = <FasqErrorReporter>[];

  /// Registers an observer for query/mutation lifecycle notifications.
  void addObserver(QueryClientObserver observer) {
    if (_observers.contains(observer)) {
      return;
    }
    _observers.add(observer);
  }

  /// Unregisters a previously added observer.
  void removeObserver(QueryClientObserver observer) {
    _observers.remove(observer);
  }

  /// Removes all registered observers.
  void clearObservers() {
    _observers.clear();
  }

  /// Registers an error reporter.
  void addErrorReporter(FasqErrorReporter reporter) {
    if (_errorReporters.contains(reporter)) {
      return;
    }
    _errorReporters.add(reporter);
  }

  /// Unregisters an error reporter.
  void removeErrorReporter(FasqErrorReporter reporter) {
    _errorReporters.remove(reporter);
  }

  /// Dispatches an error context to all registered error reporters.
  void dispatchError(FasqErrorContext context) {
    for (final reporter in _errorReporters) {
      try {
        reporter(context);
      } on Object catch (_, stackTrace) {
        _logReporterError(
          Exception('FasqErrorReporter failed: ${reporter.runtimeType}'),
          stackTrace,
        );
      }
    }
  }

  /// Notifies observers that a mutation entered the loading state.
  void notifyMutationLoading(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onMutationLoading(snapshot, meta, context);
    }
  }

  /// Notifies observers that a mutation completed successfully.
  void notifyMutationSuccess(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onMutationSuccess(snapshot, meta, context);
    }
  }

  /// Notifies observers that a mutation failed.
  void notifyMutationError(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onMutationError(snapshot, meta, context);
    }
  }

  /// Notifies observers that a mutation has settled.
  void notifyMutationSettled(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onMutationSettled(snapshot, meta, context);
    }
  }

  /// Notifies observers that a query entered the loading state.
  void notifyQueryLoading(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onQueryLoading(snapshot, meta, context);
    }
  }

  /// Notifies observers that a query completed successfully.
  void notifyQuerySuccess(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onQuerySuccess(snapshot, meta, context);
    }
  }

  /// Notifies observers that a query failed.
  void notifyQueryError(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onQueryError(snapshot, meta, context);
    }
  }

  /// Notifies observers that a query has settled.
  void notifyQuerySettled(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onQuerySettled(snapshot, meta, context);
    }
  }

  void _logReporterError(Object error, StackTrace stackTrace) {
    for (final observer in _observers) {
      if (observer is FasqLogger) {
        observer.logError(error, stackTrace);
        return;
      }
    }

    developer.log(
      'Error in FasqErrorReporter: $error',
      name: 'fasq.query_client',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
