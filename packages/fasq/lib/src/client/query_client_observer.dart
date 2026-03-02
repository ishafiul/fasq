import 'package:fasq/src/mutation/mutation_meta.dart';
import 'package:fasq/src/mutation/mutation_snapshot.dart';
import 'package:fasq/src/query/query_meta.dart';
import 'package:fasq/src/query/query_snapshot.dart';
import 'package:flutter/widgets.dart';

/// Observer hooks for query and mutation lifecycle events.
///
/// Subclass this type and override only the callbacks you need.
class QueryClientObserver {
  /// Called when a mutation transitions to loading.
  void onMutationLoading(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {}

  /// Called when a mutation completes successfully.
  void onMutationSuccess(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {}

  /// Called when a mutation completes with an error.
  void onMutationError(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {}

  /// Called when a mutation settles (success or error).
  void onMutationSettled(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {}

  /// Called when a query transitions to loading.
  void onQueryLoading(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {}

  /// Called when a query completes successfully.
  void onQuerySuccess(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {}

  /// Called when a query completes with an error.
  void onQueryError(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {}

  /// Called when a query settles (success or error).
  void onQuerySettled(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {}
}
