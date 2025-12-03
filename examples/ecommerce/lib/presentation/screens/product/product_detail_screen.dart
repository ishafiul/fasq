import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/devider.dart';
import 'package:ecommerce/presentation/widget/product/product_bottom_action_bar.dart';
import 'package:ecommerce/presentation/widget/product/product_details_tab.dart';
import 'package:ecommerce/presentation/widget/product/product_image_carousel.dart';
import 'package:ecommerce/presentation/widget/product/product_info_section.dart';
import 'package:ecommerce/presentation/widget/product/product_reviews_tab.dart';
import 'package:ecommerce/presentation/widget/product/variants_section.dart';
import 'package:ecommerce/presentation/widget/vendor/vendor_section.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({
    super.key,
    required this.id,
  });

  final String id;

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
                  id: id,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: context.spacing.md),
              ),
              SliverToBoxAdapter(
                child: AppDivider.base(
                  axis: Axis.horizontal,
                ),
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
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            children: [
              _ProductTab(
                id: id,
              ),
              ProductDetailsTab(
                productId: id,
              ),
              ProductReviewsTab(
                productId: id,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ProductBottomActionBar(
        productId: id,
        onAddToCart: () {
          // TODO: Add to cart
        },
        onBuyNow: () {
          // TODO: Buy now
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

  const _ProductTab({required this.id});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(context.spacing.sm),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                ProductInfoSection(
                  id: id,
                ),
                SizedBox(height: spacing.md),
                VendorSection(
                  productId: id,
                ),
                VariantsSection(
                  productId: id,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
