abstract class QueryKey {
  const QueryKey();

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

class StringQueryKey extends QueryKey {
  final String _key;

  const StringQueryKey(this._key);

  @override
  String get key => _key;
}

extension StringQueryKeyExtension on String {
  QueryKey toQueryKey() => StringQueryKey(this);
}

