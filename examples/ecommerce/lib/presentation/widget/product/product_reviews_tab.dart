import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/review_service.dart';
import 'package:ecommerce/core/widgets/no_data.dart';
import 'package:ecommerce/core/widgets/rating.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/presentation/widget/review/review_item.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class ProductReviewsTab extends StatelessWidget {
  const ProductReviewsTab({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(context.spacing.sm),
          sliver: SliverToBoxAdapter(
            child: _ReviewsSection(productId: productId),
          ),
        ),
      ],
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    return QueryBuilder(
      queryKey: QueryKeys.productReviews(productId),
      queryFn: () => locator.get<ReviewService>().getProductReviews(productId),
      builder: (context, state) {
        if (state.hasError || state.data == null) {
          return const SizedBox.shrink();
        }

        final reviewsData = state.data;
        final reviews = reviewsData?.data ?? [];
        final rating = reviewsData?.rating;
        final isLoading = state.isLoading;

        return ShimmerLoading(
          isLoading: isLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rating != null ? 'Reviews (${rating.totalReviews.toInt()})' : 'Reviews (0)',
                style: typography.titleSmall.toTextStyle(
                  color: palette.textPrimary,
                ),
              ),
              SizedBox(height: spacing.sm),
              if (rating != null)
                Row(
                  children: [
                    Rating(
                      value: rating.averageRating.toDouble(),
                      readOnly: true,
                      starSize: 18,
                    ),
                    SizedBox(width: spacing.sm),
                    Text(
                      rating.averageRating.toStringAsFixed(1),
                      style: typography.bodyLarge
                          .toTextStyle(
                            color: palette.textPrimary,
                          )
                          .copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    const Rating(
                      value: 0,
                      readOnly: true,
                      starSize: 18,
                    ),
                    SizedBox(width: spacing.sm),
                    Text(
                      '0.0',
                      style: typography.bodyLarge
                          .toTextStyle(
                            color: palette.textPrimary,
                          )
                          .copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              SizedBox(height: spacing.md),
              if (reviews.isEmpty)
                Padding(
                  padding: EdgeInsets.all(spacing.xxl),
                  child: const Center(
                    child: NoData(message: 'No reviews yet'),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) => ReviewItem(review: reviews[index]),
                  separatorBuilder: (context, index) => const Divider(height: 1),
                ),
            ],
          ),
        );
      },
    );
  }
}
