import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/product_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/widgets/badge.dart' as core;
import 'package:ecommerce/core/widgets/card.dart';
import 'package:ecommerce/core/widgets/number_stepper/number_stepper.dart';
import 'package:ecommerce/core/widgets/rating.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/core/widgets/tag.dart';
import 'package:ecommerce/presentation/widget/product/product_card_data.dart';
import 'package:ecommerce/presentation/widget/product/product_cart_stepper.dart';
import 'package:flutter/material.dart';

enum ProductTagType {
  new_,
  hot,
  sale,
  other;

  static ProductTagType fromString(String tag) {
    return switch (tag.toLowerCase()) {
      'new' => ProductTagType.new_,
      'hot' => ProductTagType.hot,
      'sale' => ProductTagType.sale,
      _ => ProductTagType.other,
    };
  }
}

enum ProductCardLayout { vertical, horizontal }

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.discountPercentage,
    this.showAddToCart = true,
    this.rating,
  });

  final ProductResponse? product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final double? discountPercentage;
  final bool showAddToCart;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final colors = context.colors;
    final palette = context.palette;

    final data = ProductCardData.fromProduct(
      product,
      discountPercentage: discountPercentage,
    );

    return AppCard(
      onClick: _buildOnTap(context, data),
      padding: EdgeInsets.zero,
      borderRadius: radius.all(radius.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius.all(radius.md),
        border: Border.all(color: palette.border),
      ),
      bodyStyle: const BoxDecoration(),
      bodyMainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              ProductImage(
                data: data,
                layout: ProductCardLayout.vertical,
              ),
              if (showAddToCart)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: ProductCartStepper(
                    id: product!.id,
                    max: 10,
                    compact: true,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(spacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ProductName(name: data.productName),
              const Rating(value: 3.5, readOnly: true, starSize: 14),
              const SizedBox(height: 2),
              ProductPriceSection(
                data: data,
                layout: ProductCardLayout.vertical,
              ),
            ],
          ),
        ),
      ],
    );
  }

  VoidCallback? _buildOnTap(BuildContext context, ProductCardData data) {
    if (onTap != null) return onTap;
    if (!data.hasValidId) return null;
    return () => context.router.push(ProductDetailRoute(id: data.productId));
  }
}

class ProductCardHorizontal extends StatelessWidget {
  const ProductCardHorizontal({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.discountPercentage,
    this.showAddToCart = true,
    this.rating,
  });

  final ProductResponse? product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final double? discountPercentage;
  final bool showAddToCart;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final colors = context.colors;
    final palette = context.palette;

    final data = ProductCardData.fromProduct(
      product,
      discountPercentage: discountPercentage,
    );

    return AppCard(
      onClick: _buildOnTap(context, data),
      padding: EdgeInsets.all(spacing.sm),
      borderRadius: radius.all(radius.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius.all(radius.md),
        border: Border.all(color: palette.border),
      ),
      bodyStyle: const BoxDecoration(),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductImage(
              data: data,
              layout: ProductCardLayout.horizontal,
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProductName(name: data.productName),
                  const Rating(value: 3.5, readOnly: true, starSize: 14),
                  ProductPriceSection(
                    data: data,
                    layout: ProductCardLayout.horizontal,
                  ),
                  if (showAddToCart)
                    ProductCartStepper(
                      id: product!.id,
                      max: 10,
                      expandDirection: NumberStepperExpandDirection.right,
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  VoidCallback? _buildOnTap(BuildContext context, ProductCardData data) {
    if (onTap != null) return onTap;
    if (!data.hasValidId) return null;
    return () => context.router.push(ProductDetailRoute(id: data.productId));
  }
}

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.data,
    required this.layout,
  });

  final ProductCardData data;
  final ProductCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final radius = context.radius;
    final palette = context.palette;

    final borderRadius = switch (layout) {
      ProductCardLayout.vertical => radius.top(radius.md),
      ProductCardLayout.horizontal => radius.all(radius.sm),
    };

    final imageWidget = ClipRRect(
      borderRadius: borderRadius,
      child: _buildImageContent(context),
    );

    if (layout == ProductCardLayout.horizontal) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: palette.weak.withValues(alpha: 0.08),
        ),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildImageContent(BuildContext context) {
    final imageUrl = data.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const _ImagePlaceholder(),
              errorWidget: (context, url, error) => const _ImageError(),
            )
          else
            const _ImagePlaceholder(),
          _DiscountBadge(data: data),
          _TagBadge(data: data),
        ],
      ),
    );
  }
}

/// Discount badge displayed on product image.
class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.data});

  final ProductCardData data;

  @override
  Widget build(BuildContext context) {
    if (!data.hasDiscount) return const SizedBox.shrink();

    final palette = context.palette;
    final typography = context.typography;

    return Positioned(
      top: 6,
      left: 6,
      child: core.Badge(
        color: palette.danger,
        content: Text(
          data.formattedDiscountPercentage,
          style: typography.labelSmall.toTextStyle(
            color: ColorUtils.onColor(palette.danger),
          ),
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.data});

  final ProductCardData data;

  @override
  Widget build(BuildContext context) {
    if (data.tags.isEmpty || data.hasDiscount) return const SizedBox.shrink();

    return Positioned(
      top: 6,
      left: 6,
      child: ProductTag(tag: data.tags.first.toUpperCase()),
    );
  }
}

/// Product image placeholder while loading.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ColoredBox(
      color: palette.surface,
      child: Center(
        child: CircularProgressSpinner(
          color: palette.brand,
          size: 24,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

/// Product image error state.
class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    return ColoredBox(
      color: palette.surface,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: palette.weak,
        size: spacing.lg,
      ),
    );
  }
}

class ProductTag extends StatelessWidget {
  const ProductTag({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tagType = ProductTagType.fromString(tag);

    final (tagColor, customColor) = switch (tagType) {
      ProductTagType.new_ => (TagColor.default_, palette.brand),
      ProductTagType.hot => (TagColor.warning, null),
      ProductTagType.sale => (TagColor.danger, null),
      ProductTagType.other => (TagColor.primary, null),
    };

    return Tag(
      color: tagColor,
      customColor: customColor,
      child: Text(tag),
    );
  }
}

class ProductName extends StatelessWidget {
  const ProductName({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typography = context.typography;

    return Text(
      name,
      style: typography.bodyMedium.toTextStyle(color: palette.textPrimary).copyWith(fontWeight: FontWeight.w500),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class ProductPriceSection extends StatelessWidget {
  const ProductPriceSection({
    super.key,
    required this.data,
    required this.layout,
  });

  final ProductCardData data;
  final ProductCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typography = context.typography;

    if (!data.hasDiscount) {
      return Text(
        data.formattedOriginalPrice,
        style: typography.bodyMedium.toTextStyle(color: palette.textPrimary).copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            data.formattedDiscountedPrice,
            style: typography.bodySmall.toTextStyle(color: palette.textPrimary).copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            data.formattedOriginalPrice,
            style: typography.bodyMedium.toTextStyle(color: palette.textSecondary).copyWith(
                  decoration: TextDecoration.lineThrough,
                  decorationColor: palette.textSecondary,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
