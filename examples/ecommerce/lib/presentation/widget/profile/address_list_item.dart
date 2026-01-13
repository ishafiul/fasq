import 'package:ecommerce/api/models/address_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';

class AddressListItem extends StatelessWidget {
  const AddressListItem({
    super.key,
    required this.address,
    this.isDefault = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onSetDefault,
  });

  final AddressResponse address;
  final bool isDefault;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;

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
                children: [
                  if (isDefault)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.xs,
                        vertical: spacing.xs / 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.brand,
                        borderRadius: BorderRadius.circular(context.radius.xs),
                      ),
                      child: Text(
                        'DEFAULT',
                        style: typography.labelSmall.toTextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (isDefault) SizedBox(width: spacing.xs),
                  Expanded(
                    child: Text(
                      _getAddressDisplay(),
                      style: typography.bodyLarge.toTextStyle(
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isDefault && onSetDefault != null)
                    TextButton(
                      onPressed: onSetDefault,
                      child: Text(
                        'Set as Default',
                        style: typography.bodySmall.toTextStyle(
                          color: palette.brand,
                        ),
                      ),
                    ),
                  if (onEdit != null)
                    TextButton(
                      onPressed: onEdit,
                      child: Text(
                        'Edit',
                        style: typography.bodySmall.toTextStyle(
                          color: palette.brand,
                        ),
                      ),
                    ),
                  if (onDelete != null)
                    TextButton(
                      onPressed: onDelete,
                      child: Text(
                        'Delete',
                        style: typography.bodySmall.toTextStyle(
                          color: palette.danger,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAddressDisplay() {
    try {
      final json = address.toJson();
      final parts = <String>[];

      if (json['fullName'] != null) parts.add(json['fullName'].toString());
      if (json['addressLine1'] != null) parts.add(json['addressLine1'].toString());
      if (json['addressLine2'] != null && json['addressLine2'].toString().isNotEmpty) {
        parts.add(json['addressLine2'].toString());
      }
      if (json['city'] != null) parts.add(json['city'].toString());
      if (json['state'] != null) parts.add(json['state'].toString());
      if (json['postalCode'] != null) parts.add(json['postalCode'].toString());
      if (json['country'] != null) parts.add(json['country'].toString());

      return parts.join(', ');
    } catch (e) {
      return 'Address';
    }
  }
}
