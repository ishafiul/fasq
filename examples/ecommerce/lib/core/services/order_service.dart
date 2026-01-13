import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/api/models/order_get_user_orders_response.dart';
import 'package:injectable/injectable.dart';

@singleton
class OrderService {
  final ApiClient _apiClient;

  OrderService(this._apiClient);

  Future<OrderGetUserOrdersResponse> getUserOrders({
    int page = 1,
    int limit = 20,
  }) async {
    return await _apiClient.order.getOrders(page: page, limit: limit);
  }
}
