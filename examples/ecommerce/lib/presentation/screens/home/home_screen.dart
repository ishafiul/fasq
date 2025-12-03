import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/get_promotional_best_deals_response.dart';
import 'package:ecommerce/api/models/get_promotional_featured_response.dart';
import 'package:ecommerce/api/models/get_promotional_top_products_response.dart';
import 'package:ecommerce/api/models/product_list_products_response.dart';
import 'package:ecommerce/api/models/product_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/services/promotional_service.dart';
import 'package:ecommerce/core/widgets/pull_to_refresh.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/core/widgets/un_focus.dart';
import 'package:ecommerce/presentation/widget/category/category_section.dart';
import 'package:ecommerce/presentation/widget/home/home_app_bar.dart';
import 'package:ecommerce/presentation/widget/product/product_card.dart';
import 'package:ecommerce/presentation/widget/product/product_list.dart';
import 'package:ecommerce/presentation/widget/promotional/promotional_banner.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart' hide Badge;

@RoutePage()
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _searchQuery;

  Future<void> _handleRefresh() async {
    final queryClient = context.queryClient;
    if (queryClient == null) return;

    // Invalidate all product-related queries
    queryClient.invalidateQuery(QueryKeys.featuredProducts);
    queryClient.invalidateQuery(QueryKeys.topProducts);
    queryClient.invalidateQuery(QueryKeys.bestDeals);
    queryClient.invalidateQuery(QueryKeys.currentOffers);
    queryClient.invalidateQuery(QueryKeys.categoryTree);
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      queryClient.invalidateQuery(QueryKeys.products(search: _searchQuery));
    }
    queryClient.invalidateQuery(QueryKeys.products());
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value.isEmpty ? null : value;
    });
  }

  void _handleSearchSubmitted(String value) {
    setState(() {
      _searchQuery = value.isEmpty ? null : value;
    });
    // Invalidate and refetch products with search query
    final queryClient = context.queryClient;
    if (queryClient != null) {
      queryClient.invalidateQuery(QueryKeys.products(search: value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Unfocus(
      child: Shimmer(
        child: Scaffold(
          appBar: HomeAppBar(onSearchChanged: _handleSearchChanged, onSearchSubmitted: _handleSearchSubmitted),
          body: PullToRefresh(
            onRefresh: _handleRefresh,
            child: CustomScrollView(
              slivers: [
                // Promotional Banner
                const SliverToBoxAdapter(child: PromotionalBanner()),
                SliverToBoxAdapter(child: SizedBox(height: spacing.md)),
                // Category Section
                const SliverToBoxAdapter(child: CategorySection()),
                SliverToBoxAdapter(child: SizedBox(height: spacing.md)),
                // Featured Products
                const SliverToBoxAdapter(child: _FeaturedProductsSection()),
                // Best Deals
                const SliverToBoxAdapter(child: _BestDealsSection()),
                // Top Products
                const SliverToBoxAdapter(child: _TopProductsSection()),
                // All Products
                SliverToBoxAdapter(child: _AllProductsSection(searchQuery: _searchQuery)),
                SliverToBoxAdapter(child: SizedBox(height: spacing.xxl)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedProductsSection extends StatelessWidget {
  const _FeaturedProductsSection();

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<List<GetPromotionalFeaturedResponse>>(
      queryKey: QueryKeys.featuredProducts,
      queryFn: () => locator.get<PromotionalService>().getFeaturedProducts(),
      options: QueryOptions(staleTime: const Duration(minutes: 5), cacheTime: const Duration(minutes: 30)),
      builder: (context, state) {
        if (state.hasError) {
          return const SizedBox.shrink();
        }

        final promotionalItems = state.data ?? [];
        final isLoading = state.isLoading;

        // Extract products from all promotional content items
        final allProducts = <ProductResponse>[];
        if (promotionalItems.isNotEmpty) {
          for (final item in promotionalItems) {
            final products = item.products;
            if (products.isNotEmpty) {
              allProducts.addAll(products);
            }
          }
        }

        if (!isLoading && allProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return _HorizontalProductSection(
          title: 'Featured Products',
          products: isLoading ? [] : allProducts,
          isLoading: isLoading,
          onProductTap: (product) {
            if (product != null) {
              context.router.push(ProductDetailRoute(id: product.id));
            }
          },
        );
      },
    );
  }
}

class _BestDealsSection extends StatelessWidget {
  const _BestDealsSection();

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<List<GetPromotionalBestDealsResponse>>(
      queryKey: QueryKeys.bestDeals,
      queryFn: () => locator.get<PromotionalService>().getBestDeals(),
      options: QueryOptions(staleTime: const Duration(minutes: 5), cacheTime: const Duration(minutes: 30)),
      builder: (context, state) {
        if (state.hasError) {
          return const SizedBox.shrink();
        }

        final promotionalItems = state.data ?? [];
        final isLoading = state.isLoading;

        // Extract products from all promotional content items
        final allProducts = <ProductResponse>[];
        if (promotionalItems.isNotEmpty) {
          for (final item in promotionalItems) {
            final products = item.products;
            if (products.isNotEmpty) {
              allProducts.addAll(products);
            }
          }
        }

        if (!isLoading && allProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return _HorizontalProductSection(
          title: 'Best Deals',
          products: isLoading ? [] : allProducts,
          isLoading: isLoading,
          onProductTap: (product) {
            if (product != null) {
              context.router.push(ProductDetailRoute(id: product.id));
            }
          },
        );
      },
    );
  }
}

class _TopProductsSection extends StatelessWidget {
  const _TopProductsSection();

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<List<GetPromotionalTopProductsResponse>>(
      queryKey: QueryKeys.topProducts,
      queryFn: () => locator.get<PromotionalService>().getTopProducts(),
      options: QueryOptions(staleTime: const Duration(minutes: 5), cacheTime: const Duration(minutes: 30)),
      builder: (context, state) {
        if (state.hasError) {
          return const SizedBox.shrink();
        }

        final promotionalItems = state.data ?? [];
        final isLoading = state.isLoading;

        // Extract products from all promotional content items
        final allProducts = <ProductResponse>[];
        if (promotionalItems.isNotEmpty) {
          for (final item in promotionalItems) {
            final products = item.products;
            if (products.isNotEmpty) {
              allProducts.addAll(products);
            }
          }
        }

        if (!isLoading && allProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return _HorizontalProductSection(
          title: 'Top Products',
          products: isLoading ? [] : allProducts,
          isLoading: isLoading,
          onProductTap: (product) {
            if (product != null) {
              context.router.push(ProductDetailRoute(id: product.id));
            }
          },
        );
      },
    );
  }
}

class _HorizontalProductSection extends StatelessWidget {
  const _HorizontalProductSection({
    required this.title,
    required this.products,
    this.isLoading = false,
    this.onProductTap,
  });

  final String title;
  final List<ProductResponse> products;
  final bool isLoading;
  final ValueChanged<ProductResponse?>? onProductTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    if (!isLoading && products.isEmpty) {
      return const SizedBox.shrink();
    }

    final itemCount = isLoading ? 6 : products.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.sm),
          child: Text(
            title,
            style: typography.titleMedium.toTextStyle(color: palette.textPrimary),
          ),
        ),
        SizedBox(height: spacing.sm),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: spacing.sm),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final product = isLoading ? null : products[index];

              return ShimmerLoading(
                isLoading: isLoading,
                child: Padding(
                  padding: EdgeInsets.only(right: spacing.sm),
                  child: SizedBox(
                    width: 320,
                    child: ProductCardHorizontal(
                      product: product,
                      onTap: isLoading ? null : () => onProductTap?.call(product),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: spacing.md),
      ],
    );
  }
}

class _AllProductsSection extends StatelessWidget {
  const _AllProductsSection({this.searchQuery});

  final String? searchQuery;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    return QueryBuilder<ProductListProductsResponse>(
      queryKey: QueryKeys.products(search: searchQuery),
      queryFn: () => locator.get<ProductService>().getProducts(search: searchQuery, limit: 20),
      options: QueryOptions(staleTime: const Duration(minutes: 2), cacheTime: const Duration(minutes: 10)),
      builder: (context, state) {
        if (state.hasError) {
          return Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Center(
              child: Column(
                children: [
                  Text('Failed to load products', style: typography.bodySmall.toTextStyle(color: palette.danger)),
                  SizedBox(height: spacing.sm),
                  TextButton(
                    onPressed: () {
                      context.queryClient?.invalidateQuery(QueryKeys.products(search: searchQuery));
                    },
                    child: Text('Retry', style: typography.bodySmall.toTextStyle(color: palette.brand)),
                  ),
                ],
              ),
            ),
          );
        }

        final response = state.data;
        final products = response?.data ?? [];
        final isLoading = state.isLoading;

        if (!isLoading && products.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Center(
              child: Text(
                searchQuery != null ? 'No products found for "$searchQuery"' : 'No products available',
                style: typography.bodySmall.toTextStyle(color: palette.textSecondary),
              ),
            ),
          );
        }

        return ProductList(
          title: searchQuery != null ? 'Search Results' : 'All Products',
          products: isLoading ? [] : products,
          isLoading: isLoading,
          onProductTap: (product) {
            if (product != null) {
              context.router.push(ProductDetailRoute(id: product.id));
            }
          },
        );
      },
    );
  }
}
