import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/services/cart_service.dart';
import 'package:ecommerce/core/services/user_service.dart';
import 'package:ecommerce/core/widgets/no_data.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/presentation/widget/cart/cart_item_card.dart';
import 'package:ecommerce/presentation/widget/cart/cart_summary.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

@RoutePage()
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
      ),
      body: QueryBuilder<bool>(
        queryKey: QueryKeys.isLoggedIn,
        queryFn: () => locator.get<UserService>().isLoggedIn(),
        builder: (context, authState) {
          if (authState.isLoading) {
            return const Center(child: CircularProgressSpinner());
          }

          final isLoggedIn = authState.data ?? false;

          if (!isLoggedIn) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const NoData(message: 'Please login to view your cart'),
                  SizedBox(height: spacing.md),
                  ElevatedButton(
                    onPressed: () => context.router.push(const LoginRoute()),
                    child: const Text('Login'),
                  ),
                ],
              ),
            );
          }

          return QueryBuilder(
            queryKey: QueryKeys.cart,
            queryFn: () => locator.get<CartService>().getCart(),
            options: QueryOptions(
              staleTime: const Duration(seconds: 30),
              cacheTime: const Duration(minutes: 5),
            ),
            builder: (context, cartState) {
              if (cartState.isLoading && cartState.data == null) {
                return const Center(child: CircularProgressSpinner());
              }

              if (cartState.hasError && cartState.data == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const NoData(message: 'Failed to load cart'),
                      SizedBox(height: spacing.md),
                      ElevatedButton(
                        onPressed: () {
                          final queryClient = context.queryClient;
                          if (queryClient != null) {
                            queryClient.invalidateQuery(QueryKeys.cart);
                          }
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final cartResponse = cartState.data;
              final items = cartResponse?.items ?? [];

              if (items.isEmpty) {
                return const Center(
                  child: NoData(message: 'Your cart is empty'),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.all(spacing.sm),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
                      itemBuilder: (context, index) {
                        return CartItemCard(item: items[index]);
                      },
                    ),
                  ),
                  if (cartResponse != null)
                    Padding(
                      padding: EdgeInsets.all(spacing.sm),
                      child: CartSummary(cartResponse: cartResponse),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
