import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/category_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:flutter/material.dart';

class CategoryInfoCard extends StatelessWidget {
  const CategoryInfoCard({
    super.key,
    required this.category,
  });

  final CategoryResponse? category;

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
          if (category?.imageUrl != null && category!.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: radius.all(radius.sm),
              child: CachedNetworkImage(
                imageUrl: category!.imageUrl!,
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
                    Icons.category_outlined,
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
                Icons.category_outlined,
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
                  category?.name ?? 'Category Name',
                  style: typography.titleMedium.toTextStyle(color: palette.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (category?.description != null && category!.description!.isNotEmpty) ...[
                  SizedBox(height: spacing.xs / 2),
                  Text(
                    category!.description!,
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

