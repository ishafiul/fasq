import 'package:ecommerce/api/models/product_response.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/presentation/widget/product_card.dart';
import 'package:flutter/material.dart';

/// A grid widget for displaying products.
///
/// This widget displays products in a grid layout with configurable columns.
/// Follows Ant Design mobile patterns for e-commerce product grids.
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.7,
    this.onProductTap,
    this.onAddToCart,
    this.isLoading = false,
    this.showAddToCart = true,
  });

  final List<ProductResponse> products;
  final int crossAxisCount;
  final double childAspectRatio;
  final ValueChanged<ProductResponse?>? onProductTap;
  final ValueChanged<ProductResponse?>? onAddToCart;
  final bool isLoading;
  final bool showAddToCart;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    if (!isLoading && products.isEmpty) {
      return const SizedBox.shrink();
    }

    final itemCount = isLoading ? 6 : products.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing.xs + 4,
        mainAxisSpacing: spacing.xs + 4,
      ),
      padding: EdgeInsets.symmetric(horizontal: spacing.sm),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Create mock product data when loading
        final product = isLoading ? null : products[index];

        return ShimmerLoading(
          isLoading: isLoading,
          child: ProductCard(
            product: product,
            onTap: isLoading ? null : () => onProductTap?.call(product),
            onAddToCart: isLoading ? null : () => onAddToCart?.call(product),
            showAddToCart: showAddToCart,
          ),
        );
      },
    );
  }
}
