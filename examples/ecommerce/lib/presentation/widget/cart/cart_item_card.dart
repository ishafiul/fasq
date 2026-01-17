import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/items.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/presentation/widget/product/product_cart_stepper.dart';
import 'package:ecommerce_ui/ecommerce_ui.dart';
import 'package:flutter/material.dart';

class CartItemCard extends StatelessWidget {
  const CartItemCard({
    super.key,
    required this.item,
  });

  final Items item;

  int get _quantity {
    final quantity = item.item.quantity;
    if (quantity is int) {
      return quantity;
    }
    return quantity.toInt();
  }

  String get _priceAtAdd {
    return item.item.priceAtAdd;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    final product = item.product;
    final variant = item.variant;
    final quantity = _quantity;
    final priceAtAdd = double.tryParse(_priceAtAdd) ?? 0.0;
    final itemTotal = priceAtAdd * quantity;

    return AppCard(
      onClick: () => context.router.push(ProductDetailRoute(id: product.id)),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(context.radius.sm),
              child: SizedBox(
                width: 80,
                height: 80,
                child: ColoredBox(
                  color: palette.weak,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: palette.textSecondary,
                    size: 24,
                  ),
                ),
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: typography.bodyMedium
                        .toTextStyle(color: palette.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.xs / 2),
                  Text(
                    variant.name,
                    style: typography.bodySmall.toTextStyle(color: palette.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    '\$${priceAtAdd.toStringAsFixed(2)}',
                    style:
                        typography.bodyMedium.toTextStyle(color: palette.brand).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ProductCartStepper(
              id: product.id,
              max: variant.inventoryQuantity.toInt(),
            ),
            Text(
              'Total: \$${itemTotal.toStringAsFixed(2)}',
              style: typography.bodyLarge.toTextStyle(color: palette.textPrimary).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}
