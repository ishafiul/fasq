import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/category_service.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/services/review_service.dart';
import 'package:ecommerce/core/services/vendor_service.dart';
import 'package:ecommerce/core/widgets/no_data.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/core/widgets/tag.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class ProductInfoSection extends StatelessWidget {
  const ProductInfoSection({
    super.key,
    required this.id,
  });

  final String id;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    return QueryBuilder(
      queryKey: QueryKeys.productDetail(id),
      queryFn: () => locator.get<ProductService>().getProductById(id),
      builder: (context, productState) {
        if (productState.hasError) {
          return const Center(
            child: NoData(message: 'Failed to load product details'),
          );
        }

        final product = productState.data;
        final basePrice = double.tryParse(product?.basePrice ?? '0') ?? 0;
        final tags = product?.tags ?? [];
        final variants = product?.variants ?? [];

        final hasInStock = variants.any((v) => v.inventoryQuantity > 0);
        final totalStock = variants.fold<int>(0, (sum, v) => sum + v.inventoryQuantity.toInt());

        return ShimmerLoading(
          isLoading: productState.isLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product?.name ?? '',
                style: typography.bodyLarge
                    .toTextStyle(
                      color: productState.isLoading ? Colors.transparent : palette.textPrimary,
                    )
                    .copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              SizedBox(height: spacing.xs),
              Row(
                children: [
                  Text(
                    '\$${basePrice.toStringAsFixed(2)}',
                    style: typography.titleMedium
                        .toTextStyle(
                          color: productState.isLoading ? Colors.transparent : palette.brand,
                        )
                        .copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(width: spacing.xs),
                  _RatingDisplay(productId: id),
                ],
              ),
              SizedBox(height: spacing.sm),
              if (tags.isNotEmpty) ...[
                Wrap(
                  spacing: spacing.xs,
                  runSpacing: spacing.xs,
                  children: tags.map((tag) {
                    return Tag(
                      fill: TagFill.outline,
                      child: Text(
                        tag,
                        style: typography.labelSmall.toTextStyle(),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: spacing.md),
              ],
              _StockStatusIndicator(
                hasInStock: hasInStock,
                totalStock: totalStock,
                isLoading: productState.isLoading,
              ),
              if (product?.vendorId.isNotEmpty == true) ...[
                SizedBox(height: spacing.md),
                _VendorInfo(vendorId: product!.vendorId),
              ],
              if (product != null && product.categoryId != null && product.categoryId!.isNotEmpty) ...[
                SizedBox(height: spacing.md),
                _CategoryInfo(categoryId: product.categoryId!),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StockStatusIndicator extends StatelessWidget {
  const _StockStatusIndicator({
    required this.hasInStock,
    required this.totalStock,
    required this.isLoading,
  });

  final bool hasInStock;
  final int totalStock;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox.shrink();
    }

    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    if (!hasInStock) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        ),
        decoration: BoxDecoration(
          color: palette.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(context.radius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: palette.danger,
            ),
            SizedBox(width: spacing.xs),
            Text(
              'Out of Stock',
              style: typography.bodySmall
                  .toTextStyle(
                    color: palette.danger,
                  )
                  .copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
    }

    if (totalStock <= 10) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        ),
        decoration: BoxDecoration(
          color: palette.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(context.radius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: palette.warning,
            ),
            SizedBox(width: spacing.xs),
            Text(
              'Only $totalStock left',
              style: typography.bodySmall
                  .toTextStyle(
                    color: palette.warning,
                  )
                  .copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(context.radius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: palette.success,
          ),
          SizedBox(width: spacing.xs),
          Text(
            'In Stock',
            style: typography.bodySmall
                .toTextStyle(
                  color: palette.success,
                )
                .copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _RatingDisplay extends StatelessWidget {
  const _RatingDisplay({
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final palette = context.palette;

    return QueryBuilder(
      queryKey: QueryKeys.productReviews(productId),
      queryFn: () => locator.get<ReviewService>().getProductReviews(productId, limit: 1),
      builder: (context, state) {
        if (state.hasError || state.data == null) {
          return const SizedBox.shrink();
        }

        final rating = state.data?.rating;
        final isLoading = state.isLoading;

        if (rating == null && !isLoading) {
          return const SizedBox.shrink();
        }

        return ShimmerLoading(
          isLoading: isLoading,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.sm,
              vertical: context.spacing.xs / 2,
            ),
            decoration: BoxDecoration(
              color: palette.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.radius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: palette.brand,
                ),
                SizedBox(width: context.spacing.xs / 2),
                Text(
                  rating != null ? rating.averageRating.toStringAsFixed(1) : '0.0',
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
          ),
        );
      },
    );
  }
}

class _VendorInfo extends StatelessWidget {
  const _VendorInfo({
    required this.vendorId,
  });

  final String vendorId;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;
    final radius = context.radius;
    final colors = context.colors;

    return QueryBuilder(
      queryKey: QueryKeys.vendor(vendorId),
      queryFn: () => locator.get<VendorService>().getVendorById(vendorId),
      builder: (context, vendorState) {
        if (vendorState.isLoading || vendorState.hasError || vendorState.data == null) {
          return const SizedBox.shrink();
        }

        final vendor = vendorState.data!;

        return ShimmerLoading(
          isLoading: vendorState.isLoading,
          child: GestureDetector(
            onTap: () {
              context.router.push(VendorRoute(id: vendorState.data!.id));
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm,
                vertical: spacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: radius.all(radius.sm),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  if (vendor.logo != null && vendor.logo!.isNotEmpty)
                    ClipRRect(
                      borderRadius: radius.all(radius.xs),
                      child: CachedNetworkImage(
                        imageUrl: vendor.logo!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 40,
                          height: 40,
                          color: palette.surface,
                          child: Center(
                            child: CircularProgressSpinner(
                              color: palette.brand,
                              size: 16,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 40,
                          height: 40,
                          color: palette.surface,
                          child: Icon(
                            Icons.store_outlined,
                            color: palette.weak,
                            size: 20,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: radius.all(radius.xs),
                      ),
                      child: Icon(
                        Icons.store_outlined,
                        color: palette.weak,
                        size: 20,
                      ),
                    ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sold by',
                          style: typography.labelSmall.toTextStyle(
                            color: palette.textSecondary,
                          ),
                        ),
                        SizedBox(height: spacing.xs / 2),
                        Text(
                          vendor.businessName,
                          style: typography.bodyMedium
                              .toTextStyle(
                                color: palette.textPrimary,
                              )
                              .copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryInfo extends StatelessWidget {
  const _CategoryInfo({
    required this.categoryId,
  });

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;
    final radius = context.radius;
    final colors = context.colors;

    return QueryBuilder(
      queryKey: QueryKeys.category(categoryId),
      queryFn: () => locator.get<CategoryService>().getCategoryById(categoryId),
      builder: (context, categoryState) {
        if (categoryState.isLoading || categoryState.hasError || categoryState.data == null) {
          return const SizedBox.shrink();
        }

        final category = categoryState.data!;

        return ShimmerLoading(
          isLoading: categoryState.isLoading,
          child: GestureDetector(
            onTap: () {
              context.router.push(CategoryRoute(id: categoryState.data!.id));
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm,
                vertical: spacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: radius.all(radius.sm),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  if (category.imageUrl != null && category.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: radius.all(radius.xs),
                      child: CachedNetworkImage(
                        imageUrl: category.imageUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 40,
                          height: 40,
                          color: palette.surface,
                          child: Center(
                            child: CircularProgressSpinner(
                              color: palette.brand,
                              size: 16,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 40,
                          height: 40,
                          color: palette.surface,
                          child: Icon(
                            Icons.category_outlined,
                            color: palette.weak,
                            size: 20,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: radius.all(radius.xs),
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        color: palette.weak,
                        size: 20,
                      ),
                    ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Category',
                          style: typography.labelSmall.toTextStyle(
                            color: palette.textSecondary,
                          ),
                        ),
                        SizedBox(height: spacing.xs / 2),
                        Text(
                          category.name,
                          style: typography.bodyMedium
                              .toTextStyle(
                                color: palette.textPrimary,
                              )
                              .copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
