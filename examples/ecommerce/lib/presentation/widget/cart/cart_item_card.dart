import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/cart_remove_item_request.dart';
import 'package:ecommerce/api/models/cart_response.dart';
import 'package:ecommerce/api/models/cart_update_item_request.dart';
import 'package:ecommerce/api/models/items.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/cart_service.dart';
import 'package:ecommerce/core/widgets/card.dart';
import 'package:ecommerce/core/widgets/number_stepper.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class CartItemCard extends StatelessWidget {
  const CartItemCard({
    super.key,
    required this.item,
  });

  final Items item;

  String get _itemId {
    return item.item.id;
  }

  int get _quantity {
    final quantity = item.item.quantity;
    if (quantity is int) {
      return quantity;
    }
    return quantity.toInt();
  }

  String get _priceAtAdd {
    return item.item.priceAtAdd;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    final product = item.product;
    final variant = item.variant;
    final quantity = _quantity;
    final priceAtAdd = double.tryParse(_priceAtAdd) ?? 0.0;
    final itemTotal = priceAtAdd * quantity;

    return AppCard(
      onClick: () => context.router.push(ProductDetailRoute(id: product.id)),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(context.radius.sm),
              child: SizedBox(
                width: 80,
                height: 80,
                child: ColoredBox(
                  color: palette.weak,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: palette.textSecondary,
                    size: 24,
                  ),
                ),
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: typography.bodyMedium
                        .toTextStyle(color: palette.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.xs / 2),
                  Text(
                    variant.name,
                    style: typography.bodySmall.toTextStyle(color: palette.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    '\$${priceAtAdd.toStringAsFixed(2)}',
                    style:
                        typography.bodyMedium.toTextStyle(color: palette.brand).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            _DeleteButton(itemId: _itemId),
          ],
        ),
        SizedBox(height: spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuantityStepper(
              itemId: _itemId,
              currentQuantity: quantity,
              maxQuantity: variant.inventoryQuantity.toInt(),
            ),
            Text(
              'Total: \$${itemTotal.toStringAsFixed(2)}',
              style: typography.bodyLarge.toTextStyle(color: palette.textPrimary).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.itemId,
    required this.currentQuantity,
    required this.maxQuantity,
  });

  final String itemId;
  final int currentQuantity;
  final int maxQuantity;

  @override
  Widget build(BuildContext context) {
    final cartService = locator.get<CartService>();

    return MutationBuilder<CartResponse, CartUpdateItemRequest>(
      mutationFn: (request) => cartService.updateItem(
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
        final palette = context.palette;
        return Stack(
          alignment: Alignment.center,
          children: [
            NumberStepper(
              value: currentQuantity,
              min: 1,
              max: maxQuantity,
              step: 1,
              disabled: state.isLoading,
              onChanged: (value) async {
                if (value != null && value != currentQuantity) {
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
                  color: palette.background.withValues(alpha: 0.7),
                  child: Center(
                    child: CircularProgressSpinner(
                      color: palette.brand,
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
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.itemId,
  });

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final cartService = locator.get<CartService>();

    return MutationBuilder<CartResponse, CartRemoveItemRequest>(
      mutationFn: (request) => cartService.removeItem(id: request.id),
      options: MutationOptions(
        meta: const MutationMeta(
          successMessage: 'Item removed from cart',
          errorMessage: 'Failed to remove item',
        ),
        onSuccess: (data) {
          final queryClient = context.queryClient;
          if (queryClient != null) {
            queryClient.setQueryData(QueryKeys.cart, data);
          }
        },
      ),
      builder: (context, state, mutate) {
        return IconButton(
          onPressed: state.isLoading
              ? null
              : () async {
                  final request = CartRemoveItemRequest(id: itemId);
                  await mutate(request);
                },
          icon: state.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressSpinner(
                    color: context.palette.danger,
                    size: 20,
                    strokeWidth: 2,
                  ),
                )
              : SvgIcon(
                  svg: Assets.icons.outlined.delete,
                  size: 20,
                  color: context.palette.danger,
                ),
        );
      },
    );
  }
}
