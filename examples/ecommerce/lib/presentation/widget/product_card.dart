import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/product_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';

/// A card widget that displays product information.
///
/// This widget shows:
/// - Product image
/// - Product name
/// - Price
/// - Add to cart button
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap, this.onAddToCart});

  final ProductResponse? product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final radius = context.radius;

    // Extract product data (handling dynamic type)
    // When product is empty (loading state), use empty strings for shimmer effect
    final productName = product?.name;
    final basePrice = product?.basePrice;

    // Get image URL from images array (new structure) or fallback to imageUrl (old structure)
    final imageUrl = product?.images.first.url;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius.all(radius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: radius.top(radius.md),
              child: AspectRatio(
                aspectRatio: 1,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: palette.weak,
                          child: Center(child: CircularProgressIndicator(color: palette.brand, strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: palette.weak,
                          child: Icon(Icons.image_not_supported, color: palette.textSecondary, size: spacing.md),
                        ),
                      )
                    : Container(
                        color: palette.weak,
                        child: Icon(Icons.image, color: palette.textSecondary, size: spacing.md),
                      ),
              ),
            ),
            // Product Info
            Padding(
              padding: EdgeInsets.all(spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    productName ?? '',
                    style: typography.bodyMedium.toTextStyle(color: palette.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.xs),
                  Text('\$$basePrice', style: typography.titleMedium.toTextStyle(color: palette.brand))
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
