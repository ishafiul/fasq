import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/category_tree_node.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/category_service.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

/// A horizontal scrollable section displaying product categories.
class CategorySection extends StatelessWidget {
  const CategorySection({super.key, this.onCategoryTap});

  final ValueChanged<CategoryTreeNode?>? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final radius = context.radius;

    return Shimmer(
      child: QueryBuilder<List<CategoryTreeNode>>(
        queryKey: QueryKeys.categoryTree,
        queryFn: () => locator.get<CategoryService>().getCategoryTree(),
        builder: (context, state) {
          if (state.hasError) {
            return SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'Failed to load categories',
                  style: typography.bodySmall.toTextStyle(color: palette.danger),
                ),
              ),
            );
          }

          final categories = state.data ?? [];
          final isLoading = state.isLoading;
          final itemCount = isLoading ? 6 : categories.length;

          if (!isLoading && categories.isEmpty) {
            return const SizedBox.shrink();
          }

          return SizedBox(
            height: 100,
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(left: spacing.sm),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      // Create mock category data when loading
                      final category = isLoading ? null : categories[index];

                      return ShimmerLoading(
                        isLoading: isLoading,
                        child: _CategoryCard(
                          category: category,
                          onTap: isLoading
                              ? () {}
                              : () {
                                  if (category != null) {
                                    if (onCategoryTap != null) {
                                      onCategoryTap?.call(category);
                                    } else {
                                      context.router.push(CategoryRoute(id: category.id));
                                    }
                                  }
                                },
                          palette: palette,
                          spacing: spacing,
                          typography: typography,
                          radius: radius,
                        ),
                      );
                    },
                  ),
                ),
                if (!isLoading)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                    child: _SeeAllButton(
                      onTap: () {
                        context.router.push(const CategoriesListRoute());
                      },
                      palette: palette,
                      spacing: spacing,
                      typography: typography,
                      radius: radius,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
    required this.palette,
    required this.spacing,
    required this.typography,
    required this.radius,
  });

  final CategoryTreeNode? category;
  final VoidCallback onTap;
  final AppPalette palette;
  final Spacing spacing;
  final TypographyScale typography;
  final RadiusScale radius;

  @override
  Widget build(BuildContext context) {
    final categoryName = category?.name;
    final imageUrl = category?.imageUrl;

    return Padding(
      padding: EdgeInsets.only(right: spacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius.all(radius.md),
        child: Container(
          width: 80,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: radius.all(radius.md),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Category Image
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: radius.all(radius.sm),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 40,
                      height: 40,
                      color: palette.weak,
                      child: Icon(Icons.image, size: spacing.sm, color: palette.textSecondary),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 40,
                      height: 40,
                      color: palette.weak,
                      child: Icon(Icons.image_not_supported, size: spacing.sm, color: palette.textSecondary),
                    ),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: palette.weak, borderRadius: radius.all(radius.sm)),
                  child: Icon(Icons.category, size: spacing.sm, color: palette.textSecondary),
                ),
              SizedBox(height: spacing.xs),
              // Category Name
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.xs),
                child: Text(
                  categoryName ?? '',
                  style: typography.bodySmall.toTextStyle(color: palette.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({
    required this.onTap,
    required this.palette,
    required this.spacing,
    required this.typography,
    required this.radius,
  });

  final VoidCallback onTap;
  final AppPalette palette;
  final Spacing spacing;
  final TypographyScale typography;
  final RadiusScale radius;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: radius.all(radius.md),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: palette.brand,
          borderRadius: radius.all(radius.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.arrow_forward,
              color: palette.surface,
              size: 24,
            ),
            SizedBox(height: spacing.xs),
            Text(
              'See All',
              style: typography.bodySmall
                  .toTextStyle(
                    color: palette.surface,
                  )
                  .copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
