import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/presentation/widget/product/details/rating.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ProductHeaderSection extends StatelessWidget {
  const ProductHeaderSection({
    required this.id,
    required this.isLoading,
    required this.selectedVariant,
  });

  final String id;
  final bool isLoading;
  final Variants? selectedVariant;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;
    final colors = context.colors;

    return Shimmer(
      child: QueryBuilder<ProductDetailResponse>(
        queryKey: QueryKeys.productDetail(id),
        queryFn: () => locator.get<ProductService>().getProductById(id),
        builder: (context, productState) {
          if (productState.hasError) {
            return const SizedBox.shrink();
          }

          final product = productState.data!;
          final basePrice = double.tryParse(product.basePrice) ?? 0;
          final variantPrice =
              selectedVariant != null ? (double.tryParse(selectedVariant!.price) ?? basePrice) : basePrice;
          final compareAtPrice = selectedVariant?.compareAtPrice != null && selectedVariant!.compareAtPrice!.isNotEmpty
              ? double.tryParse(selectedVariant!.compareAtPrice!)
              : null;
          final hasDiscount = compareAtPrice != null && compareAtPrice > variantPrice;
          final discountPercent =
              hasDiscount ? (((compareAtPrice - variantPrice) / compareAtPrice) * 100).round() : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerLoading.text(
                          isLoading: productState.isLoading,
                          child: Text(
                            product.name,
                            style: typography.titleLarge
                                .toTextStyle(
                                  color: palette.textPrimary,
                                )
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                          ),
                        ),
                        SizedBox(height: spacing.sm),
                        Row(
                          children: [
                            ShimmerLoading.text(
                              isLoading: productState.isLoading,
                              child: Text(
                                '\$${variantPrice.toStringAsFixed(2)}',
                                style: typography.headlineSmall
                                    .toTextStyle(
                                      color: palette.textPrimary,
                                    )
                                    .copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (hasDiscount) ...[
                              SizedBox(width: spacing.sm),
                              ShimmerLoading.text(
                                isLoading: productState.isLoading,
                                child: Text(
                                  '\$${compareAtPrice.toStringAsFixed(2)}',
                                  style: typography.bodyLarge
                                      .toTextStyle(
                                        color: palette.textSecondary,
                                      )
                                      .copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor: palette.textSecondary,
                                      ),
                                ),
                              ),
                              SizedBox(width: spacing.sm),
                              ShimmerLoading.text(
                                isLoading: productState.isLoading,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: spacing.xs,
                                    vertical: spacing.xs / 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.danger,
                                    borderRadius: BorderRadius.circular(context.radius.xs),
                                  ),
                                  child: Text(
                                    '-$discountPercent%',
                                    style: typography.labelSmall
                                        .toTextStyle(
                                          color: colors.onError,
                                        )
                                        .copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  ShimmerLoading(
                    isLoading: productState.isLoading,
                    child: IconButton(
                      icon: Icon(
                        Icons.share_outlined,
                        color: palette.textSecondary,
                      ),
                      onPressed: () async {
                        final productUrl = 'https://example.com/products/${product.slug}';
                        await Share.share('Check out ${product.name}: $productUrl');
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              RatingDisplay(productId: id),
            ],
          );
        },
      ),
    );
  }
}
