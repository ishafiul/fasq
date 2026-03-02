import 'dart:developer' as developer;

import 'package:fasq/src/client/query_client_observer.dart';
import 'package:fasq/src/mutation/mutation_meta.dart';
import 'package:fasq/src/mutation/mutation_snapshot.dart';
import 'package:fasq/src/observability/error/error_context.dart';
import 'package:fasq/src/query/query_meta.dart';
import 'package:fasq/src/query/query_snapshot.dart';
import 'package:flutter/widgets.dart';

/// Logs query and mutation lifecycle events for debugging.
///
/// The logger can be attached as a [QueryClientObserver] to emit lifecycle
/// messages and structured error logs.
class FasqLogger implements QueryClientObserver {
  /// Creates a [FasqLogger].
  ///
  /// Set [enabled] to disable all logging, [showData] to include result data
  /// in success logs, and [truncateLength] to limit logged payload length.
  FasqLogger({
    this.enabled = true,
    this.showData = false,
    this.truncateLength = 100,
  });

  /// Whether this logger emits lifecycle and error logs.
  final bool enabled;

  /// Whether query and mutation data should be included in logs.
  final bool showData;

  /// Maximum number of characters to print from logged payload data.
  final int truncateLength;

  final Map<Object, DateTime> _queryStartTimes = {};
  final Map<Object, DateTime> _mutationStartTimes = {};

  String _formatLoggableData(dynamic data) {
    if (!showData) {
      return '';
    }

    if (data == null) {
      return '';
    }

    final dataString = data.toString();
    if (dataString.length > truncateLength) {
      return ' ${dataString.substring(0, truncateLength)}...';
    } else {
      return ' $dataString';
    }
  }

  void _logLifecycle(String message) {
    developer.log(
      message,
      name: 'Fasq',
    );
  }

  @override
  void onQueryLoading(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    if (!enabled) return;

    _queryStartTimes[snapshot.queryKey] = DateTime.now();

    final message = '⏳ [Fetch] ${snapshot.queryKey}';
    _logLifecycle(message);
  }

  @override
  void onQuerySuccess(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    if (!enabled) return;

    final startTime = _queryStartTimes.remove(snapshot.queryKey);
    if (startTime == null) return;

    final duration = DateTime.now().difference(startTime);
    final durationString = '(${duration.inMilliseconds}ms)';

    final dataLog = _formatLoggableData(snapshot.currentState.data);

    final logMessage =
        '✅ [Success] ${snapshot.queryKey} $durationString$dataLog';
    _logLifecycle(logMessage);
  }

  @override
  void onQueryError(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    if (!enabled) return;

    _queryStartTimes.remove(snapshot.queryKey);

    final queryKey = snapshot.queryKey.toString();
    final error = snapshot.currentState.error;
    final errorDetails = error?.toString() ?? 'Unknown error';

    final logMessage = '❌ [Error] $queryKey: $errorDetails';
    _logLifecycle(logMessage);
  }

  @override
  void onQuerySettled(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    if (!enabled) return;

    _queryStartTimes.remove(snapshot.queryKey);
  }

  @override
  void onMutationLoading(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    if (!enabled) return;

    final mutationKey = snapshot.variables?.toString() ?? 'mutation';
    _mutationStartTimes[mutationKey] = DateTime.now();

    final message = '🚀 [Mutation] $mutationKey';
    _logLifecycle(message);
  }

  @override
  void onMutationSuccess(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    if (!enabled) return;

    final mutationKey = snapshot.variables?.toString() ?? 'mutation';
    final startTime = _mutationStartTimes.remove(mutationKey);
    if (startTime == null) return;

    final duration = DateTime.now().difference(startTime);
    final durationString = '(${duration.inMilliseconds}ms)';

    final dataLog = _formatLoggableData(snapshot.currentState.data);

    final logMessage =
        '✅ [Mutation Success] $mutationKey $durationString$dataLog';
    _logLifecycle(logMessage);
  }

  @override
  void onMutationError(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    if (!enabled) return;

    final mutationKey = snapshot.variables?.toString() ?? 'mutation';
    _mutationStartTimes.remove(mutationKey);

    final error = snapshot.currentState.error;
    final errorDetails = error?.toString() ?? 'Unknown error';

    final logMessage = '❌ [Mutation Error] $mutationKey: $errorDetails';
    _logLifecycle(logMessage);
  }

  @override
  void onMutationSettled(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    if (!enabled) return;

    final mutationKey = snapshot.variables?.toString() ?? 'mutation';
    _mutationStartTimes.remove(mutationKey);
  }

  /// Logs an error with optional structured context.
  ///
  /// If [context] is provided, logs structured data including query key,
  /// retry count, network status, and sanitized query options. If [context]
  /// is null, logs a simple error message for backward compatibility.
  ///
  /// [error] - The error that occurred.
  /// [stackTrace] - Optional stack trace associated with the error.
  /// [context] - Optional error context with structured query metadata.
  ///
  /// Example:
  /// ```dart
  /// logger.logError(exception, stackTrace);
  /// // or with context:
  /// logger.logError(exception, stackTrace, errorContext);
  /// ```
  void logError(
    Object error, [
    StackTrace? stackTrace,
    FasqErrorContext? context,
  ]) {
    if (!enabled) return;

    if (context != null) {
      // Structured logging with context
      final structuredLog = <String, dynamic>{
        'message': 'Fasq Query Error',
        'errorType': error.runtimeType.toString(),
        'errorMessage': error.toString(),
        'queryKey': context.queryKey.map((e) => e.toString()).toList(),
        'retryCount': context.retryCount,
        'staleTimeMs': context.staleTime.inMilliseconds,
        'networkStatus': context.networkStatus ? 'online' : 'offline',
        'sanitizedQueryOptions': context.sanitizedQueryOptions,
      };

      // Use developer.log for structured output in Dart VM
      // Convert map to a readable string format
      final logString = _formatStructuredLog(structuredLog);
      developer.log(
        logString,
        name: 'Fasq',
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      // Backward compatible simple logging
      developer.log(
        'Fasq Error: $error',
        name: 'Fasq',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Formats a structured log map into a readable string.
  ///
  /// Converts the map to a key-value format that's easy to read in logs.
  String _formatStructuredLog(Map<String, dynamic> log) {
    final buffer = StringBuffer('Fasq Query Error:\n');
    for (final entry in log.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }
    return buffer.toString();
  }
}
