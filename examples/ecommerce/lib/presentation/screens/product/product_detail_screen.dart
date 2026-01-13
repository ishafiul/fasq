import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/api/models/review_response.dart';
import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/services/review_service.dart';
import 'package:ecommerce/presentation/widget/cart/cart_icon_button.dart';
import 'package:ecommerce/presentation/widget/product/details/product_bottom_nav.dart';
import 'package:ecommerce/presentation/widget/product/details/product_image_carousel.dart';
import 'package:ecommerce/presentation/widget/product/product_reviews_tab.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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

  void _handleShare(String? productName, String? productUrl) {
    if (productName == null || productUrl == null) return;
    Share.share('Check out $productName: $productUrl');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    return Scaffold(
      body: QueryBuilder<ProductDetailResponse>(
        queryKey: QueryKeys.productDetail(widget.id),
        queryFn: () => locator.get<ProductService>().getProductById(widget.id),
        builder: (context, productState) {
          final product = productState.data;
          if (productState.isLoading || !productState.hasData) return SizedBox();
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                const SliverAppBar(
                  title: Text('Product Details'),
                  floating: true,
                  snap: true,
                  pinned: true,
                  actions: [
                    CartIconButton(),
                  ],
                ),
              ];
            },
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ProductImageCarousel(
                    id: product!.id,
                  ),
                ),
                // SliverPadding(
                //   padding: EdgeInsets.all(spacing.md),
                //   sliver: SliverList(
                //     delegate: SliverChildListDelegate(
                //       [
                //         _ProductHeaderSection(
                //           product: product,
                //           isLoading: productState.isLoading,
                //           selectedVariant: _selectedVariant,
                //           onShare: () => _handleShare(product.name, product.slug),
                //         ),
                //         SizedBox(height: spacing.lg),
                //         const Divider(height: 1),
                //         SizedBox(height: spacing.lg),
                //         VariantsSection(
                //           product: product,
                //           isLoading: productState.isLoading,
                //           onVariantSelected: _handleVariantSelected,
                //         ),
                //         SizedBox(height: spacing.lg),
                //         const Divider(height: 1),
                //         SizedBox(height: spacing.lg),
                //         if (product.description != null) ...[
                //           Collapse(
                //             items: [
                //               CollapsePanel(
                //                 key: 'description',
                //                 title: Text(
                //                   'Description',
                //                   style: typography.titleMedium.toTextStyle(),
                //                 ),
                //                 child: Text(
                //                   product.description!,
                //                   style: typography.bodyMedium.toTextStyle(
                //                     color: palette.textSecondary,
                //                   ),
                //                 ),
                //               ),
                //               CollapsePanel(
                //                 key: 'specifications',
                //                 title: Text(
                //                   'Specifications',
                //                   style: typography.titleMedium.toTextStyle(),
                //                 ),
                //                 child: _SpecificationsContent(product: product),
                //               ),
                //               CollapsePanel(
                //                 key: 'shipping',
                //                 title: Text(
                //                   'Delivery',
                //                   style: typography.titleMedium.toTextStyle(),
                //                 ),
                //                 child: _DeliveryOptions(),
                //               ),
                //             ],
                //           ),
                //           SizedBox(height: spacing.lg),
                //         ],
                //         _RatingReviewsSection(
                //           productId: widget.id,
                //           productName: product.name,
                //         ),
                //         SizedBox(height: spacing.lg),
                //       ],
                //     ),
                //   ),
                // ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: ProductBottomActionBar(
        productId: widget.id,
        selectedVariant: _selectedVariant,
        isOutOfStock: _isOutOfStock,
      ),
    );
  }
}

class _SpecificationsContent extends StatelessWidget {
  const _SpecificationsContent({
    required this.product,
  });

  final ProductDetailResponse product;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    final specifications = <String, String>{};

    if (product.tags != null && product.tags!.isNotEmpty) {
      specifications['Tags'] = product.tags!.join(', ');
    }

    if (specifications.isEmpty) {
      return Text(
        'No specifications available',
        style: typography.bodyMedium.toTextStyle(
          color: palette.textSecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: specifications.entries.map((entry) {
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.sm,
                  vertical: spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(context.radius.sm),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  entry.value,
                  style: typography.bodyMedium.toTextStyle(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DeliveryOptions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Column(
      children: [
        _DeliveryOption(
          title: 'Standard',
          duration: '5-7 days',
          price: '\$3.00',
        ),
        SizedBox(height: spacing.sm),
        _DeliveryOption(
          title: 'Express',
          duration: '1-2 days',
          price: '\$12.00',
        ),
      ],
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({
    required this.title,
    required this.duration,
    required this.price,
  });

  final String title;
  final String duration;
  final String price;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;
    final radius = context.radius;

    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: radius.all(radius.sm),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typography.bodyLarge
                    .toTextStyle(
                      color: palette.textPrimary,
                    )
                    .copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              SizedBox(height: spacing.xs / 2),
              Text(
                duration,
                style: typography.bodySmall.toTextStyle(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            price,
            style: typography.bodyMedium
                .toTextStyle(
                  color: palette.brand,
                )
                .copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _RatingReviewsSection extends StatelessWidget {
  const _RatingReviewsSection({
    required this.productId,
    this.productName,
  });

  final String productId;
  final String? productName;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    return QueryBuilder(
      queryKey: QueryKeys.productReviews(productId),
      queryFn: () => locator.get<ReviewService>().getProductReviews(productId, limit: 1),
      builder: (context, state) {
        if (state.hasError || (state.data == null && !state.isLoading)) {
          return const SizedBox.shrink();
        }

        final rating = state.data?.rating;
        final reviews = state.data?.data ?? [];
        final totalReviews = state.data?.meta.total ?? 0;

        if (rating == null && totalReviews == 0 && !state.isLoading) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rating & Reviews',
                  style: typography.titleMedium
                      .toTextStyle(
                        color: palette.textPrimary,
                      )
                      .copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (totalReviews > 0)
                  TextButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (context) {
                          return SizedBox(
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(spacing.md),
                              ),
                              child: Scaffold(
                                appBar: AppBar(
                                  title: const Text('Reviews'),
                                  automaticallyImplyLeading: false,
                                  actions: [
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                                body: ProductReviewsTab(productId: productId),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: const Text('View All Reviews'),
                  ),
              ],
            ),
            if (rating != null) ...[
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 24,
                    color: palette.warning,
                  ),
                  SizedBox(width: spacing.xs),
                  Text(
                    rating.averageRating.toStringAsFixed(1),
                    style: typography.headlineSmall
                        .toTextStyle(
                          color: palette.textPrimary,
                        )
                        .copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(width: spacing.xs),
                  Text(
                    '/5',
                    style: typography.bodyMedium.toTextStyle(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            if (reviews.isNotEmpty) ...[
              SizedBox(height: spacing.md),
              _ReviewItem(review: reviews.first),
            ],
          ],
        );
      },
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.review,
  });

  final ReviewResponse review;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(context.radius.sm),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: palette.surface,
                child: Icon(
                  Icons.person,
                  color: palette.textSecondary,
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User',
                      style: typography.bodyMedium
                          .toTextStyle(
                            color: palette.textPrimary,
                          )
                          .copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: spacing.xs / 2),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < review.rating.toInt() ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 16,
                          color: palette.warning,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            SizedBox(height: spacing.sm),
            Text(
              review.comment ?? '',
              style: typography.bodyMedium.toTextStyle(
                color: palette.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
