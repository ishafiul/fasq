import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/api/models/get_promotional_best_deals_response.dart';
import 'package:ecommerce/api/models/get_promotional_current_offers_response.dart';
import 'package:ecommerce/api/models/get_promotional_featured_response.dart';
import 'package:ecommerce/api/models/get_promotional_top_products_response.dart';
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
  Future<List<GetPromotionalFeaturedResponse>> getFeaturedProducts() async {
    return await _apiClient.promotional.getPromotionalFeatured();
  }

  /// Gets top products.
  ///
  /// Returns a list of top-selling or popular products.
  Future<List<GetPromotionalTopProductsResponse>> getTopProducts() async {
    return await _apiClient.promotional.getPromotionalTopProducts();
  }

  /// Gets best deals.
  ///
  /// Returns a list of products with the best discounts or deals.
  Future<List<GetPromotionalBestDealsResponse>> getBestDeals() async {
    return await _apiClient.promotional.getPromotionalBestDeals();
  }

  /// Gets current offers.
  ///
  /// Returns a list of active promotional offers.
  Future<List<GetPromotionalCurrentOffersResponse>> getCurrentOffers() async {
    return await _apiClient.promotional.getPromotionalCurrentOffers();
  }
}
