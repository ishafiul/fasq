import 'package:flutter/widgets.dart';

import '../core/mutation_meta.dart';
import '../core/mutation_snapshot.dart';
import '../core/query_client_observer.dart';
import '../core/query_meta.dart';
import '../core/query_snapshot.dart';

class FasqLogger implements QueryClientObserver {
  final bool enabled;
  final bool showData;
  final int truncateLength;

  final Map<Object, DateTime> _queryStartTimes = {};
  final Map<Object, DateTime> _mutationStartTimes = {};

  FasqLogger({
    this.enabled = true,
    this.showData = false,
    this.truncateLength = 100,
  });

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

  @override
  void onQueryLoading(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    if (!enabled) return;

    _queryStartTimes[snapshot.queryKey] = DateTime.now();

    final message = '⏳ [Fetch] ${snapshot.queryKey.toString()}';
    print(message);
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
        '✅ [Success] ${snapshot.queryKey.toString()} $durationString$dataLog';
    print(logMessage);
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
    print(logMessage);
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
    print(message);
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
    print(logMessage);
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
    print(logMessage);
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
}
