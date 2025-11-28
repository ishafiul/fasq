import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/services/review_service.dart';
import 'package:ecommerce/core/services/vendor_service.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/no_data.dart';
import 'package:ecommerce/core/widgets/rating.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/core/widgets/tag.dart';
import 'package:ecommerce/presentation/widget/product_image_carousel.dart';
import 'package:ecommerce/presentation/widget/review_item.dart';
import 'package:ecommerce/presentation/widget/variant_selector.dart';
import 'package:ecommerce/presentation/widget/vendor_info_card.dart';
import 'package:fasq/fasq.dart';
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
    final palette = context.palette;

    return Shimmer(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Product Details'),
          backgroundColor: palette.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: QueryBuilder(
          queryKey: QueryKeys.productDetail(id),
          queryFn: () => locator.get<ProductService>().getProductById(id),
          builder: (context, productState) {
            if (productState.isLoading) {
              return const ShimmerLoading(
                isLoading: true,
                child: SizedBox.shrink(),
              );
            }

            if (productState.hasError || productState.data == null) {
              return Center(
                child: NoData(message: 'Failed to load product details'),
              );
            }

            final product = productState.data!;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ProductImageCarousel(images: product.images),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: context.spacing.md),
                ),
                SliverToBoxAdapter(
                  child: _ProductInfoSection(product: product),
                ),
                SliverToBoxAdapter(
                  child: QueryBuilder(
                    queryKey: QueryKeys.vendor(product.vendorId),
                    queryFn: () => locator.get<VendorService>().getVendorById(product.vendorId),
                    builder: (context, vendorState) {
                      if (vendorState.isLoading) {
                        return const SizedBox.shrink();
                      }

                      if (vendorState.hasError || vendorState.data == null) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
                        child: VendorInfoCard(vendor: vendorState.data!),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: context.spacing.md),
                ),
                SliverToBoxAdapter(
                  child: _VariantsSection(variants: product.variants),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: context.spacing.md),
                ),
                SliverToBoxAdapter(
                  child: _ReviewsSection(productId: product.id),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: context.spacing.xxl),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: _BottomActionBar(productId: id),
      ),
    );
  }
}

class _ProductInfoSection extends StatelessWidget {
  const _ProductInfoSection({
    required this.product,
  });

  final ProductDetailResponse product;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    final basePrice = double.tryParse(product.basePrice) ?? 0;
    final tags = product.tags;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: typography.bodyMedium.toTextStyle(color: palette.textPrimary).copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: spacing.xs),
          Row(
            children: [
              Text(
                '\$${basePrice.toStringAsFixed(2)}',
                style: typography.titleMedium.toTextStyle(color: palette.textPrimary).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          if (tags != null && tags.isNotEmpty) ...[
            SizedBox(height: spacing.sm),
            Wrap(
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              children: tags.map((tag) {
                return Tag(
                  color: TagColor.primary,
                  child: Text(tag.toUpperCase()),
                );
              }).toList(),
            ),
          ],
          if (product.description != null && product.description!.isNotEmpty) ...[
            SizedBox(height: spacing.md),
            Text(
              product.description!,
              style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _VariantsSection extends StatelessWidget {
  const _VariantsSection({
    required this.variants,
  });

  final List<Variants> variants;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    if (variants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.sm),
          child: Text(
            'Variants',
            style: typography.titleSmall.toTextStyle(color: palette.textPrimary),
          ),
        ),
        SizedBox(height: spacing.sm),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.sm),
          child: VariantSelector(
            variants: variants,
            onVariantSelected: (variant) {
              // Handle variant selection
            },
          ),
        ),
        SizedBox(height: spacing.md),
      ],
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    return QueryBuilder(
      queryKey: QueryKeys.productReviews(productId),
      queryFn: () => locator.get<ReviewService>().getProductReviews(productId),
      builder: (context, state) {
        if (state.isLoading) {
          return Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Center(
              child: CircularProgressSpinner(color: palette.brand, size: 24, strokeWidth: 2),
            ),
          );
        }

        if (state.hasError || state.data == null) {
          return const SizedBox.shrink();
        }

        final reviewsData = state.data!;
        final reviews = reviewsData.data;
        final rating = reviewsData.rating;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reviews',
                    style: typography.titleSmall.toTextStyle(color: palette.textPrimary),
                  ),
                  SizedBox(height: spacing.sm),
                  Row(
                    children: [
                      Rating(
                        value: rating.averageRating.toDouble(),
                        readOnly: true,
                        starSize: 18,
                      ),
                      SizedBox(width: spacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rating.averageRating.toStringAsFixed(1),
                            style: typography.bodyLarge.toTextStyle(color: palette.textPrimary).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            '${rating.totalReviews.toInt()} reviews',
                            style: typography.bodySmall.toTextStyle(color: palette.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.md),
            if (reviews.isEmpty)
              Padding(
                padding: EdgeInsets.all(spacing.xxl),
                child: Center(
                  child: NoData(message: 'No reviews yet'),
                ),
              )
            else
              Column(
                children: reviews.map((review) => ReviewItem(review: review)).toList(),
              ),
          ],
        );
      },
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;

    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(spacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: context.palette.border, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Button.primary(
                onPressed: () {
                  // TODO: Add to cart
                },
                isBlock: true,
                child: const Text('Add to Cart'),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Button(
                onPressed: () {
                  // TODO: Buy now
                },
                fill: ButtonFill.outline,
                isBlock: true,
                child: const Text('Buy Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
