import 'package:ecommerce/api/models/category_get_category_response.dart';
import 'package:ecommerce/api/models/get_categories_response.dart';
import 'package:ecommerce/api/models/get_promotional_best_deals_response.dart';
import 'package:ecommerce/api/models/get_promotional_current_offers_response.dart';
import 'package:ecommerce/api/models/get_promotional_featured_response.dart';
import 'package:ecommerce/api/models/get_promotional_top_products_response.dart';
import 'package:ecommerce/api/models/product_list_products_response.dart';
import 'package:ecommerce/api/models/product_response.dart';
import 'package:fasq/fasq.dart';

/// Type-safe query keys for the application.
///
/// This class provides centralized query key definitions for all API queries.
/// All query keys use TypedQueryKey for type safety and better IDE support.
class QueryKeys {
  QueryKeys._();

  // Products
  /// Query key for product list with filters and pagination.
  static TypedQueryKey<ProductListProductsResponse> products({
    String? categoryId,
    String? vendorId,
    String? search,
    int page = 1,
    int limit = 20,
  }) =>
      TypedQueryKey<ProductListProductsResponse>(
        'products:${categoryId ?? 'all'}:${vendorId ?? 'all'}:${search ?? ''}:$page:$limit',
        ProductListProductsResponse,
      );

  /// Query key for a single product by ID.
  static TypedQueryKey<ProductResponse> product(String id) =>
      TypedQueryKey<ProductResponse>('product:$id', ProductResponse);

  /// Query key for featured products.
  static TypedQueryKey<List<GetPromotionalFeaturedResponse>> get featuredProducts =>
      const TypedQueryKey<List<GetPromotionalFeaturedResponse>>(
        'promotional:featured',
        List<GetPromotionalFeaturedResponse>,
      );

  /// Query key for top products.
  static TypedQueryKey<List<GetPromotionalTopProductsResponse>> get topProducts =>
      const TypedQueryKey<List<GetPromotionalTopProductsResponse>>(
        'promotional:top-products',
        List<GetPromotionalTopProductsResponse>,
      );

  /// Query key for best deals.
  static TypedQueryKey<List<GetPromotionalBestDealsResponse>> get bestDeals =>
      const TypedQueryKey<List<GetPromotionalBestDealsResponse>>(
        'promotional:best-deals',
        List<GetPromotionalBestDealsResponse>,
      );

  /// Query key for current offers.
  static TypedQueryKey<List<GetPromotionalCurrentOffersResponse>> get currentOffers =>
      const TypedQueryKey<List<GetPromotionalCurrentOffersResponse>>(
        'promotional:current-offers',
        List<GetPromotionalCurrentOffersResponse>,
      );

  // Categories
  /// Query key for category tree.
  static TypedQueryKey<List<GetCategoriesResponse>> get categoryTree =>
      const TypedQueryKey<List<GetCategoriesResponse>>(
        'categories:tree',
        List<GetCategoriesResponse>,
      );

  /// Query key for a single category by ID.
  static TypedQueryKey<CategoryGetCategoryResponse> category(String id) =>
      TypedQueryKey<CategoryGetCategoryResponse>('category:$id', CategoryGetCategoryResponse);

  // User
  /// Query key for user email.
  static TypedQueryKey<String?> get userEmail => const TypedQueryKey<String?>('user:email', String);

  /// Query key for user login status.
  static TypedQueryKey<bool> get isLoggedIn => const TypedQueryKey<bool>('user:isLoggedIn', bool);
}
