import 'package:ecommerce/api/models/cart_response.dart';
import 'package:ecommerce/api/models/category_response.dart';
import 'package:ecommerce/api/models/category_tree_node.dart';
import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/api/models/product_list_products_response.dart';
import 'package:ecommerce/api/models/product_response.dart';
import 'package:ecommerce/api/models/promotional_content_response.dart';
import 'package:ecommerce/api/models/review_get_product_reviews_response.dart';
import 'package:ecommerce/api/models/vendor_get_vendor_response.dart';
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

  /// Query key for product detail with variants and images.
  static TypedQueryKey<ProductDetailResponse> productDetail(String id) =>
      TypedQueryKey<ProductDetailResponse>('product:detail:$id', ProductDetailResponse);

  /// Query key for featured products.
  static TypedQueryKey<List<PromotionalContentResponse>> get featuredProducts =>
      const TypedQueryKey<List<PromotionalContentResponse>>(
        'promotional:featured',
        List<PromotionalContentResponse>,
      );

  /// Query key for top products.
  static TypedQueryKey<List<PromotionalContentResponse>> get topProducts =>
      const TypedQueryKey<List<PromotionalContentResponse>>(
        'promotional:top-products',
        List<PromotionalContentResponse>,
      );

  /// Query key for best deals.
  static TypedQueryKey<List<PromotionalContentResponse>> get bestDeals =>
      const TypedQueryKey<List<PromotionalContentResponse>>(
        'promotional:best-deals',
        List<PromotionalContentResponse>,
      );

  /// Query key for current offers.
  static TypedQueryKey<List<PromotionalContentResponse>> get currentOffers =>
      const TypedQueryKey<List<PromotionalContentResponse>>(
        'promotional:current-offers',
        List<PromotionalContentResponse>,
      );

  // Categories
  /// Query key for category tree.
  static TypedQueryKey<List<CategoryTreeNode>> get categoryTree => const TypedQueryKey<List<CategoryTreeNode>>(
        'categories:tree',
        List<CategoryTreeNode>,
      );

  /// Query key for a single category by ID.
  static TypedQueryKey<CategoryResponse> category(String id) =>
      TypedQueryKey<CategoryResponse>('category:$id', CategoryResponse);

  /// Query key for category products with pagination.
  static TypedQueryKey<ProductListProductsResponse> categoryProducts(
    String categoryId, {
    int page = 1,
    int limit = 20,
  }) =>
      TypedQueryKey<ProductListProductsResponse>(
        'category:products:$categoryId:$page:$limit',
        ProductListProductsResponse,
      );

  /// Query key for searching products in a category.
  static TypedQueryKey<ProductListProductsResponse> categoryProductSearch(
    String categoryId,
    String search, {
    int limit = 10,
  }) =>
      TypedQueryKey<ProductListProductsResponse>(
        'category:products:search:$categoryId:$search:$limit',
        ProductListProductsResponse,
      );

  // Vendors
  /// Query key for a single vendor by ID.
  static TypedQueryKey<VendorGetVendorResponse> vendor(String id) =>
      TypedQueryKey<VendorGetVendorResponse>('vendor:$id', VendorGetVendorResponse);

  /// Query key for vendor products with pagination.
  static TypedQueryKey<ProductListProductsResponse> vendorProducts(
    String vendorId, {
    int page = 1,
    int limit = 20,
  }) =>
      TypedQueryKey<ProductListProductsResponse>(
        'vendor:products:$vendorId:$page:$limit',
        ProductListProductsResponse,
      );

  // Reviews
  /// Query key for product reviews with pagination.
  static TypedQueryKey<ReviewGetProductReviewsResponse> productReviews(
    String productId, {
    int page = 1,
    int limit = 20,
  }) =>
      TypedQueryKey<ReviewGetProductReviewsResponse>(
        'reviews:product:$productId:$page:$limit',
        ReviewGetProductReviewsResponse,
      );

  // User
  /// Query key for user email.
  static TypedQueryKey<String?> get userEmail => const TypedQueryKey<String?>('user:email', String);

  /// Query key for user login status.
  static TypedQueryKey<bool> get isLoggedIn => const TypedQueryKey<bool>('user:isLoggedIn', bool);

  // Cart
  /// Query key for the current cart.
  static TypedQueryKey<CartResponse> get cart => const TypedQueryKey<CartResponse>('cart', CartResponse);
}
