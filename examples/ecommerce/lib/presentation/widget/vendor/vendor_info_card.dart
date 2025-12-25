import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/vendor_get_vendor_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:flutter/material.dart';

class VendorInfoCard extends StatelessWidget {
  const VendorInfoCard({
    super.key,
    required this.vendor,
  });

  final VendorGetVendorResponse vendor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius.all(radius.md),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          if (vendor.logo != null && vendor.logo!.isNotEmpty)
            ClipRRect(
              borderRadius: radius.all(radius.sm),
              child: CachedNetworkImage(
                imageUrl: vendor.logo!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 60,
                  height: 60,
                  color: palette.surface,
                  child: Center(
                    child: CircularProgressSpinner(color: palette.brand, size: 20, strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 60,
                  height: 60,
                  color: palette.surface,
                  child: Icon(
                    Icons.store_outlined,
                    color: palette.weak,
                    size: spacing.md,
                  ),
                ),
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: radius.all(radius.sm),
              ),
              child: Icon(
                Icons.store_outlined,
                color: palette.weak,
                size: spacing.md,
              ),
            ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vendor.businessName,
                  style: typography.titleMedium.toTextStyle(color: palette.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (vendor.description != null && vendor.description!.isNotEmpty) ...[
                  SizedBox(height: spacing.xs / 2),
                  Text(
                    vendor.description!,
                    style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
