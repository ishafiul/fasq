import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/cart_add_item_request.dart';
import 'package:ecommerce/api/models/cart_response.dart';
import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/cart_service.dart';
import 'package:ecommerce/core/services/user_service.dart';
import 'package:ecommerce/core/widgets/card.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer.dart';
import 'package:ecommerce/core/widgets/snackbar.dart';
import 'package:ecommerce/presentation/widget/cart/cart_icon_button.dart';
import 'package:ecommerce/presentation/widget/product/product_bottom_action_bar.dart';
import 'package:ecommerce/presentation/widget/product/product_details_tab.dart';
import 'package:ecommerce/presentation/widget/product/product_image_carousel.dart';
import 'package:ecommerce/presentation/widget/product/product_info_section.dart';
import 'package:ecommerce/presentation/widget/product/product_reviews_tab.dart';
import 'package:ecommerce/presentation/widget/product/variants_section.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.id,
  });

  final String id;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Variants? _selectedVariant;

  void _handleVariantSelected(Variants? variant) {
    if (!mounted) return;
    setState(() {
      _selectedVariant = variant;
    });
  }

  bool get _isOutOfStock {
    if (_selectedVariant == null) return false;
    return _selectedVariant!.inventoryQuantity <= 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: Shimmer(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                const SliverAppBar(
                  title: Text('Product Details'),
                  floating: true,
                  snap: true,
                  actions: [
                    CartIconButton(),
                  ],
                ),
                SliverToBoxAdapter(
                  child: ProductImageCarousel(
                    id: widget.id,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: context.spacing.sm),
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      tabs: const [
                        Tab(text: 'Product'),
                        Tab(text: 'Details'),
                        Tab(text: 'Reviews'),
                      ],
                      labelColor: context.palette.brand,
                      unselectedLabelColor: context.palette.textSecondary,
                      indicatorColor: context.palette.brand,
                      labelPadding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              children: [
                _ProductTab(
                  id: widget.id,
                  onVariantSelected: _handleVariantSelected,
                ),
                ProductDetailsTab(
                  productId: widget.id,
                ),
                ProductReviewsTab(
                  productId: widget.id,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _AddToCartButton(
        productId: widget.id,
        selectedVariant: _selectedVariant,
        isOutOfStock: _isOutOfStock,
        maxQuantity: _selectedVariant?.inventoryQuantity.toInt(),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(child: _tabBar),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _ProductTab extends StatelessWidget {
  final String id;
  final ValueChanged<Variants?>? onVariantSelected;

  const _ProductTab({
    required this.id,
    this.onVariantSelected,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(spacing.sm),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                AppCard(
                  children: [
                    ProductInfoSection(id: id),
                  ],
                ),
                SizedBox(height: spacing.md),
                VariantsSection(
                  productId: id,
                  onVariantSelected: onVariantSelected,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddToCartButton extends StatefulWidget {
  const _AddToCartButton({
    required this.productId,
    required this.selectedVariant,
    required this.isOutOfStock,
    this.maxQuantity,
  });

  final String productId;
  final Variants? selectedVariant;
  final bool isOutOfStock;
  final int? maxQuantity;

  @override
  State<_AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<_AddToCartButton> {
  @override
  Widget build(BuildContext context) {
    return QueryBuilder<bool>(
      queryKey: QueryKeys.isLoggedIn,
      queryFn: () => locator.get<UserService>().isLoggedIn(),
      builder: (context, authState) {
        final isLoggedIn = authState.data ?? false;

        if (!isLoggedIn) {
          return ProductBottomActionBar(
            productId: widget.productId,
            isOutOfStock: widget.isOutOfStock,
            maxQuantity: widget.maxQuantity,
            onAddToCart: (quantity) {
              showSnackBar(
                context: context,
                type: SnackBarType.alert,
                message: 'Please login to add items to cart',
                withIcon: true,
              );
              Future.delayed(const Duration(seconds: 1), () {
                if (context.mounted) {
                  context.router.push(const LoginRoute());
                }
              });
            },
          );
        }

        if (widget.selectedVariant == null) {
          return ProductBottomActionBar(
            productId: widget.productId,
            isOutOfStock: false,
            maxQuantity: widget.maxQuantity,
            onAddToCart: (quantity) {
              showSnackBar(
                context: context,
                type: SnackBarType.alert,
                message: 'Please select a variant',
                withIcon: true,
              );
            },
          );
        }

        final cartService = locator.get<CartService>();
        final variant = widget.selectedVariant!;
        final priceAtAdd = variant.price;

        return MutationBuilder<CartResponse, CartAddItemRequest>(
          mutationFn: (request) => cartService.addItem(
            productId: request.productId,
            variantId: request.variantId,
            quantity: request.quantity,
            priceAtAdd: request.priceAtAdd,
          ),
          options: MutationOptions(
            meta: const MutationMeta(
              successMessage: 'Item added to cart',
              errorMessage: 'Failed to add item to cart',
            ),
            onSuccess: (data) {
              final queryClient = context.queryClient;
              if (queryClient != null) {
                queryClient.setQueryData(QueryKeys.cart, data);
              }
            },
          ),
          builder: (context, state, mutate) {
            return ProductBottomActionBar(
              productId: widget.productId,
              isLoading: state.isLoading,
              isOutOfStock: widget.isOutOfStock,
              maxQuantity: widget.maxQuantity,
              onAddToCart: (quantity) {
                final request = CartAddItemRequest(
                  productId: widget.productId,
                  variantId: variant.id,
                  quantity: quantity,
                  priceAtAdd: priceAtAdd,
                );
                mutate(request);
              },
            );
          },
        );
      },
    );
  }
}
