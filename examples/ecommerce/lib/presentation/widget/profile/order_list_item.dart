import 'package:ecommerce/api/models/order_list_item.dart' as api;
import 'package:ecommerce_ui/src/theme/colors.dart';
import 'package:ecommerce_ui/src/theme/const.dart';
import 'package:flutter/material.dart';

class OrderListItem extends StatelessWidget {
  const OrderListItem({
    super.key,
    required this.order,
    this.onTap,
  });

  final api.OrderListItem order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    return Card(
      margin: EdgeInsets.only(bottom: spacing.sm),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getOrderId(),
                    style: typography.titleMedium.toTextStyle(
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    _getOrderStatus() ?? 'Unknown',
                    style: typography.bodySmall.toTextStyle(
                      color: palette.brand,
                    ),
                  ),
                ],
              ),
              if (_getOrderDate() != null) ...[
                SizedBox(height: spacing.xs),
                Text(
                  _getOrderDate()!,
                  style: typography.bodySmall.toTextStyle(
                    color: palette.textSecondary,
                  ),
                ),
              ],
              if (_getOrderTotal() != null) ...[
                SizedBox(height: spacing.xs),
                Text(
                  _getOrderTotal()!,
                  style: typography.bodyLarge
                      .toTextStyle(
                        color: palette.textPrimary,
                      )
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getOrderId() {
    try {
      final json = order.toJson();
      return json['id']?.toString() ?? 'Order';
    } catch (e) {
      return 'Order';
    }
  }

  String? _getOrderStatus() {
    try {
      final json = order.toJson();
      return json['status']?.toString();
    } catch (e) {
      return null;
    }
  }

  String? _getOrderDate() {
    try {
      final json = order.toJson();
      final dateStr = json['createdAt']?.toString();
      if (dateStr != null) {
        return 'Ordered on ${dateStr}';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String? _getOrderTotal() {
    try {
      final json = order.toJson();
      final total = json['total']?.toString();
      if (total != null) {
        return 'Total: \$$total';
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
