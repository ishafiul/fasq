import 'package:ecommerce/api/models/product_list_products_response.dart';
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
  static TypedQueryKey<dynamic> product(String id) => TypedQueryKey<dynamic>('product:$id', dynamic);

  /// Query key for featured products.
  static const TypedQueryKey<List<dynamic>> featuredProducts = TypedQueryKey<List<dynamic>>(
    'promotional:featured',
    List<dynamic>,
  );

  /// Query key for top products.
  static const TypedQueryKey<List<dynamic>> topProducts = TypedQueryKey<List<dynamic>>(
    'promotional:top-products',
    List<dynamic>,
  );

  /// Query key for best deals.
  static const TypedQueryKey<List<dynamic>> bestDeals = TypedQueryKey<List<dynamic>>(
    'promotional:best-deals',
    List<dynamic>,
  );

  /// Query key for current offers.
  static const TypedQueryKey<List<dynamic>> currentOffers = TypedQueryKey<List<dynamic>>(
    'promotional:current-offers',
    List<dynamic>,
  );

  // Categories
  /// Query key for category tree.
  static const TypedQueryKey<List<dynamic>> categoryTree = TypedQueryKey<List<dynamic>>(
    'categories:tree',
    List<dynamic>,
  );

  /// Query key for a single category by ID.
  static TypedQueryKey<dynamic> category(String id) => TypedQueryKey<dynamic>('category:$id', dynamic);

  // User
  /// Query key for user email.
  static TypedQueryKey<String?> get userEmail => const TypedQueryKey<String?>('user:email', String);

  /// Query key for user login status.
  static TypedQueryKey<bool> get isLoggedIn => const TypedQueryKey<bool>('user:isLoggedIn', bool);
}
