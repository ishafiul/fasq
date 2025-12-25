import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/api/models/promotional_content_response.dart';
import 'package:injectable/injectable.dart';

/// Service for promotional content operations.
///
/// This service handles all promotional API calls including:
/// - Featured products
/// - Top products
/// - Best deals
/// - Current offers
@singleton
class PromotionalService {
  final ApiClient _apiClient;

  PromotionalService(this._apiClient);

  /// Gets featured products.
  ///
  /// Returns a list of products marked as featured.
  Future<List<PromotionalContentResponse>> getFeaturedProducts() async {
    return await _apiClient.promotional.getPromotionalFeatured();
  }

  /// Gets top products.
  ///
  /// Returns a list of top-selling or popular products.
  Future<List<PromotionalContentResponse>> getTopProducts() async {
    return await _apiClient.promotional.getPromotionalTopProducts();
  }

  /// Gets best deals.
  ///
  /// Returns a list of products with the best discounts or deals.
  Future<List<PromotionalContentResponse>> getBestDeals() async {
    return await _apiClient.promotional.getPromotionalBestDeals();
  }

  /// Gets current offers.
  ///
  /// Returns a list of active promotional offers.
  Future<List<PromotionalContentResponse>> getCurrentOffers() async {
    return await _apiClient.promotional.getPromotionalCurrentOffers();
  }
}
