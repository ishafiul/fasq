import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/category_tree_node.dart';
import 'package:ecommerce/api/models/children3.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/category_service.dart';
import 'package:ecommerce/core/widgets/collapse.dart';
import 'package:ecommerce/core/widgets/no_data.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

@RoutePage()
class CategoriesListScreen extends StatelessWidget {
  const CategoriesListScreen({super.key});

  /// Flattens all nested children recursively into a single list.
  ///
  /// Handles the nested structure: CategoryTreeNode -> Children3 -> Children2 -> Children
  static List<_FlattenedCategory> _flattenChildren(
    List<Children3> children3,
  ) {
    final List<_FlattenedCategory> result = [];

    for (final child3 in children3) {
      // Add the Children3 itself
      result.add(_FlattenedCategory(
        id: child3.id,
        name: child3.name,
        description: child3.description,
        imageUrl: child3.imageUrl,
      ));

      // Flatten Children2
      for (final child2 in child3.children) {
        // Add the Children2 itself
        result.add(_FlattenedCategory(
          id: child2.id,
          name: child2.name,
          description: child2.description,
          imageUrl: child2.imageUrl,
        ));

        // Flatten Children
        for (final child in child2.children) {
          // Add the Children itself
          result.add(_FlattenedCategory(
            id: child.id,
            name: child.name,
            description: child.description,
            imageUrl: child.imageUrl,
          ));
        }
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'All Categories',
          style: typography.titleLarge.toTextStyle(),
        ),
      ),
      body: QueryBuilder<List<CategoryTreeNode>>(
        queryKey: QueryKeys.categoryTree,
        queryFn: () => locator.get<CategoryService>().getCategoryTree(),
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressSpinner(),
            );
          }

          if (state.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const NoData(message: 'Failed to load categories'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.queryClient?.invalidateQuery(QueryKeys.categoryTree);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final categories = state.data ?? [];

          if (categories.isEmpty) {
            return const Center(
              child: NoData(message: 'No categories available'),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(spacing.sm),
            child: Collapse(
              accordion: false,
              items: categories.map((category) {
                final flattenedChildren = _flattenChildren(category.children);

                // Build children list - only include flattened children (not the top-level category itself)
                final List<Widget> childrenList = [];
                for (var i = 0; i < flattenedChildren.length; i++) {
                  final child = flattenedChildren[i];
                  childrenList.add(
                    _CategoryChildItem(
                      categoryId: child.id,
                      name: child.name,
                      description: child.description,
                      imageUrl: child.imageUrl,
                    ),
                  );
                  // Add divider between items (except after the last one)
                  if (i < flattenedChildren.length - 1) {
                    childrenList.add(
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: context.palette.border,
                      ),
                    );
                  }
                }

                final hasChildren = childrenList.isNotEmpty;

                return CollapsePanel(
                  key: category.id,
                  title: _CategoryTitle(
                    name: category.name,
                    imageUrl: category.imageUrl,
                    description: category.description,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: childrenList,
                  ),
                  forceRender: hasChildren,
                  disabled: !hasChildren,
                  arrowIcon: hasChildren ? null : const SizedBox.shrink(),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

/// Represents a flattened category item from the nested tree structure.
class _FlattenedCategory {
  const _FlattenedCategory({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
}

/// Title widget for a category in the collapse panel.
class _CategoryTitle extends StatelessWidget {
  const _CategoryTitle({
    required this.name,
    this.imageUrl,
    this.description,
  });

  final String name;
  final String? imageUrl;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;
    final radius = context.radius;

    return Row(
      children: [
        if (imageUrl != null && imageUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: radius.all(radius.xs),
            child: CachedNetworkImage(
              imageUrl: imageUrl!,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 32,
                height: 32,
                color: palette.weak,
                child: Center(
                  child: CircularProgressSpinner(
                    color: palette.brand,
                    size: 16,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 32,
                height: 32,
                color: palette.weak,
                child: Icon(
                  Icons.category_outlined,
                  color: palette.weak,
                  size: 16,
                ),
              ),
            ),
          )
        else
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: palette.weak,
              borderRadius: radius.all(radius.xs),
            ),
            child: Icon(
              Icons.category_outlined,
              color: palette.textSecondary,
              size: 16,
            ),
          ),
        SizedBox(width: spacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: typography.bodyMedium
                    .toTextStyle(
                      color: palette.textPrimary,
                    )
                    .copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (description != null && description!.isNotEmpty) ...[
                SizedBox(height: spacing.xs / 2),
                Text(
                  description!,
                  style: typography.bodySmall.toTextStyle(
                    color: palette.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// List item widget for a child category (used in collapse panels).
class _CategoryChildItem extends StatelessWidget {
  const _CategoryChildItem({
    required this.categoryId,
    required this.name,
    this.description,
    this.imageUrl,
  });

  final String categoryId;
  final String name;
  final String? description;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;
    final radius = context.radius;
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.router.push(CategoryRoute(id: categoryId));
        },
        splashColor: colors.primary.withValues(alpha: 0.08),
        highlightColor: colors.primary.withValues(alpha: 0.04),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xs,
          ),
          child: Row(
            children: [
              if (imageUrl != null && imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: radius.all(radius.xs),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 32,
                      height: 32,
                      color: palette.weak,
                      child: Center(
                        child: CircularProgressSpinner(
                          color: palette.brand,
                          size: 16,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 32,
                      height: 32,
                      color: palette.weak,
                      child: Icon(
                        Icons.category_outlined,
                        color: palette.weak,
                        size: 16,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: palette.weak,
                    borderRadius: radius.all(radius.xs),
                  ),
                  child: Icon(
                    Icons.category_outlined,
                    color: palette.textSecondary,
                    size: 16,
                  ),
                ),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: typography.bodyMedium.toTextStyle(
                        color: palette.textPrimary,
                      ),
                    ),
                    if (description != null && description!.isNotEmpty) ...[
                      SizedBox(height: spacing.xs / 2),
                      Text(
                        description!,
                        style: typography.bodySmall.toTextStyle(
                          color: palette.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
