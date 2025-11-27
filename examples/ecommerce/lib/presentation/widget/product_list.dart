import 'package:ecommerce/api/models/product_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/presentation/widget/product_grid.dart';
import 'package:flutter/material.dart';

/// A widget for displaying a list of products with title and grid.
class ProductList extends StatelessWidget {
  const ProductList({
    super.key,
    required this.title,
    required this.products,
    this.crossAxisCount = 2,
    this.onProductTap,
    this.onAddToCart,
    this.onViewAll,
    this.isLoading = false,
  });

  final String title;
  final List<ProductResponse> products;
  final int crossAxisCount;
  final ValueChanged<ProductResponse?>? onProductTap;
  final ValueChanged<ProductResponse?>? onAddToCart;
  final VoidCallback? onViewAll;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    if (!isLoading && products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: typography.titleMedium.toTextStyle(color: palette.textPrimary),
              ),
              if (onViewAll != null && !isLoading)
                TextButton(
                  onPressed: onViewAll,
                  child: Text('View All', style: typography.bodyMedium.toTextStyle(color: palette.brand)),
                ),
            ],
          ),
        ),
        SizedBox(height: spacing.sm),
        // Product Grid
        ProductGrid(
          products: products,
          crossAxisCount: crossAxisCount,
          onProductTap: onProductTap,
          onAddToCart: onAddToCart,
          isLoading: isLoading,
        ),
        SizedBox(height: spacing.md),
      ],
    );
  }
}
