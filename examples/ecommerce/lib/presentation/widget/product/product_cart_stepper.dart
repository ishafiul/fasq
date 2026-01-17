import 'dart:async';

import 'package:ecommerce/api/models/cart_add_item_request.dart';
import 'package:ecommerce/api/models/cart_remove_item_request.dart';
import 'package:ecommerce/api/models/cart_response.dart';
import 'package:ecommerce/api/models/cart_update_item_request.dart';
import 'package:ecommerce/api/models/item.dart';
import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/cart_service.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce_ui/ecommerce_ui.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';
import 'package:stream_transform/stream_transform.dart';

/// todo: handle variants
class ProductCartStepper extends StatelessWidget {
  const ProductCartStepper({
    super.key,
    required this.id,
    this.compact = false,
    this.expandDirection = NumberStepperExpandDirection.left,
    this.max,
  });

  final String id;
  final bool compact;
  final NumberStepperExpandDirection expandDirection;
  final int? max;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<ProductDetailResponse>(
      queryKey: QueryKeys.productDetail(id),
      queryFn: () => locator.get<ProductService>().getProductById(id),
      builder: (context, productState) {
        if (!productState.hasValue) {
          return _NumberStepperWidget(
            compact: compact,
            expandDirection: expandDirection,
            max: max,
            onQuantityChanged: (value) {},
            isLoading: true,
            currentQuantity: 0,
          );
        }
        return _AuthenticatedCartStepper(
          product: productState.data!,
          compact: compact,
          expandDirection: expandDirection,
          max: max,
        );
      },
    );
  }
}

class _AuthenticatedCartStepper extends StatefulWidget {
  const _AuthenticatedCartStepper({
    required this.product,
    this.compact = false,
    this.expandDirection = NumberStepperExpandDirection.left,
    this.max,
  });

  final ProductDetailResponse product;
  final bool compact;
  final NumberStepperExpandDirection expandDirection;
  final int? max;

  @override
  State<_AuthenticatedCartStepper> createState() => _AuthenticatedCartStepperState();
}

class _AuthenticatedCartStepperState extends State<_AuthenticatedCartStepper> {
  late final StreamController<int> _quantityController;
  StreamSubscription<int>? _debounceSubscription;
  int? _syncedQuantity;
  Item? _currentCartItem;
  Future<void> Function(CartUpdateItemRequest)? _updateMutate;
  Future<void> Function(CartAddItemRequest)? _addMutate;
  late Future<void> Function(CartRemoveItemRequest)? _removeMutate;
  QueryClient? _queryClient;

  static const _debounceDuration = Duration(milliseconds: 1000);
  static final _debounceTransformer = StreamTransformer<int, int>.fromBind(
    (stream) => stream.debounce(_debounceDuration),
  );

