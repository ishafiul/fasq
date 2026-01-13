import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/api/models/cart_add_item_request.dart';
import 'package:ecommerce/api/models/cart_response.dart';
import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/cart_service.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/snackbar.dart';
import 'package:ecommerce/presentation/widget/product/product_cart_stepper.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class ProductBottomActionBar extends StatefulWidget {
  const ProductBottomActionBar({
    required this.productId,
    required this.selectedVariant,
    required this.isOutOfStock,
  });

  final String productId;
  final Variants? selectedVariant;
  final bool isOutOfStock;

  @override
  State<ProductBottomActionBar> createState() => _ProductBottomActionBarState();
}

class _ProductBottomActionBarState extends State<ProductBottomActionBar> {
  bool _isWishlisted = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final palette = context.palette;

    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(spacing.sm),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: palette.border),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _isWishlisted ? Icons.favorite : Icons.favorite_border,
                color: _isWishlisted ? palette.danger : palette.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _isWishlisted = !_isWishlisted;
                });
              },
            ),
            SizedBox(width: spacing.xs),
            ProductCartStepper(
              id: widget.productId,
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: _buildBuyNowButton(
                context: context,
                isLoggedIn: true,
                label: 'Buy Now',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyNowButton({
    required BuildContext context,
    required bool isLoggedIn,
    required String label,
  }) {
    if (!isLoggedIn) {
      return Button.primary(
        onPressed: () async {
          await showSnackBar(
            context: context,
            type: SnackBarType.alert,
            message: 'Please login to continue',
            withIcon: true,
          );
          Future.delayed(const Duration(seconds: 1), () async {
            if (context.mounted) {
              await context.router.push(const LoginRoute());
            }
          });
        },
        child: Text(label),
      );
    }

    if (widget.selectedVariant == null) {
      return Button.primary(
        onPressed: () async {
          await showSnackBar(
            context: context,
            type: SnackBarType.alert,
            message: 'Please select a variant',
            withIcon: true,
          );
        },
        child: Text(label),
      );
    }

    final cartService = locator.get<CartService>();
    final variant = widget.selectedVariant!;
    final priceAtAdd = variant.price;

    return MutationBuilder<CartResponse, CartAddItemRequest>(
      mutationFn: (request) => cartService.addItem(
        productId: request.productId,
        variantId: request.variantId,
        quantity: request.quantity,
        priceAtAdd: request.priceAtAdd,
      ),
      options: MutationOptions(
        meta: const MutationMeta(
          successMessage: 'Proceeding to checkout',
          errorMessage: 'Failed to add item to cart',
        ),
        onSuccess: (data) {
          final queryClient = context.queryClient;
          if (queryClient != null) {
            queryClient.setQueryData(QueryKeys.cart, data);
          }
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              context.router.push(const CartRoute());
            }
          });
        },
      ),
      builder: (context, state, mutate) {
        return Button.primary(
          onPressed: widget.isOutOfStock || state.isLoading
              ? null
              : () async {
                  final request = CartAddItemRequest(
                    productId: widget.productId,
                    variantId: variant.id,
                    quantity: 1, // Default to 1 for Buy Now
                    priceAtAdd: priceAtAdd,
                  );
                  await mutate(request);
                },
          child: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(label),
        );
      },
    );
  }
}
