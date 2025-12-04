import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/product_list_products_response.dart';
import 'package:ecommerce/api/models/product_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/services/vendor_service.dart';
import 'package:ecommerce/core/widgets/no_data.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/presentation/widget/product/product_grid.dart';
import 'package:ecommerce/presentation/widget/vendor/vendor_info_card.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

@RoutePage()
class VendorScreen extends StatefulWidget {
  const VendorScreen({
    super.key,
    required this.id,
  });

  final String id;

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen> {
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
  void didUpdateWidget(VendorScreen oldWidget) {
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
            vendorId: widget.id,
            page: nextPage,
            limit: 20,
          );

      if (!mounted) return;

      final queryClient = context.queryClient;
      if (queryClient != null) {
        final queryKey = QueryKeys.vendorProducts(widget.id, page: nextPage, limit: 20);
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

    return Shimmer(
      child: Scaffold(
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              title: QueryBuilder(
                queryKey: QueryKeys.vendor(widget.id),
                queryFn: () => locator.get<VendorService>().getVendorById(widget.id),
                builder: (context, vendorState) {
                  if (vendorState.data != null) {
                    return Text(vendorState.data!.businessName);
                  }
                  return const Text('Vendor');
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
                    queryKey: QueryKeys.vendor(widget.id),
                    queryFn: () => locator.get<VendorService>().getVendorById(widget.id),
                    options: QueryOptions(
                      staleTime: const Duration(minutes: 5),
                      cacheTime: const Duration(minutes: 30),
                    ),
                    builder: (context, vendorState) {
                      if (vendorState.isLoading && vendorState.data == null) {
                        return ShimmerLoading(
                          isLoading: true,
                          child: _VendorInfoCardPlaceholder(),
                        );
                      }

                      if (vendorState.hasError && vendorState.data == null) {
                        return Center(
                          child: Column(
                            children: [
                              const NoData(message: 'Failed to load vendor information'),
                              SizedBox(height: spacing.md),
                              ElevatedButton(
                                onPressed: () {
                                  final queryClient = context.queryClient;
                                  if (queryClient != null) {
                                    queryClient.invalidateQuery(QueryKeys.vendor(widget.id));
                                  }
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      final vendor = vendorState.data;
                      if (vendor == null) {
                        return const Center(child: NoData(message: 'Vendor not found'));
                      }

                      return ShimmerLoading(
                        isLoading: vendorState.isLoading,
                        child: VendorInfoCard(vendor: vendor),
                      );
                    },
                  ),
                  SizedBox(height: spacing.md),
                  _VendorProductsSection(
                    vendorId: widget.id,
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

class _VendorProductsSection extends StatefulWidget {
  const _VendorProductsSection({
    required this.vendorId,
    required this.accumulatedProducts,
    required this.hasMorePages,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onReset,
  });

  final String vendorId;
  final List<ProductResponse> accumulatedProducts;
  final bool hasMorePages;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final VoidCallback onReset;

  @override
  State<_VendorProductsSection> createState() => _VendorProductsSectionState();
}

class _VendorProductsSectionState extends State<_VendorProductsSection> {
  String? _previousVendorId;
  bool _firstPageHasNextPage = false;

  @override
  void didUpdateWidget(_VendorProductsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vendorId != _previousVendorId) {
      _previousVendorId = widget.vendorId;
      widget.onReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final palette = context.palette;
    final typography = context.typography;

    return QueryBuilder<ProductListProductsResponse>(
      queryKey: QueryKeys.vendorProducts(widget.vendorId, page: 1, limit: 20),
      queryFn: () => locator.get<ProductService>().getProducts(
            vendorId: widget.vendorId,
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
                      queryClient.invalidateQuery(QueryKeys.vendorProducts(widget.vendorId, page: 1));
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
        _previousVendorId = widget.vendorId;

        final firstPageProducts = response.data;
        final allProducts = [
          ...firstPageProducts,
          ...widget.accumulatedProducts,
        ];

        if (allProducts.isEmpty) {
          return const Center(
            child: NoData(message: 'No products available from this vendor'),
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

class _VendorInfoCardPlaceholder extends StatelessWidget {
  const _VendorInfoCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final radius = context.radius;
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius.all(radius.md),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: radius.all(radius.sm),
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 20,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: radius.all(radius.xs),
                  ),
                ),
                SizedBox(height: spacing.xs / 2),
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: radius.all(radius.xs),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
