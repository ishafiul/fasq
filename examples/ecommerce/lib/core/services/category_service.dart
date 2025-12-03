import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/api/models/category_response.dart';
import 'package:ecommerce/api/models/category_tree_node.dart';
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
  Future<List<CategoryTreeNode>> getCategoryTree() async {
    return await _apiClient.category.getCategories();
  }

  /// Gets a single category by ID.
  ///
  /// Returns the category details including name, slug, description, etc.
  Future<CategoryResponse> getCategoryById(String id) async {
    return await _apiClient.category.getCategoriesId(id: id);
  }
}
