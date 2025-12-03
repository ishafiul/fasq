import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/cart_service.dart';
import 'package:ecommerce/core/services/user_service.dart';
import 'package:ecommerce/core/widgets/badge.dart' as core;
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class CartIconButton extends StatelessWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<bool>(
      queryKey: QueryKeys.isLoggedIn,
      queryFn: () => locator.get<UserService>().isLoggedIn(),
      builder: (context, authState) {
        if (authState.isLoading || authState.data != true) {
          return const SizedBox.shrink();
        }

        return QueryBuilder(
          queryKey: QueryKeys.cart,
          queryFn: () => locator.get<CartService>().getCart(),
          options: QueryOptions(
            staleTime: const Duration(seconds: 30),
            cacheTime: const Duration(minutes: 5),
          ),
          builder: (context, cartState) {
            if (cartState.isLoading || cartState.hasError) {
              return const SizedBox.shrink();
            }

            final cartResponse = cartState.data;
            final items = cartResponse?.items ?? [];
            final itemCount = items.length;

            if (itemCount == 0) {
              return const SizedBox.shrink();
            }

            final badgeText = itemCount > 99 ? '99+' : itemCount.toString();
            final palette = context.palette;
            final typography = context.typography;

            return core.Badge(
              color: palette.danger,
              content: Text(
                badgeText,
                style: typography.labelSmall.toTextStyle(
                  color: ColorUtils.onColor(palette.danger),
                ),
              ),
              child: IconButton(
                onPressed: () {
                  context.router.push(const CartRoute());
                },
                icon: Icon(
                  Icons.shopping_cart_outlined,
                  color: palette.textPrimary,
                ),
                tooltip: 'Shopping Cart',
              ),
            );
          },
        );
      },
    );
  }
}
