import { eq, and, lt } from 'drizzle-orm';
import { DB } from '../utils/db.utils';
import { carts, cartItems, InsertCart, InsertCartItem } from '../schemas/cart.schema';
import { products, productVariants } from '../schemas/product.schema';
import { v4 as uuidv4 } from 'uuid';

const CART_EXPIRY_DAYS = 30;

export async function getOrCreateCart(db: DB, userId: string) {
  const [existingCart] = await db
    .select()
    .from(carts)
    .where(eq(carts.userId, userId))
    .limit(1);

  if (existingCart) {
    if (new Date(existingCart.expiresAt) > new Date()) {
      return existingCart;
    }
    await db.update(carts).set({
      expiresAt: new Date(Date.now() + CART_EXPIRY_DAYS * 24 * 60 * 60 * 1000),
      updatedAt: new Date(),
    }).where(eq(carts.id, existingCart.id));
    return existingCart;
  }

  const id = uuidv4();
  const expiresAt = new Date(Date.now() + CART_EXPIRY_DAYS * 24 * 60 * 60 * 1000);

  const [cart] = await db
    .insert(carts)
    .values({
      id,
      userId,
      expiresAt,
    })
    .returning();

  return cart;
}

export async function addItemToCart(
  db: DB,
  cartId: string,
  data: Omit<InsertCartItem, 'id' | 'cartId'>
) {
  const [existingItem] = await db
    .select()
    .from(cartItems)
    .where(
      and(
        eq(cartItems.cartId, cartId),
        eq(cartItems.productId, data.productId),
        eq(cartItems.variantId, data.variantId)
      )
    )
    .limit(1);

  if (existingItem) {
    const [updated] = await db
      .update(cartItems)
      .set({
        quantity: existingItem.quantity + data.quantity,
        updatedAt: new Date(),
      })
      .where(eq(cartItems.id, existingItem.id))
      .returning();
    return updated;
  }

  const id = uuidv4();
  const insertData: InsertCartItem = {
    ...data,
    id,
    cartId,
  };
  const [item] = await db
    .insert(cartItems)
    .values(insertData)
    .returning();

  if (!item) {
    throw new Error('Failed to create cart item');
  }

  return item;
}

export async function updateCartItem(
  db: DB,
  id: string,
  quantity: number
) {
  if (quantity <= 0) {
    return await removeCartItem(db, id);
  }

  const [item] = await db
    .update(cartItems)
    .set({ quantity, updatedAt: new Date() })
    .where(eq(cartItems.id, id))
    .returning();

  return item || null;
}

export async function removeCartItem(db: DB, id: string) {
  const [item] = await db
    .delete(cartItems)
    .where(eq(cartItems.id, id))
    .returning();
  return item || null;
}

export async function clearCart(db: DB, cartId: string) {
  await db.delete(cartItems).where(eq(cartItems.cartId, cartId));
}

export async function getCartWithItems(db: DB, cartId: string) {
  const cartResult = await db
    .select()
    .from(carts)
    .where(eq(carts.id, cartId))
    .limit(1);

  if (!cartResult || cartResult.length === 0) {
    return null;
  }

  const cart = cartResult[0];
  if (!cart) {
    return null;
  }

  const items = await db
    .select({
      item: cartItems,
      product: products,
      variant: productVariants,
    })
    .from(cartItems)
    .innerJoin(products, eq(cartItems.productId, products.id))
    .innerJoin(productVariants, eq(cartItems.variantId, productVariants.id))
    .where(eq(cartItems.cartId, cartId));

  return {
    cart,
    items,
  };
}

export async function cleanupExpiredCarts(db: DB) {
  await db.delete(carts).where(lt(carts.expiresAt, new Date()));
}

