import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/api/models/cart_add_item_request.dart';
import 'package:ecommerce/api/models/cart_clear_cart_response.dart';
import 'package:ecommerce/api/models/cart_remove_item_request.dart';
import 'package:ecommerce/api/models/cart_response.dart';
import 'package:ecommerce/api/models/cart_update_item_request.dart';
import 'package:injectable/injectable.dart';

/// Service for cart-related operations.
///
/// This service handles all cart API calls including:
/// - Getting the current cart
/// - Adding items to cart
/// - Updating item quantities
/// - Removing items from cart
/// - Clearing the entire cart
@singleton
class CartService {
  final ApiClient _apiClient;

  CartService(this._apiClient);

  /// Gets the current cart with all items.
  ///
  /// Returns the cart object and list of cart items.
  Future<CartResponse> getCart() async {
    return await _apiClient.cart.getCart();
  }

  /// Adds an item to the cart.
  ///
  /// Parameters:
  /// - [productId] - The product ID to add
  /// - [variantId] - The variant ID to add
  /// - [quantity] - The quantity to add (1-999)
  /// - [priceAtAdd] - The price at the time of adding (as string)
  Future<CartResponse> addItem({
    required String productId,
    required String variantId,
    required int quantity,
    required String priceAtAdd,
  }) async {
    final request = CartAddItemRequest(
      productId: productId,
      variantId: variantId,
      quantity: quantity,
      priceAtAdd: priceAtAdd,
    );
    return await _apiClient.cart.postCartItems(body: request);
  }

  /// Updates the quantity of a cart item.
  ///
  /// Parameters:
  /// - [id] - The cart item ID to update
  /// - [quantity] - The new quantity (0-999, 0 removes the item)
  Future<CartResponse> updateItem({
    required String id,
    required int quantity,
  }) async {
    final request = CartUpdateItemRequest(
      id: id,
      quantity: quantity,
    );
    return await _apiClient.cart.patchCartItemsId(body: request);
  }

  /// Removes an item from the cart.
  ///
  /// Parameters:
  /// - [id] - The cart item ID to remove
  Future<CartResponse> removeItem({
    required String id,
  }) async {
    final request = CartRemoveItemRequest(id: id);
    return await _apiClient.cart.deleteCartItemsId(body: request);
  }

  /// Clears the entire cart.
  ///
  /// Removes all items from the cart.
  Future<CartClearCartResponse> clearCart() async {
    return await _apiClient.cart.deleteCart(body: const {});
  }
}
