import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';

/// A synchronous logical transformation committed as one durable transaction.
typedef DurableOutboxTransaction =
    OutboxSnapshot Function(
      OutboxSnapshot current,
    );

/// Versioned durable storage boundary for offline mutation work.
abstract class DurableOutboxStore {
  /// Opens, validates, and recovers the store without clearing evidence.
  Future<OutboxSnapshot> open();

  /// Returns the last snapshot acknowledged by this store.
  OutboxSnapshot get snapshot;

  /// Monotonically increasing generation committed by the store.
  int get generation;

  /// Commits [transaction] and acknowledges only after durable replacement.
  Future<OutboxSnapshot> transact(
    DurableOutboxTransaction transaction, {
    int? expectedGeneration,
  });

  /// Releases ownership and closes the store.
  Future<void> close();
}