  @override
  void initState() {
    super.initState();
    _quantityController = StreamController<int>();
    _debounceSubscription = _quantityController.stream.transform(_debounceTransformer).listen(_handleQuantityChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _queryClient = context.queryClient;
  }

  @override
  Future<void> dispose() async {
    await _debounceSubscription?.cancel();
    await _quantityController.close();
    super.dispose();
  }

  Future<void> _handleQuantityChange(int quantity) async {
    if (quantity <= 0) return;
    if (_shouldSkipMutation(quantity)) return;

    if (_currentCartItem != null) {
      await _updateItemQuantity(quantity);
    } else {
      await _addItemToCart(quantity);
    }
  }

  bool _shouldSkipMutation(int quantity) {
    final currentCartQuantity = _currentCartItem?.quantity.toInt() ?? 0;
    return quantity == currentCartQuantity || quantity == _syncedQuantity;
  }

  Future<void> _updateItemQuantity(int quantity) async {
    if (_updateMutate == null) return;
    await _updateMutate!(
      CartUpdateItemRequest(
        id: _currentCartItem!.id,
        quantity: quantity,
      ),
    );
  }

  Future<void> _addItemToCart(int quantity) async {
    if (_addMutate == null) return;
    await _addMutate!(
      CartAddItemRequest(
        productId: widget.product.id,
        variantId: _getVariantId(),
        quantity: quantity,
        priceAtAdd: widget.product.basePrice,
      ),
    );
  }

  String _getVariantId() {
    return _currentCartItem?.variantId ?? (widget.product.variants.isNotEmpty ? widget.product.variants.first.id : '');
  }

  void _updateSyncedQuantity(int quantity) {
    if (_syncedQuantity != quantity) {
      _syncedQuantity = quantity;
    }
  }

  void _onQuantityChanged(num? value) {
    if (value == null) return;
    final quantity = value.toInt();
    if (quantity == _syncedQuantity) return;
    _quantityController.add(quantity);
  }

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
        final cart = cartState.data;
        if (cart == null) {
          return _NumberStepperWidget(
            compact: widget.compact,
            expandDirection: widget.expandDirection,
            max: widget.max,
            onQuantityChanged: _onQuantityChanged,
            isLoading: true,
            currentQuantity: 0,
          );
        }

        final cartItem = _findCartItem(cart);
        _currentCartItem = cartItem;
        final currentQuantity = cartItem?.quantity.toInt() ?? 0;
        _updateSyncedQuantity(currentQuantity);

        return _StepperWithMutations(
          cartItem: cartItem,
          currentQuantity: currentQuantity,
          compact: widget.compact,
          expandDirection: widget.expandDirection,
          max: widget.max,
          onQuantityChanged: _onQuantityChanged,
          onMutationSuccess: _handleMutationSuccess,
          onUpdateMutate: (mutate) => _updateMutate = mutate,
          onAddMutate: (mutate) => _addMutate = mutate,
          onRemoveMutate: (mutate) => _removeMutate = mutate,
        );
      },
    );
  }

  void _handleMutationSuccess(CartResponse cart) {
    if (_queryClient == null || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _queryClient == null) return;
      _queryClient!.setQueryData(QueryKeys.cart, cart);
      final cartItem = _findCartItem(cart);
      _updateSyncedQuantity(cartItem?.quantity.toInt() ?? 0);
    });
  }

  Item? _findCartItem(CartResponse cart) {
    final matchingItems = cart.items.where((item) => item.product.id == widget.product.id).toList();
    return matchingItems.isEmpty ? null : matchingItems.first.item;
  }
}

class _StepperWithMutations extends StatelessWidget {
  const _StepperWithMutations({
    required this.cartItem,
    required this.currentQuantity,
    required this.compact,
    required this.expandDirection,
    required this.max,
    required this.onQuantityChanged,
    required this.onMutationSuccess,
    required this.onUpdateMutate,
    required this.onAddMutate,
    required this.onRemoveMutate,
  });

  final Item? cartItem;
  final int currentQuantity;
  final bool compact;
  final NumberStepperExpandDirection expandDirection;
  final int? max;
  final ValueChanged<num?> onQuantityChanged;
  final ValueChanged<CartResponse> onMutationSuccess;
  final ValueChanged<Future<void> Function(CartUpdateItemRequest)> onUpdateMutate;
  final ValueChanged<Future<void> Function(CartAddItemRequest)> onAddMutate;
  final ValueChanged<Future<void> Function(CartRemoveItemRequest)> onRemoveMutate;

  @override
  Widget build(BuildContext context) {
    if (cartItem != null) {
      return _UpdateAndRemoveMutations(
        cartItem: cartItem!,
        currentQuantity: currentQuantity,
        compact: compact,
        expandDirection: expandDirection,
        max: max,
        onQuantityChanged: onQuantityChanged,
        onMutationSuccess: onMutationSuccess,
        onUpdateMutate: onUpdateMutate,
        onRemoveMutate: onRemoveMutate,
      );
    }
    return _AddMutation(
      currentQuantity: currentQuantity,
      compact: compact,
      expandDirection: expandDirection,
      max: max,
      onQuantityChanged: onQuantityChanged,
      onMutationSuccess: onMutationSuccess,
      onAddMutate: onAddMutate,
    );
  }
}

