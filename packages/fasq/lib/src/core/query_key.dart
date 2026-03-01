import 'package:meta/meta.dart';

/// Base type for stable query identifiers used by the cache/client registry.
@immutable
abstract class QueryKey {
  /// Creates a query key.
  const QueryKey();

  /// Canonical string representation of this key.
  String get key;

  @override
  String toString() => key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryKey && runtimeType == other.runtimeType && key == other.key;

  @override
  int get hashCode => key.hashCode;
}

/// Query key backed by a plain string value.
class StringQueryKey extends QueryKey {
  /// Creates a string-backed query key.
  const StringQueryKey(this._key);

  final String _key;

  @override
  String get key => _key;
}

/// Converts strings to [QueryKey] instances.
extension StringQueryKeyExtension on String {
  /// Returns this string as a [QueryKey].
  QueryKey toQueryKey() => StringQueryKey(this);
}
