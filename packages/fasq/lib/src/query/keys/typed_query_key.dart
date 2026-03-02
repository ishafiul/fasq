import 'package:fasq/src/query/keys/query_key.dart';

/// A [QueryKey] that carries an associated result type.
///
/// This helps keep query-key usage explicit when working with typed query
/// APIs.
class TypedQueryKey<T> extends QueryKey {
  /// Creates a typed query key from the base `key` string and `type`.
  const TypedQueryKey(this._key, this._type);

  final String _key;
  final Type _type;

  @override
  /// String representation of this query key.
  String get key => _key;

  /// Runtime type associated with this key.
  Type get type => _type;

  /// Returns a new key by appending a single [param].
  TypedQueryKey<T> withParam(String param) =>
      TypedQueryKey<T>('$_key:$param', _type);

  /// Returns a new key by appending all [params] in order.
  TypedQueryKey<T> withParams(List<String> params) =>
      TypedQueryKey<T>('$_key:${params.join(":")}', _type);
}
