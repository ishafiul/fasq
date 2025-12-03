import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:flutter/material.dart';

class ProductBottomActionBar extends StatelessWidget {
  const ProductBottomActionBar({
    super.key,
    required this.productId,
    this.isLoading = false,
    this.onAddToCart,
    this.onBuyNow,
  });

  final String productId;
  final bool isLoading;
  final VoidCallback? onAddToCart;
  final VoidCallback? onBuyNow;

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
                onPressed: isLoading ? null : onAddToCart,
                isBlock: true,
                child: const Text('Add to Cart'),
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Button(
                onPressed: isLoading ? null : onBuyNow,
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

