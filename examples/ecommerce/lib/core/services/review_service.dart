import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/api/models/review_get_product_reviews_response.dart';
import 'package:injectable/injectable.dart';

/// Service for review-related operations.
///
/// This service handles all review API calls including:
/// - Getting product reviews with pagination
@singleton
class ReviewService {
  final ApiClient _apiClient;

  ReviewService(this._apiClient);

  /// Gets product reviews with pagination.
  ///
  /// Parameters:
  /// - [productId] - The product ID to get reviews for
  /// - [page] - Page number (default: 1)
  /// - [limit] - Items per page (default: 20)
  ///
  /// Returns reviews with rating summary and pagination metadata.
  Future<ReviewGetProductReviewsResponse> getProductReviews(
    String productId, {
    int page = 1,
    int limit = 20,
  }) async {
    return await _apiClient.review.getProductsProductIdReviews(
      productId: productId,
      page: page,
      limit: limit,
    );
  }
}
