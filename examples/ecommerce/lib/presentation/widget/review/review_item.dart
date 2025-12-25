import 'package:ecommerce/api/models/review_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/badge.dart' as core;
import 'package:ecommerce/core/widgets/rating.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:intl/intl.dart';

class ReviewItem extends StatelessWidget {
  const ReviewItem({
    super.key,
    required this.review,
  });

  final ReviewResponse review;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    final dateFormat = DateFormat('MMM dd, yyyy');
    final formattedDate = dateFormat.format(review.createdAt);

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(color: palette.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            review.title,
                            style: typography.bodyMedium.toTextStyle(color: palette.textPrimary).copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (review.isVerifiedPurchase)
                          Padding(
                            padding: EdgeInsets.only(left: spacing.xs),
                            child: core.Badge(
                              color: palette.success,
                              content: Text(
                                'Verified',
                                style: typography.labelSmall.toTextStyle(
                                  color: ColorUtils.onColor(palette.success),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: spacing.xs / 2),
                    Row(
                      children: [
                        Rating(
                          value: review.rating.toDouble(),
                          readOnly: true,
                          starSize: 16,
                        ),
                        SizedBox(width: spacing.xs),
                        Text(
                          formattedDate,
                          style: typography.labelSmall.toTextStyle(color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            SizedBox(height: spacing.sm),
            Text(
              review.comment!,
              style: typography.bodyMedium.toTextStyle(color: palette.textPrimary),
            ),
          ],
        ],
      ),
    );
  }
}
