import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/api/models/category_get_category_response.dart';
import 'package:ecommerce/api/models/get_categories_response.dart';
import 'package:injectable/injectable.dart';

/// Service for category-related operations.
///
/// This service handles all category API calls including:
/// - Getting the category tree (hierarchical structure)
/// - Getting a single category by ID
@singleton
class CategoryService {
  final ApiClient _apiClient;

  CategoryService(this._apiClient);

  /// Gets the category tree (hierarchical structure).
  ///
  /// Returns a list of categories with their parent-child relationships.
  Future<List<GetCategoriesResponse>> getCategoryTree() async {
    return await _apiClient.category.getCategories();
  }

  /// Gets a single category by ID.
  ///
  /// Returns the category details including name, slug, description, etc.
  Future<CategoryGetCategoryResponse> getCategoryById(String id) async {
    return await _apiClient.category.getCategoriesId(id: id);
  }
}
