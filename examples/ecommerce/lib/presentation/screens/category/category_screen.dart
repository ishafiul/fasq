import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/product_list_products_response.dart';
import 'package:ecommerce/api/models/product_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/category_service.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/widgets/no_data.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/core/widgets/spinner/rotating_dots.dart';
import 'package:ecommerce/core/widgets/type_ahead/type_ahead.dart';
import 'package:ecommerce/presentation/widget/category/category_info_card.dart';
import 'package:ecommerce/presentation/widget/product/product_grid.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

@RoutePage()
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.id,
  });

  final String id;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  final List<ProductResponse> _accumulatedProducts = [];
  bool _hasMorePages = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(CategoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) {
      _resetPagination();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMorePages) return;

    setState(() {
      _isLoadingMore = true;
    });

    final nextPage = _currentPage + 1;

    try {
      final response = await locator.get<ProductService>().getProducts(
            categoryId: widget.id,
            page: nextPage,
            limit: 20,
          );

      if (!mounted) return;

      final queryClient = context.queryClient;
      if (queryClient != null) {
        final queryKey = QueryKeys.categoryProducts(widget.id, page: nextPage, limit: 20);
        queryClient.setQueryData(queryKey, response);
      }

      setState(() {
        _accumulatedProducts.addAll(response.data);
        _currentPage = nextPage;
        _hasMorePages = response.meta.hasNextPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _resetPagination() {
    setState(() {
      _currentPage = 1;
      _accumulatedProducts.clear();
      _hasMorePages = true;
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      body: Shimmer(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              title: QueryBuilder(
                queryKey: QueryKeys.category(widget.id),
                queryFn: () => locator.get<CategoryService>().getCategoryById(widget.id),
                builder: (context, categoryState) {
                  if (categoryState.data != null) {
                    return Text(categoryState.data!.name);
                  }
                  return const Text('Category');
                },
              ),
              floating: true,
              snap: true,
            ),
            SliverPadding(
              padding: EdgeInsets.all(spacing.sm),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  QueryBuilder(
                    queryKey: QueryKeys.category(widget.id),
                    queryFn: () => locator.get<CategoryService>().getCategoryById(widget.id),
                    options: QueryOptions(
                      staleTime: const Duration(minutes: 5),
                      cacheTime: const Duration(minutes: 30),
                    ),
                    builder: (context, categoryState) {
                      if (categoryState.isLoading && categoryState.data == null) {
                        return ShimmerLoading(
                          isLoading: true,
                          child: CategoryInfoCard(category: null),
                        );
                      }

                      if (categoryState.hasError && categoryState.data == null) {
                        return Center(
                          child: Column(
                            children: [
                              const NoData(message: 'Failed to load category information'),
                              SizedBox(height: spacing.md),
                              ElevatedButton(
                                onPressed: () {
                                  final queryClient = context.queryClient;
                                  if (queryClient != null) {
                                    queryClient.invalidateQuery(QueryKeys.category(widget.id));
                                  }
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      final category = categoryState.data;
                      if (category == null) {
                        return const Center(child: NoData(message: 'Category not found'));
                      }

                      return CategoryInfoCard(category: category);
                    },
                  ),
                  SizedBox(height: spacing.md),
                  // Product search within category
                  _CategoryProductSearch(categoryId: widget.id),
                  SizedBox(height: spacing.md),
                  _CategoryProductsSection(
                    categoryId: widget.id,
                    accumulatedProducts: _accumulatedProducts,
                    hasMorePages: _hasMorePages,
                    isLoadingMore: _isLoadingMore,
                    onLoadMore: _loadNextPage,
                    onReset: _resetPagination,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search widget for finding products within how category.
class _CategoryProductSearch extends StatelessWidget {
  const _CategoryProductSearch({
    required this.categoryId,
  });

  final String categoryId;

  Future<List<ProductResponse>> _searchProducts(String pattern) async {
    if (pattern.isEmpty) {
      return [];
    }

    final response = await locator.get<ProductService>().getProducts(
          categoryId: categoryId,
          search: pattern,
          limit: 10,
        );

    return response.data;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final radius = context.radius;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: spacing.sm),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(radius.sm),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TypeAhead<ProductResponse>(
        suggestionsCallback: _searchProducts,
        debounceDuration: const Duration(milliseconds: 400),
        minCharsForSuggestions: 2,
        placeholder: 'Search products in this category...',
        hideOnEmpty: false,
        suggestionsBoxMaxHeight: 350,
        itemBuilder: (
          BuildContext itemContext,
          ProductResponse product,
        ) {
          final images = product.images;
          final hasImages = images.isNotEmpty;
          final imageUrl = hasImages ? images.first.url : null;

          return Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              leading: hasImages && imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        imageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 40,
                            height: 40,
                            color: palette.surface,
                            child: Icon(
                              Icons.image_not_supported,
                              size: 20,
                              color: palette.weak,
                            ),
                          );
                        },
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      color: palette.surface,
                      child: Icon(
                        Icons.shopping_bag,
                        size: 20,
                        color: palette.weak,
                      ),
                    ),
              title: Text(
                product.name,
                style: typography.bodyMedium.toTextStyle(
                  color: palette.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '\$${product.basePrice}',
                style: typography.bodySmall.toTextStyle(
                  color: palette.brand,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: palette.weak,
              ),
            ),
          );
        },
        onSelected: (ProductResponse product) {
          context.router.push(ProductDetailRoute(id: product.id));
        },
        loadingBuilder: (context) {
          return Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Center(
              child: WaveDots(color: palette.brand, size: spacing.xl),
            ),
          );
        },
        emptyBuilder: (context) {
          return SizedBox(
            height: 200,
            child: NoData(message: 'No products found'),
          );
        },
        errorBuilder: (context, error) {
          return Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Text(
              'Search failed',
              style: typography.bodyMedium.toTextStyle(
                color: palette.danger,
              ),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }
}

class _CategoryProductsSection extends StatefulWidget {
  const _CategoryProductsSection({
    required this.categoryId,
    required this.accumulatedProducts,
    required this.hasMorePages,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onReset,
  });

  final String categoryId;
  final List<ProductResponse> accumulatedProducts;
  final bool hasMorePages;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final VoidCallback onReset;

  @override
  State<_CategoryProductsSection> createState() => _CategoryProductsSectionState();
}

class _CategoryProductsSectionState extends State<_CategoryProductsSection> {
  String? _previousCategoryId;
  bool _firstPageHasNextPage = false;

  @override
  void didUpdateWidget(_CategoryProductsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categoryId != _previousCategoryId) {
      _previousCategoryId = widget.categoryId;
      widget.onReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final palette = context.palette;
    final typography = context.typography;

    return QueryBuilder<ProductListProductsResponse>(
      queryKey: QueryKeys.categoryProducts(widget.categoryId, page: 1, limit: 20),
      queryFn: () => locator.get<ProductService>().getProducts(
            categoryId: widget.categoryId,
            page: 1,
            limit: 20,
          ),
      options: QueryOptions(
        staleTime: const Duration(minutes: 2),
        cacheTime: const Duration(minutes: 10),
      ),
      builder: (context, state) {
        if (state.isLoading && state.data == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                child: Text(
                  'Products',
                  style: typography.titleMedium.toTextStyle(color: palette.textPrimary),
                ),
              ),
              SizedBox(height: spacing.sm),
              ProductGrid(
                products: [],
                isLoading: true,
                onProductTap: (product) {
                  if (product != null) {
                    context.router.push(ProductDetailRoute(id: product.id));
                  }
                },
              ),
            ],
          );
        }

        if (state.hasError && state.data == null) {
          return Center(
            child: Column(
              children: [
                const NoData(message: 'Failed to load products'),
                SizedBox(height: spacing.md),
                ElevatedButton(
                  onPressed: () {
                    final queryClient = context.queryClient;
                    if (queryClient != null) {
                      queryClient.invalidateQuery(QueryKeys.categoryProducts(widget.categoryId, page: 1));
                      widget.onReset();
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final response = state.data;
        if (response == null) {
          return const Center(child: NoData(message: 'No products available'));
        }

        _firstPageHasNextPage = response.meta.hasNextPage;
        _previousCategoryId = widget.categoryId;

        final firstPageProducts = response.data;
        final allProducts = [
          ...firstPageProducts,
          ...widget.accumulatedProducts,
        ];

        if (allProducts.isEmpty) {
          return const Center(
            child: NoData(message: 'No products available in this category'),
          );
        }

        final shouldShowLoadMore = (_firstPageHasNextPage && widget.accumulatedProducts.isEmpty) || widget.hasMorePages;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.sm),
              child: Text(
                'Products',
                style: typography.titleMedium.toTextStyle(color: palette.textPrimary),
              ),
            ),
            SizedBox(height: spacing.sm),
            ProductGrid(
              products: allProducts,
              isLoading: false,
              onProductTap: (product) {
                if (product != null) {
                  context.router.push(ProductDetailRoute(id: product.id));
                }
              },
            ),
            if (widget.isLoadingMore)
              Padding(
                padding: EdgeInsets.all(spacing.md),
                child: const Center(
                  child: CircularProgressSpinner(),
                ),
              )
            else if (shouldShowLoadMore && !widget.isLoadingMore)
              Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Center(
                  child: ElevatedButton(
                    onPressed: widget.onLoadMore,
                    child: const Text('Load More'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
