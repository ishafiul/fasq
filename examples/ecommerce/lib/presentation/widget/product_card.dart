import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/product_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// A card widget that displays product information following Ant Design mobile patterns.
///
/// Features:
/// - Clean, elevated card design with subtle shadows
/// - Product image with loading/error states
/// - Product name with proper truncation
/// - Price display with discount support
/// - Optional add to cart action
/// - Tags/badges for product status
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.discountPercentage,
    this.showAddToCart = true,
  });

  final ProductResponse? product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final double? discountPercentage;
  final bool showAddToCart;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final radius = context.radius;

    final productName = product?.name ?? '';
    final basePrice = product?.basePrice ?? '0';
    final tags = product?.tags ?? [];

    // Get image URL from images array
    final imageUrl = product?.images.isNotEmpty == true ? product?.images.first.url : null;

    // Calculate discounted price if applicable
    final hasDiscount = discountPercentage != null && discountPercentage! > 0;
    final originalPrice = double.tryParse(basePrice) ?? 0;
    final discountedPrice = hasDiscount ? originalPrice * (1 - discountPercentage! / 100) : originalPrice;

    // Determine if we're in dark mode for shadow adjustments
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? palette.surface : Colors.white,
        borderRadius: radius.all(radius.md),
        border: isDark ? Border.all(color: palette.border, width: 0.5) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius.all(radius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius.all(radius.md),
          splashColor: palette.brand.withValues(alpha: 0.08),
          highlightColor: palette.brand.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image Section - takes 60% of card height
              Expanded(
                flex: 6,
                child: _ProductImage(
                  imageUrl: imageUrl,
                  hasDiscount: hasDiscount,
                  discountPercentage: discountPercentage,
                  tags: tags,
                  palette: palette,
                  spacing: spacing,
                  typography: typography,
                  radius: radius,
                ),
              ),

              // Product Info Section - takes 40% of card height
              Expanded(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.all(spacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product Name - allow to shrink if needed
                      Flexible(
                        child: Text(
                          productName,
                          style: typography.labelMedium.toTextStyle(
                            color: palette.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      SizedBox(height: spacing.xs / 2),

                      // Price Row
                      _PriceSection(
                        hasDiscount: hasDiscount,
                        discountedPrice: discountedPrice,
                        originalPrice: originalPrice,
                        palette: palette,
                        typography: typography,
                      ),

                      // Add to Cart Button (optional)
                      if (showAddToCart) ...[
                        Button.primary(
                          onPressed: onAddToCart,
                          fill: ButtonFill.solid,
                          shape: ButtonShape.base,
                          buttonSize: ButtonSize.mini,
                          isBlock: true,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgIcon(
                                svg: Assets.icons.outlined.shoppingCart,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              const Text('Add'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.hasDiscount,
    required this.discountPercentage,
    required this.tags,
    required this.palette,
    required this.spacing,
    required this.typography,
    required this.radius,
  });

  final String? imageUrl;
  final bool hasDiscount;
  final double? discountPercentage;
  final List<String> tags;
  final AppPalette palette;
  final Spacing spacing;
  final TypographyScale typography;
  final RadiusScale radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius.top(radius.md),
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            if (imageUrl != null && imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _ImagePlaceholder(palette: palette),
                errorWidget: (context, url, error) => _ImageError(palette: palette, spacing: spacing),
              )
            else
              _ImagePlaceholder(palette: palette),

            // Discount Badge
            if (hasDiscount)
              Positioned(
                top: 6,
                left: 6,
                child: _DiscountBadge(
                  discountPercentage: discountPercentage!,
                  palette: palette,
                  typography: typography,
                  radius: radius,
                ),
              ),

            // Tag Badge (e.g., "NEW", "HOT")
            if (tags.isNotEmpty && !hasDiscount)
              Positioned(
                top: 6,
                left: 6,
                child: _TagBadge(
                  tag: tags.first.toUpperCase(),
                  palette: palette,
                  typography: typography,
                  radius: radius,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.surface,
      child: Center(
        child: CircularProgressSpinner(color: palette.brand, size: 24, strokeWidth: 2),
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError({required this.palette, required this.spacing});

  final AppPalette palette;
  final Spacing spacing;

  @override
  Widget build(BuildContext context) {
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

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({
    required this.discountPercentage,
    required this.palette,
    required this.typography,
    required this.radius,
  });

  final double discountPercentage;
  final AppPalette palette;
  final TypographyScale typography;
  final RadiusScale radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: palette.danger,
        borderRadius: radius.all(radius.xs),
      ),
      child: Text(
        '-${discountPercentage.toInt()}%',
        style: typography.labelSmall.toTextStyle(color: Colors.white),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({
    required this.tag,
    required this.palette,
    required this.typography,
    required this.radius,
  });

  final String tag;
  final AppPalette palette;
  final TypographyScale typography;
  final RadiusScale radius;

  @override
  Widget build(BuildContext context) {
    // Different colors for different tags
    Color badgeColor;
    switch (tag.toLowerCase()) {
      case 'new':
        badgeColor = palette.brand;
      case 'hot':
        badgeColor = palette.warning;
      case 'sale':
        badgeColor = palette.danger;
      default:
        badgeColor = palette.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: radius.all(radius.xs),
      ),
      child: Text(
        tag,
        style: typography.labelSmall.toTextStyle(color: Colors.white),
      ),
    );
  }
}

class _PriceSection extends StatelessWidget {
  const _PriceSection({
    required this.hasDiscount,
    required this.discountedPrice,
    required this.originalPrice,
    required this.palette,
    required this.typography,
  });

  final bool hasDiscount;
  final double discountedPrice;
  final double originalPrice;
  final AppPalette palette;
  final TypographyScale typography;

  @override
  Widget build(BuildContext context) {
    // Compact price display - horizontal when discounted
    if (hasDiscount) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Current Price
          Flexible(
            child: Text(
              '\$${discountedPrice.toStringAsFixed(2)}',
              style: typography.labelLarge.toTextStyle(color: palette.danger),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          // Original Price (strikethrough)
          Flexible(
            child: Text(
              '\$${originalPrice.toStringAsFixed(2)}',
              style: typography.labelSmall.toTextStyle(color: palette.weak).copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: palette.weak,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    // Single price display
    return Text(
      '\$${originalPrice.toStringAsFixed(2)}',
      style: typography.labelLarge.toTextStyle(color: palette.danger),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
