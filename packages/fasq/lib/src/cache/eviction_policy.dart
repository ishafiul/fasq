/// Policy for selecting which cache entries to evict when memory limit is reached.
///
/// Different policies optimize for different access patterns:
/// - [lru] - Best for general use (default)
/// - [lfu] - Best when some data is frequently reused
/// - [fifo] - Simplest, evicts oldest data
enum EvictionPolicy {
  /// Least Recently Used - evicts entries that haven't been accessed recently.
  ///
  /// Best for general use where recent data is more likely needed again.
  lru,

  /// Least Frequently Used - evicts entries that are rarely accessed.
  ///
  /// Best when some data is frequently reused while other data is one-off.
  lfu,

  /// First In First Out - evicts oldest entries.
  ///
  /// Simplest policy but least intelligent about access patterns.
  fifo,
}
