import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/api/models/product_list_products_response.dart';
import 'package:ecommerce/api/models/sort_by.dart';
import 'package:ecommerce/api/models/sort_order.dart';
import 'package:injectable/injectable.dart';

/// Service for product-related operations.
///
/// This service handles all product API calls including:
/// - Listing products with filters and pagination
/// - Getting product details by ID
@singleton
class ProductService {
  final ApiClient _apiClient;

  ProductService(this._apiClient);

  /// Gets a list of products with optional filters and pagination.
  ///
  /// Parameters:
  /// - [categoryId] - Filter by category ID
  /// - [vendorId] - Filter by vendor ID
  /// - [search] - Search query string
  /// - [page] - Page number (default: 1)
  /// - [limit] - Items per page (default: 20)
  /// - [minPrice] - Minimum price filter
  /// - [maxPrice] - Maximum price filter
  /// - [inStock] - Filter by stock availability
  /// - [status] - Filter by product status
  /// - [tags] - Filter by tags (comma-separated)
  /// - [sortBy] - Sort field (default: createdAt)
  /// - [sortOrder] - Sort order (default: desc)
  Future<ProductListProductsResponse> getProducts({
    String? categoryId,
    String? vendorId,
    String? search,
    int page = 1,
    int limit = 20,
    num? minPrice,
    num? maxPrice,
    bool? inStock,
    String? status,
    String? tags,
    SortBy? sortBy,
    SortOrder? sortOrder,
  }) async {
    return await _apiClient.product.getProducts(
      categoryId: categoryId,
      vendorId: vendorId,
      search: search,
      page: page,
      limit: limit,
      minPrice: minPrice,
      maxPrice: maxPrice,
      inStock: inStock,
      status: status,
      tags: tags,
      sortBy: sortBy ?? SortBy.createdAt,
      sortOrder: sortOrder ?? SortOrder.desc,
    );
  }

  /// Gets a single product by ID with variants and images.
  ///
  /// Returns the product with all its variants and images included.
  Future<ProductDetailResponse> getProductById(String id) async {
    return await _apiClient.product.getProductsId(id: id);
  }
}