class _UpdateAndRemoveMutations extends StatelessWidget {
  const _UpdateAndRemoveMutations({
    required this.cartItem,
    required this.currentQuantity,
    required this.compact,
    required this.expandDirection,
    required this.max,
    required this.onQuantityChanged,
    required this.onMutationSuccess,
    required this.onUpdateMutate,
    required this.onRemoveMutate,
  });

  final Item cartItem;
  final int currentQuantity;
  final bool compact;
  final NumberStepperExpandDirection expandDirection;
  final int? max;
  final ValueChanged<num?> onQuantityChanged;
  final ValueChanged<CartResponse> onMutationSuccess;
  final ValueChanged<Future<void> Function(CartUpdateItemRequest)> onUpdateMutate;
  final ValueChanged<Future<void> Function(CartRemoveItemRequest)> onRemoveMutate;

  @override
  Widget build(BuildContext context) {
    return MutationBuilder<CartResponse, CartUpdateItemRequest>(
      mutationFn: (request) => locator.get<CartService>().updateItem(
            id: request.id,
            quantity: request.quantity,
          ),
      options: MutationOptions(
        meta: const MutationMeta(
          successMessage: 'Cart updated',
          errorMessage: 'Failed to update cart',
        ),
        onSuccess: onMutationSuccess,
      ),
      builder: (context, updateState, updateMutate) {
        onUpdateMutate(updateMutate);
        return MutationBuilder<CartResponse, CartRemoveItemRequest>(
          mutationFn: (request) => locator.get<CartService>().removeItem(id: request.id),
          options: MutationOptions(
            meta: const MutationMeta(
              successMessage: 'Item removed from cart',
              errorMessage: 'Failed to remove item',
            ),
            onSuccess: onMutationSuccess,
          ),
          builder: (context, removeState, removeMutate) {
            onRemoveMutate(removeMutate);
            return _NumberStepperWidget(
              currentQuantity: currentQuantity,
              isLoading: updateState.isLoading || removeState.isLoading,
              compact: compact,
              expandDirection: expandDirection,
              max: max,
              onQuantityChanged: onQuantityChanged,
              onDelete: () => removeMutate(CartRemoveItemRequest(id: cartItem.id)),
            );
          },
        );
      },
    );
  }
}

class _AddMutation extends StatelessWidget {
  const _AddMutation({
    required this.currentQuantity,
    required this.compact,
    required this.expandDirection,
    required this.max,
    required this.onQuantityChanged,
    required this.onMutationSuccess,
    required this.onAddMutate,
  });

  final int currentQuantity;
  final bool compact;
  final NumberStepperExpandDirection expandDirection;
  final int? max;
  final ValueChanged<num?> onQuantityChanged;
  final ValueChanged<CartResponse> onMutationSuccess;
  final ValueChanged<Future<void> Function(CartAddItemRequest)> onAddMutate;

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
        onSuccess: onMutationSuccess,
      ),
      builder: (context, state, mutate) {
        onAddMutate(mutate);
        return _NumberStepperWidget(
          currentQuantity: currentQuantity,
          isLoading: state.isLoading,
          compact: compact,
          expandDirection: expandDirection,
          max: max,
          onQuantityChanged: onQuantityChanged,
        );
      },
    );
  }
}

class _NumberStepperWidget extends StatelessWidget {
  const _NumberStepperWidget({
    required this.currentQuantity,
    required this.isLoading,
    required this.compact,
    required this.expandDirection,
    required this.max,
    required this.onQuantityChanged,
    this.onDelete,
  });

  final int currentQuantity;
  final bool isLoading;
  final bool compact;
  final NumberStepperExpandDirection expandDirection;
  final int? max;
  final ValueChanged<num?> onQuantityChanged;
  final VoidCallback? onDelete;

  static const _minQuantity = 1;
  static const _defaultMaxQuantity = 999;

  @override
  Widget build(BuildContext context) {
    return NumberStepper(
      value: currentQuantity,
      min: _minQuantity,
      max: max ?? _defaultMaxQuantity,
      disabled: isLoading,
      compact: compact,
      expandDirection: expandDirection,
      onChanged: onQuantityChanged,
      onDelete: onDelete,
    );
  }
}
