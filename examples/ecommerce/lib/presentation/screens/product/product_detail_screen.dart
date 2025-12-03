import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/card.dart';
import 'package:ecommerce/presentation/widget/product/product_bottom_action_bar.dart';
import 'package:ecommerce/presentation/widget/product/product_details_tab.dart';
import 'package:ecommerce/presentation/widget/product/product_image_carousel.dart';
import 'package:ecommerce/presentation/widget/product/product_info_section.dart';
import 'package:ecommerce/presentation/widget/product/product_reviews_tab.dart';
import 'package:ecommerce/presentation/widget/product/variants_section.dart';
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
    if (_selectedVariant == null) return true;
    return _selectedVariant!.inventoryQuantity <= 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              const SliverAppBar(
                title: Text('Product Details'),
                floating: true,
                snap: true,
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
      bottomNavigationBar: ProductBottomActionBar(
        productId: widget.id,
        isOutOfStock: _isOutOfStock,
        maxQuantity: _selectedVariant?.inventoryQuantity.toInt(),
        onAddToCart: (quantity) {
          // TODO: Add to cart with quantity
        },
        onBuyNow: (quantity) {
          // TODO: Buy now with quantity
        },
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
