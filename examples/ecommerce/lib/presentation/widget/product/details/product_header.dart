import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/presentation/widget/product/details/rating.dart';
import 'package:ecommerce/presentation/widget/product/product_info_section.dart';
import 'package:flutter/material.dart';

class ProductHeaderSection extends StatelessWidget {
  const ProductHeaderSection({
    required this.product,
    required this.isLoading,
    required this.selectedVariant,
    required this.onShare,
  });

  final ProductDetailResponse? product;
  final bool isLoading;
  final Variants? selectedVariant;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;
    final colors = context.colors;

    if (isLoading || product == null) {
      return ProductInfoSection(
        product: product,
        isLoading: isLoading,
      );
    }

    final productNonNull = product!;
    final basePrice = double.tryParse(productNonNull.basePrice) ?? 0;
    final variantPrice = selectedVariant != null ? (double.tryParse(selectedVariant!.price) ?? basePrice) : basePrice;
    final compareAtPrice = selectedVariant?.compareAtPrice != null && selectedVariant!.compareAtPrice!.isNotEmpty
        ? double.tryParse(selectedVariant!.compareAtPrice!)
        : null;
    final hasDiscount = compareAtPrice != null && compareAtPrice > variantPrice;
    final discountPercent = hasDiscount ? (((compareAtPrice! - variantPrice) / compareAtPrice) * 100).round() : null;

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
                  Text(
                    productNonNull.name,
                    style: typography.titleLarge
                        .toTextStyle(
                          color: palette.textPrimary,
                        )
                        .copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                  ),
                  SizedBox(height: spacing.sm),
                  Row(
                    children: [
                      Text(
                        '\$${variantPrice.toStringAsFixed(2)}',
                        style: typography.headlineSmall
                            .toTextStyle(
                              color: palette.textPrimary,
                            )
                            .copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (hasDiscount) ...[
                        SizedBox(width: spacing.sm),
                        Text(
                          '\$${compareAtPrice!.toStringAsFixed(2)}',
                          style: typography.bodyLarge
                              .toTextStyle(
                                color: palette.textSecondary,
                              )
                              .copyWith(
                                decoration: TextDecoration.lineThrough,
                                decorationColor: palette.textSecondary,
                              ),
                        ),
                        SizedBox(width: spacing.sm),
                        Container(
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
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.share_outlined,
                color: palette.textSecondary,
              ),
              onPressed: onShare,
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        RatingDisplay(productId: productNonNull.id),
      ],
    );
  }
}
