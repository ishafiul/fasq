import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';
import '../query_keys.dart';

class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({super.key});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Category Products',
      description:
          'Demonstrates dependent queries - fetch categories first, then products based on selected category. Products query is enabled only when a category is selected.',
      codeSnippet: '''
// Categories query (independent)
final categoriesQuery = QueryClient().getQuery<List<Category>>(
  QueryKeys.categories,
  () => api.fetchCategories(),
);

// Products query (dependent on category selection)
final productsQuery = QueryClient().getQuery<List<Product>>(
  QueryKeys.productsByCategory(\$_selectedCategoryId!),
  () => api.fetchProducts(\$_selectedCategoryId!),
  options: QueryOptions(
    enabled: \$_selectedCategoryId != null,
  ),
);

// Categories query starts automatically
// Products query only runs when category is selected
''',
      child: Column(
        children: [
          _buildCategoriesSection(),
          const SizedBox(height: 16),
          _buildProductsSection(),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return QueryBuilder<List<Category>>(
      queryKey: QueryKeys.categories,
      queryFn: () => ApiService.fetchCategories(),
      builder: (context, state) {
        if (state.isLoading) {
          return _buildLoadingCard('Loading categories...');
        }

        if (state.hasError) {
          return _buildErrorCard(state.error.toString());
        }

        if (state.hasData) {
          return _buildCategoriesList(state.data!);
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildCategoriesList(List<Category> categories) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.category,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Categories',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) {
              final isSelected = _selectedCategoryId == category.id;
              return FilterChip(
                label: Text(category.name),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedCategoryId = isSelected ? null : category.id;
                  });
                },
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
    if (_selectedCategoryId == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.touch_app,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Select a category to view products',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return QueryBuilder<List<Product>>(
      key: ValueKey('products:$_selectedCategoryId'),
      queryKey: QueryKeys.productsByCategory(_selectedCategoryId!),
      queryFn: () => ApiService.fetchProducts(_selectedCategoryId!),
      options: QueryOptions(
        enabled: _selectedCategoryId != null,
      ),
      builder: (context, state) {
        if (state.isLoading) {
          return _buildLoadingCard('Loading products...');
        }

        if (state.hasError) {
          return _buildErrorCard(state.error.toString());
        }

        if (state.hasData) {
          return _buildProductsList(state.data!);
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildProductsList(List<Product> products) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_cart,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Products (${products.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: products.map((product) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
