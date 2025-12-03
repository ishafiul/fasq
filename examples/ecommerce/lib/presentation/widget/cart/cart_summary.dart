import 'package:ecommerce/api/models/cart_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/card.dart';
import 'package:flutter/material.dart';

class CartSummary extends StatelessWidget {
  const CartSummary({
    super.key,
    required this.cartResponse,
  });

  final CartResponse cartResponse;

  double get _subtotal {
    double total = 0.0;
    for (final item in cartResponse.items) {
      final itemMap = item.item;
      final quantity = itemMap.quantity;
      final priceAtAdd = itemMap.priceAtAdd;
      final price = double.tryParse(priceAtAdd) ?? 0.0;
      total += price * quantity;
    }
    return total;
  }

  double get _tax {
    return _subtotal * 0.1;
  }

  double get _total {
    return _subtotal + _tax;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    return AppCard(
      children: [
        _SummaryRow(
          label: 'Subtotal',
          value: _subtotal,
        ),
        SizedBox(height: spacing.xs),
        _SummaryRow(
          label: 'Tax',
          value: _tax,
        ),
        SizedBox(height: spacing.sm),
        Divider(color: palette.border),
        SizedBox(height: spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style:
                  typography.titleMedium.toTextStyle(color: palette.textPrimary).copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '\$${_total.toStringAsFixed(2)}',
              style: typography.titleLarge.toTextStyle(color: palette.brand).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final palette = context.palette;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
        ),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: typography.bodyMedium.toTextStyle(color: palette.textPrimary).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
