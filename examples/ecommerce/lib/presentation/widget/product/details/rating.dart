import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/review_service.dart';
import 'package:ecommerce_ui/ecommerce_ui.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class RatingDisplay extends StatelessWidget {
  const RatingDisplay({
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final palette = context.palette;

    return Shimmer(
      child: QueryBuilder(
        queryKey: QueryKeys.productReviews(productId),
        queryFn: () => locator.get<ReviewService>().getProductReviews(productId, limit: 1),
        builder: (context, state) {
          if (state.hasError) {
            return const SizedBox.shrink();
          }

          final rating = state.data?.rating;
          final totalReviews = state.data?.meta.total ?? 0;

          if (rating == null) {
            return const SizedBox.shrink();
          }

          return ShimmerLoading.text(
            isLoading: state.isLoading,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 20,
                  color: palette.warning,
                ),
                SizedBox(width: context.spacing.xs / 2),
                Text(
                  rating.averageRating.toStringAsFixed(1),
                  style: typography.bodyMedium
                      .toTextStyle(
                        color: palette.textPrimary,
                      )
                      .copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (totalReviews > 0) ...[
                  SizedBox(width: context.spacing.xs),
                  Text(
                    '($totalReviews)',
                    style: typography.bodySmall.toTextStyle(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
