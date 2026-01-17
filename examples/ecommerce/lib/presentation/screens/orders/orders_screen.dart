import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/order_service.dart';
import 'package:ecommerce/presentation/widget/cart/cart_icon_button.dart';
import 'package:ecommerce/presentation/widget/profile/order_list_item.dart';
import 'package:ecommerce_ui/ecommerce_ui.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

@RoutePage()
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: const [
          CartIconButton(),
        ],
      ),
      body: QueryBuilder(
        queryKey: QueryKeys.userOrders(),
        queryFn: () => locator.get<OrderService>().getUserOrders(),
        builder: (context, state) {
          if (state.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: palette.brand),
            );
          }

          if (state.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error loading orders',
                    style: typography.bodyLarge.toTextStyle(
                      color: palette.danger,
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  Button.primary(
                    onPressed: () {
                      context.queryClient?.invalidateQuery(QueryKeys.userOrders());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final orders = state.data?.data ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: NoData(
                message: 'No orders found.',
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.all(spacing.md),
            children: orders.map((order) {
              return OrderListItem(
                order: order,
                onTap: () {
                  // TODO: Navigate to order details
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
