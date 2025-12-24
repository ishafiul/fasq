import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/cart_add_item_request.dart';
import 'package:ecommerce/api/models/cart_response.dart';
import 'package:ecommerce/api/models/cart_update_item_request.dart';
import 'package:ecommerce/api/models/product_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/cart_service.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/services/user_service.dart';
import 'package:ecommerce/core/widgets/badge.dart' as core;
import 'package:ecommerce/core/widgets/card.dart';
import 'package:ecommerce/core/widgets/number_stepper.dart';
import 'package:ecommerce/core/widgets/rating.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/core/widgets/tag.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

enum ProductTagType {
  new_,
  hot,
  sale,
  other;

  static ProductTagType fromString(String tag) {
    switch (tag.toLowerCase()) {
      case 'new':
        return ProductTagType.new_;
      case 'hot':
        return ProductTagType.hot;
      case 'sale':
        return ProductTagType.sale;
      default:
        return ProductTagType.other;
    }
  }
}

/// A card widget that displays product information following Ant Design mobile patterns.
///
/// Features:
/// - Clean, elevated card design with subtle shadows
/// - Product image with loading/error states
/// - Product name with proper truncation
/// - Price display with discount support
/// - Optional add to cart action
/// - Tags/badges for product status
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.discountPercentage,
    this.showAddToCart = true,
    this.rating,
  });

  final ProductResponse? product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final double? discountPercentage;
  final bool showAddToCart;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final radius = context.radius;

    final productName = product?.name ?? '';
    final basePrice = product?.basePrice ?? '0';
    final tags = product?.tags ?? [];

    // Get image URL from images array
    final imageUrl = product?.images.isNotEmpty == true ? product?.images.first.url : null;

    // Calculate discounted price if applicable
    final hasDiscount = discountPercentage != null && discountPercentage! > 0;
    final originalPrice = double.tryParse(basePrice) ?? 0;
    final discountedPrice = hasDiscount ? originalPrice * (1 - discountPercentage! / 100) : originalPrice;

    final colors = context.colors;

    return AppCard(
      onClick: onTap ?? (product != null ? () => context.router.push(ProductDetailRoute(id: product!.id)) : null),
      padding: EdgeInsets.zero,
      borderRadius: radius.all(radius.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius.all(radius.md),
        border: Border.all(
          color: palette.border,
        ),
      ),
      bodyStyle: const BoxDecoration(),
      bodyMainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          flex: 5,
          child: _ProductImage(
            imageUrl: imageUrl,
            hasDiscount: hasDiscount,
            discountPercentage: discountPercentage,
            tags: tags,
          ),
        ),
        Padding(
          padding: EdgeInsets.all(spacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                productName,
                style: typography.bodyMedium
                    .toTextStyle(
                      color: palette.textPrimary,
                    )
                    .copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Rating(
                value: 3.5,
                readOnly: true,
                starSize: 14,
              ),
              const SizedBox(height: 2),
              _PriceSection(
                hasDiscount: hasDiscount,
                discountedPrice: discountedPrice,
                originalPrice: originalPrice,
              ),
              if (showAddToCart) ...[
                SizedBox(height: spacing.xs / 2),
                GestureDetector(
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: _ProductCartStepper(product: product),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.hasDiscount,
    required this.discountPercentage,
    required this.tags,
  });

  final String? imageUrl;
  final bool hasDiscount;
  final double? discountPercentage;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final radius = context.radius;
    final palette = context.palette;
    final typography = context.typography;
    return ClipRRect(
      borderRadius: radius.top(radius.md),
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            if (imageUrl != null && imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const _ImagePlaceholder(),
                errorWidget: (context, url, error) => const _ImageError(),
              )
            else
              const _ImagePlaceholder(),

            // Discount Badge
            if (hasDiscount)
              Positioned(
                top: 6,
                left: 6,
                child: core.Badge(
                  color: palette.danger,
                  content: Text(
                    '-${discountPercentage!.toInt()}%',
                    style: typography.labelSmall.toTextStyle(
                      color: ColorUtils.onColor(palette.danger),
                    ),
                  ),
                ),
              ),

            // Tag Badge (e.g., "NEW", "HOT")
            if (tags.isNotEmpty && !hasDiscount)
              Positioned(
                top: 6,
                left: 6,
                child: _ProductTag(tag: tags.first.toUpperCase()),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ColoredBox(
      color: palette.surface,
      child: Center(
        child: CircularProgressSpinner(color: palette.brand, size: 24, strokeWidth: 2),
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    return ColoredBox(
      color: palette.surface,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: palette.weak,
        size: spacing.lg,
      ),
    );
  }
}

class _ProductTag extends StatelessWidget {
  const _ProductTag({
    required this.tag,
  });

  final String tag;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tagType = ProductTagType.fromString(tag);

    final TagColor tagColor;
    final Color? customColor;

    switch (tagType) {
      case ProductTagType.new_:
        tagColor = TagColor.default_;
        customColor = palette.brand;
      case ProductTagType.hot:
        tagColor = TagColor.warning;
        customColor = null;
      case ProductTagType.sale:
        tagColor = TagColor.danger;
        customColor = null;
      case ProductTagType.other:
        tagColor = TagColor.primary;
        customColor = null;
    }

    return Tag(
      color: tagColor,
      customColor: customColor,
      child: Text(tag),
    );
  }
}

class _PriceSection extends StatelessWidget {
  const _PriceSection({
    required this.hasDiscount,
    required this.discountedPrice,
    required this.originalPrice,
  });

  final bool hasDiscount;
  final double discountedPrice;
  final double originalPrice;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typography = context.typography;

    if (hasDiscount) {
      return Row(
        children: [
          Flexible(
            child: Text(
              '\$${discountedPrice.toStringAsFixed(2)}',
              style: typography.bodySmall.toTextStyle(color: palette.textPrimary).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '\$${originalPrice.toStringAsFixed(2)}',
              style: typography.bodyMedium.toTextStyle(color: palette.textSecondary).copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: palette.textSecondary,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Text(
      '\$${originalPrice.toStringAsFixed(2)}',
      style: typography.bodyMedium.toTextStyle(color: palette.textPrimary).copyWith(
            fontWeight: FontWeight.w600,
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A modern horizontal product card for horizontal scrolling lists.
///
/// Follows Ant Design mobile patterns with:
/// - Clean, modern card design with proper spacing
/// - Optimized image presentation with better aspect ratio
/// - Clear visual hierarchy and typography
/// - Refined shadows and borders
/// - Optimized for horizontal scrolling
/// - Reuses private widgets from ProductCard
class ProductCardHorizontal extends StatelessWidget {
  const ProductCardHorizontal({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.discountPercentage,
    this.showAddToCart = true,
    this.rating,
  });

  final ProductResponse? product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final double? discountPercentage;
  final bool showAddToCart;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final radius = context.radius;

    final productName = product?.name ?? '';
    final basePrice = product?.basePrice ?? '0';
    final tags = product?.tags ?? [];

    final imageUrl = product?.images.isNotEmpty == true ? product?.images.first.url : null;

    final hasDiscount = discountPercentage != null && discountPercentage! > 0;
    final originalPrice = double.tryParse(basePrice) ?? 0;
    final discountedPrice = hasDiscount ? originalPrice * (1 - discountPercentage! / 100) : originalPrice;

    final colors = context.colors;
    final hasImage = imageUrl?.isNotEmpty ?? false;
    final finalImageUrl = hasImage ? imageUrl : null;

    return AppCard(
      onClick: onTap ?? (product != null ? () => context.router.push(ProductDetailRoute(id: product!.id)) : null),
      padding: EdgeInsets.all(spacing.sm),
      borderRadius: radius.all(radius.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius.all(radius.md),
        border: Border.all(
          color: palette.border,
        ),
      ),
      bodyStyle: const BoxDecoration(),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductImageHorizontal(
              imageUrl: finalImageUrl,
              hasDiscount: hasDiscount,
              discountPercentage: discountPercentage,
              tags: tags,
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    productName,
                    style: typography.bodyMedium
                        .toTextStyle(
                          color: palette.textPrimary,
                        )
                        .copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Rating(
                    value: 3.5,
                    readOnly: true,
                    starSize: 14,
                  ),
                  _PriceSectionHorizontal(
                    hasDiscount: hasDiscount,
                    discountedPrice: discountedPrice,
                    originalPrice: originalPrice,
                  ),
                  if (showAddToCart) ...[
                    GestureDetector(
                      onTap: () {},
                      behavior: HitTestBehavior.opaque,
                      child: _ProductCartStepper(product: product),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProductImageHorizontal extends StatelessWidget {
  const _ProductImageHorizontal({
    required this.imageUrl,
    required this.hasDiscount,
    required this.discountPercentage,
    required this.tags,
  });

  final String? imageUrl;
  final bool hasDiscount;
  final double? discountPercentage;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final radius = context.radius;
    final palette = context.palette;
    final typography = context.typography;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: radius.all(radius.sm),
        color: palette.weak.withValues(alpha: 0.08),
      ),
      child: ClipRRect(
        borderRadius: radius.all(radius.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const _ImagePlaceholder(),
                errorWidget: (context, url, error) => const _ImageError(),
              )
            else
              const _ImagePlaceholder(),
            if (hasDiscount && discountPercentage != null)
              Positioned(
                top: 8,
                left: 8,
                child: core.Badge(
                  color: palette.danger,
                  content: Text(
                    '-${discountPercentage!.toInt()}%',
                    style: typography.labelSmall.toTextStyle(
                      color: ColorUtils.onColor(palette.danger),
                    ),
                  ),
                ),
              ),
            if (tags.isNotEmpty && !hasDiscount)
              Positioned(
                top: 8,
                left: 8,
                child: _ProductTag(tag: tags.first.toUpperCase()),
              ),
          ],
        ),
      ),
    );
  }
}

class _PriceSectionHorizontal extends StatelessWidget {
  const _PriceSectionHorizontal({
    required this.hasDiscount,
    required this.discountedPrice,
    required this.originalPrice,
  });

  final bool hasDiscount;
  final double discountedPrice;
  final double originalPrice;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typography = context.typography;

    if (hasDiscount) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${discountedPrice.toStringAsFixed(2)}',
                style: typography.bodySmall
                    .toTextStyle(
                      color: palette.textPrimary,
                    )
                    .copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 6),
              Text(
                '\$${originalPrice.toStringAsFixed(2)}',
                style: typography.bodyMedium
                    .toTextStyle(
                      color: palette.textSecondary,
                    )
                    .copyWith(
                      decoration: TextDecoration.lineThrough,
                      decorationColor: palette.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      );
    }

    return Text(
      '\$${originalPrice.toStringAsFixed(2)}',
      style: typography.bodyMedium
          .toTextStyle(
            color: palette.textPrimary,
          )
          .copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _ProductCartStepper extends StatelessWidget {
  const _ProductCartStepper({
    required this.product,
  });

  final ProductResponse? product;

  @override
  Widget build(BuildContext context) {
    if (product == null) {
      return const SizedBox.shrink();
    }

    return QueryBuilder<bool>(
      queryKey: QueryKeys.isLoggedIn,
      queryFn: () => locator.get<UserService>().isLoggedIn(),
      builder: (context, authState) {
        if (authState.isLoading || authState.data != true) {
          return NumberStepper(
            value: 0,
            min: 0,
            max: 999,
            step: 1,
            compact: true,
            onChanged: (value) {
              if (value != null && value > 0) {
                context.router.push(ProductDetailRoute(id: product!.id));
              }
            },
          );
        }

        return QueryBuilder<CartResponse>(
          queryKey: QueryKeys.cart,
          queryFn: () => locator.get<CartService>().getCart(),
          options: QueryOptions(
            staleTime: const Duration(seconds: 30),
            cacheTime: const Duration(minutes: 5),
          ),
          builder: (context, cartState) {
            final cartItems = cartState.data?.items ?? [];
            final productItems = cartItems.where((item) => item.product.id == product!.id).toList();

            final currentQuantity = productItems.fold<int>(
              0,
              (sum, item) {
                final quantity = item.item.quantity;
                final qty = quantity is int ? quantity : quantity.toInt();
                return sum + qty;
              },
            );

            if (currentQuantity == 0) {
              return MutationBuilder<CartResponse, CartAddItemRequest>(
                mutationFn: (request) => locator.get<CartService>().addItem(
                      productId: request.productId,
                      variantId: request.variantId,
                      quantity: request.quantity,
                      priceAtAdd: request.priceAtAdd,
                    ),
                options: MutationOptions(
                  meta: const MutationMeta(
                    successMessage: 'Item added to cart',
                    errorMessage: 'Failed to add item to cart',
                  ),
                  onSuccess: (data) {
                    final queryClient = context.queryClient;
                    if (queryClient != null) {
                      queryClient.setQueryData(QueryKeys.cart, data);
                    }
                  },
                ),
                builder: (context, state, mutate) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      NumberStepper(
                        value: 0,
                        min: 0,
                        max: 999,
                        step: 1,
                        compact: true,
                        disabled: state.isLoading,
                        onChanged: (value) async {
                          if (value == null || value <= 0) return;

                          final productService = locator.get<ProductService>();
                          try {
                            final productDetail = await productService.getProductById(product!.id);
                            final variants = productDetail.variants;

                            if (variants.isEmpty) {
                              if (context.mounted) {
                                context.router.push(ProductDetailRoute(id: product!.id));
                              }
                              return;
                            }

                            final availableVariant = variants.firstWhere(
                              (v) => v.inventoryQuantity > 0,
                              orElse: () => variants.first,
                            );

                            final request = CartAddItemRequest(
                              productId: product!.id,
                              variantId: availableVariant.id,
                              quantity: value.toInt(),
                              priceAtAdd: availableVariant.price,
                            );
                            await mutate(request);
                          } catch (e) {
                            if (context.mounted) {
                              context.router.push(ProductDetailRoute(id: product!.id));
                            }
                          }
                        },
                      ),
                      if (state.isLoading)
                        Positioned.fill(
                          child: ColoredBox(
                            color: context.palette.background.withValues(alpha: 0.7),
                            child: Center(
                              child: CircularProgressSpinner(
                                color: context.palette.brand,
                                size: 20,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            }

            final firstItem = productItems.first;
            final itemId = firstItem.item.id;
            final variant = firstItem.variant;
            final maxQuantity = variant.inventoryQuantity.toInt();

            return MutationBuilder<CartResponse, CartUpdateItemRequest>(
              mutationFn: (request) => locator.get<CartService>().updateItem(
                    id: request.id,
                    quantity: request.quantity,
                  ),
              options: MutationOptions(
                onSuccess: (data) {
                  final queryClient = context.queryClient;
                  if (queryClient != null) {
                    queryClient.setQueryData(QueryKeys.cart, data);
                  }
                },
              ),
              builder: (context, state, mutate) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    NumberStepper(
                      value: currentQuantity,
                      min: 0,
                      max: maxQuantity,
                      compact: true,
                      disabled: state.isLoading,
                      onChanged: (value) async {
                        if (value == null) return;

                        if (value == 0) {
                          final cartService = locator.get<CartService>();
                          await cartService.removeItem(id: itemId);
                          final queryClient = context.queryClient;
                          if (queryClient != null) {
                            final updatedCart = await cartService.getCart();
                            queryClient.setQueryData(QueryKeys.cart, updatedCart);
                          }
                        } else if (value != currentQuantity) {
                          final request = CartUpdateItemRequest(
                            id: itemId,
                            quantity: value.toInt(),
                          );
                          await mutate(request);
                        }
                      },
                    ),
                    if (state.isLoading)
                      Positioned.fill(
                        child: ColoredBox(
                          color: context.palette.background.withValues(alpha: 0.7),
                          child: Center(
                            child: CircularProgressSpinner(
                              color: context.palette.brand,
                              size: 20,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
