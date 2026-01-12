import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/cart_add_item_request.dart';
import 'package:ecommerce/api/models/cart_response.dart';
import 'package:ecommerce/api/models/cart_update_item_request.dart';
import 'package:ecommerce/api/models/product_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/cart_service.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/services/user_service.dart';
import 'package:ecommerce/core/widgets/number_stepper.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class ProductCartStepper extends StatelessWidget {
  const ProductCartStepper({
    super.key,
    required this.product,
  });

  final ProductResponse? product;

  @override
  Widget build(BuildContext context) {
    final currentProduct = product;
    if (currentProduct == null) {
      return const SizedBox.shrink();
    }

    return QueryBuilder<bool>(
      queryKey: QueryKeys.isLoggedIn,
      queryFn: () => locator.get<UserService>().isLoggedIn(),
      builder: (context, authState) {
        if (authState.isLoading || authState.data != true) {
          return _UnauthenticatedStepper(product: currentProduct);
        }

        return _AuthenticatedCartStepper(product: currentProduct);
      },
    );
  }
}

class _UnauthenticatedStepper extends StatelessWidget {
  const _UnauthenticatedStepper({required this.product});

  final ProductResponse product;

  @override
  Widget build(BuildContext context) {
    return NumberStepper(
      value: 0,
      min: 0,
      max: 999,
      compact: true,
      onChanged: (value) {
        if (value != null && value > 0) {
          unawaited(context.router.push(const LoginRoute()));
        }
      },
    );
  }
}

class _AuthenticatedCartStepper extends StatelessWidget {
  const _AuthenticatedCartStepper({required this.product});

  final ProductResponse product;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<CartResponse>(
      queryKey: QueryKeys.cart,
      queryFn: () => locator.get<CartService>().getCart(),
      options: QueryOptions(
        staleTime: const Duration(seconds: 30),
        cacheTime: const Duration(minutes: 5),
      ),
      builder: (context, cartState) {
        final cartItems = cartState.data?.items ?? [];
        final productItems = cartItems.where((item) => item.product.id == product.id).toList();

        final currentQuantity = productItems.fold<int>(
          0,
          (sum, item) {
            final quantity = item.item.quantity;
            final qty = quantity is int ? quantity : quantity.toInt();
            return sum + qty;
          },
        );

        if (currentQuantity == 0) {
          return _AddToCartStepper(product: product);
        }

        final firstItem = productItems.first;
        return _UpdateCartStepper(
          product: product,
          itemId: firstItem.item.id,
          variantId: firstItem.variant.id,
          currentQuantity: currentQuantity,
          maxQuantity: firstItem.variant.inventoryQuantity.toInt(),
        );
      },
    );
  }
}

class _AddToCartStepper extends StatelessWidget {
  const _AddToCartStepper({required this.product});

  final ProductResponse product;

  @override
  Widget build(BuildContext context) {
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
          queryClient?.setQueryData(QueryKeys.cart, data);
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
              compact: true,
              disabled: state.isLoading,
              onChanged: (value) async {
                if (value == null || value <= 0) return;

                final productService = locator.get<ProductService>();
                final productId = product.id;
                final router = context.router;

                try {
                  final productDetail = await productService.getProductById(productId);
                  final variants = productDetail.variants;

                  if (variants.isEmpty) {
                    if (context.mounted) {
                      unawaited(
                        router.push(ProductDetailRoute(id: productId)),
                      );
                    }
                    return;
                  }

                  final availableVariant = variants.firstWhere(
                    (v) => v.inventoryQuantity > 0,
                    orElse: () => variants.first,
                  );

                  final request = CartAddItemRequest(
                    productId: productId,
                    variantId: availableVariant.id,
                    quantity: value.toInt(),
                    priceAtAdd: availableVariant.price,
                  );
                  await mutate(request);
                } catch (e) {
                  if (context.mounted) {
                    unawaited(router.push(ProductDetailRoute(id: productId)));
                  }
                }
              },
            ),
            if (state.isLoading) const _StepperLoadingOverlay(),
          ],
        );
      },
    );
  }
}

class _UpdateCartStepper extends StatelessWidget {
  const _UpdateCartStepper({
    required this.product,
    required this.itemId,
    required this.variantId,
    required this.currentQuantity,
    required this.maxQuantity,
  });

  final ProductResponse product;
  final String itemId;
  final String variantId;
  final int currentQuantity;
  final int maxQuantity;

  @override
  Widget build(BuildContext context) {
    return MutationBuilder<CartResponse, CartUpdateItemRequest>(
      mutationFn: (request) => locator.get<CartService>().updateItem(
            id: request.id,
            quantity: request.quantity,
          ),
      options: MutationOptions(
        onSuccess: (data) {
          final queryClient = context.queryClient;
          queryClient?.setQueryData(QueryKeys.cart, data);
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
                  if (queryClient != null && context.mounted) {
                    final updatedCart = await cartService.getCart();
                    if (context.mounted) {
                      queryClient.setQueryData(QueryKeys.cart, updatedCart);
                    }
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
            if (state.isLoading) const _StepperLoadingOverlay(),
          ],
        );
      },
    );
  }
}

/// Shared loading overlay for cart stepper operations.
class _StepperLoadingOverlay extends StatelessWidget {
  const _StepperLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Positioned.fill(
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
    );
  }
}
