import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/number_stepper.dart';
import 'package:flutter/material.dart';

class ProductBottomActionBar extends StatefulWidget {
  const ProductBottomActionBar({
    super.key,
    required this.productId,
    this.isLoading = false,
    this.isOutOfStock = false,
    this.onAddToCart,
    this.maxQuantity,
  });

  final String productId;
  final bool isLoading;
  final bool isOutOfStock;
  final ValueChanged<int>? onAddToCart;
  final int? maxQuantity;

  @override
  State<ProductBottomActionBar> createState() => _ProductBottomActionBarState();
}

class _ProductBottomActionBarState extends State<ProductBottomActionBar> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;
    final colors = context.colors;

    final isDisabled = widget.isLoading || widget.isOutOfStock;

    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(spacing.sm),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: palette.border, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isLoading && widget.isOutOfStock)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.sm,
                  vertical: spacing.xs,
                ),
                margin: EdgeInsets.only(bottom: spacing.sm),
                decoration: BoxDecoration(
                  color: palette.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(context.radius.sm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
              ),
            Row(
              children: [
                NumberStepper(
                  value: _quantity,
                  min: 1,
                  max: widget.maxQuantity,
                  step: 1,
                  disabled: isDisabled,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _quantity = value.toInt();
                      });
                    }
                  },
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Button.primary(
                    onPressed: isDisabled ? null : () => widget.onAddToCart?.call(_quantity),
                    isBlock: true,
                    child: const Text('Add to Cart'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
