import 'query_key.dart';

class TypedQueryKey<T> extends QueryKey {
  final String _key;
  final Type _type;

  const TypedQueryKey(this._key, this._type);

  @override
  String get key => _key;

  Type get type => _type;

  TypedQueryKey<T> withParam(String param) =>
      TypedQueryKey<T>('$_key:$param', _type);

  TypedQueryKey<T> withParams(List<String> params) =>
      TypedQueryKey<T>('$_key:${params.join(":")}', _type);
}
