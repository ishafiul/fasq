import 'package:fasq/fasq.dart';

class QueryKeys {
  static TypedQueryKey<List<dynamic>> get products =>
      const TypedQueryKey<List<dynamic>>('products', List<dynamic>);

  static TypedQueryKey<dynamic> product(String id) =>
      TypedQueryKey<dynamic>('product:$id', dynamic);

  static TypedQueryKey<dynamic> user(String id) =>
      TypedQueryKey<dynamic>('user:$id', dynamic);

  static TypedQueryKey<List<dynamic>> ordersByUser(String userId) =>
      TypedQueryKey<List<dynamic>>('orders:user:$userId', List<dynamic>);
}

