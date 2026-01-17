import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/category_service.dart';
import 'package:ecommerce/core/services/review_service.dart';
import 'package:ecommerce/core/services/vendor_service.dart';
import 'package:ecommerce_ui/ecommerce_ui.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class ProductInfoSection extends StatelessWidget {
  const ProductInfoSection({
    super.key,
    required this.product,
    this.isLoading = false,
  });

  final ProductDetailResponse? product;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    final product = this.product;

    final basePrice = double.tryParse(product?.basePrice ?? '0') ?? 0;
    final tags = product?.tags ?? [];
    final variants = product?.variants ?? [];

    final hasInStock = variants.any((v) => v.inventoryQuantity > 0);
    final totalStock = variants.fold<int>(0, (sum, v) => sum + v.inventoryQuantity.toInt());

    return ShimmerLoading(
      isLoading: isLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product?.name ?? 'Product Name',
            style: typography.headlineSmall
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '\$${basePrice.toStringAsFixed(2)}',
                style: typography.headlineMedium
                    .toTextStyle(
                      color: palette.textPrimary,
                    )
                    .copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(width: spacing.sm),
              if (product != null) _RatingDisplay(productId: product.id),
            ],
          ),
          SizedBox(height: spacing.md),
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              children: tags.map((tag) {
                return Tag(
                  fill: TagFill.outline,
                  child: Text(
                    tag,
                    style: typography.labelSmall.toTextStyle(
                      color: palette.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: spacing.md),
          ],
          _StockStatusIndicator(
            hasInStock: hasInStock,
            totalStock: totalStock,
            isLoading: isLoading,
          ),
          if (product != null && product.vendorId.isNotEmpty) ...[
            SizedBox(height: spacing.lg),
            _VendorInfo(vendorId: product.vendorId),
          ],
          if (product != null && product.categoryId != null && product.categoryId!.isNotEmpty) ...[
            SizedBox(height: spacing.md),
            _CategoryInfo(categoryId: product.categoryId!),
          ],
        ],
      ),
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

    final typography = context.typography;
    final palette = context.palette;

    if (!hasInStock) {
      return Text(
        'Out of Stock',
        style: typography.bodyMedium
            .toTextStyle(
              color: palette.danger,
            )
            .copyWith(
              fontWeight: FontWeight.w600,
            ),
      );
    }

    if (totalStock <= 10) {
      return Text(
        'Only $totalStock left in stock',
        style: typography.bodyMedium
            .toTextStyle(
              color: palette.danger,
            )
            .copyWith(
              fontWeight: FontWeight.w600,
            ),
      );
    }

    return Text(
      'In Stock',
      style: typography.bodyMedium
          .toTextStyle(
            color: palette.success,
          )
          .copyWith(
            fontWeight: FontWeight.w600,
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
        // final reviews = state.data?.data ?? []; // Unused for now
        final totalReviews = state.data?.meta.total ?? 0;
        final isLoading = state.isLoading;

        if (rating == null && !isLoading) {
          return const SizedBox.shrink();
        }

        return ShimmerLoading(
          isLoading: isLoading,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: 20,
                color: palette.warning, // Gold color usually better for stars
              ),
              SizedBox(width: context.spacing.xs / 2),
              Text(
                rating != null ? rating.averageRating.toStringAsFixed(1) : '0.0',
                style: typography.bodyMedium
                    .toTextStyle(
                      color: palette.textPrimary,
                    )
                    .copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (totalReviews > 0) ...[
                SizedBox(width: context.spacing.xs),
                Text(
                  '($totalReviews)',
                  style: typography.bodySmall.toTextStyle(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ],
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
    final palette = context.palette;
    final radius = context.radius;

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
          child: ListItem(
            title: Text(
              vendor.businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            description: const Text('Sold by'),
            onClick: () {
              context.router.push(VendorRoute(id: vendorState.data!.id));
            },
            prefix: Builder(
              builder: (context) {
                if (vendor.logo != null && vendor.logo!.isNotEmpty) {
                  return ClipRRect(
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
                  );
                } else {
                  return Container(
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
                  );
                }
              },
            ),
            suffix: Icon(
              Icons.chevron_right,
              color: palette.textSecondary,
              size: 20,
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
    final palette = context.palette;
    final radius = context.radius;

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
          child: ListItem(
            title: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            description: const Text('Category'),
            onClick: () {
              context.router.push(CategoryRoute(id: categoryState.data!.id));
            },
            prefix: Builder(
              builder: (context) {
                if (category.imageUrl != null && category.imageUrl!.isNotEmpty) {
                  return ClipRRect(
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
                  );
                } else {
                  return Container(
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
                  );
                }
              },
            ),
            suffix: Icon(
              Icons.chevron_right,
              color: palette.textSecondary,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}
