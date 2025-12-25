import z from "zod/v3";
import { ORPCError } from '@orpc/server';
import { eq } from 'drizzle-orm';
import { protectedProcedure } from '../procedures';
import type { TRPCContext } from '../context';
import {
  getOrCreateCart,
  addItemToCart,
  updateCartItem,
  removeCartItem,
  clearCart,
  getCartWithItems,
} from '../repositories/cart.repository';
import { cartResponseSchema } from '../schemas/cart.schema';
import { cartItems } from '../schemas/cart.schema';

const OPENAPI_TAG = 'Cart';

export const cartRoutes = {
  getCart: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'GET',
      path: '/cart',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({}))
    .output(cartResponseSchema)
    .handler(async ({ context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      try {
      const cart = await getOrCreateCart(db, authUser.id);
      const cartWithItems = await getCartWithItems(db, cart.id);

      if (!cartWithItems) {
        throw new ORPCError('NOT_FOUND', { message: 'Cart not found' });
      }

      return cartWithItems;
      } catch (error) {
        if (error instanceof ORPCError) {
          throw error;
        }
        throw new ORPCError('INTERNAL_SERVER_ERROR', {
          message: 'Failed to fetch cart. Please try again later.',
        });
      }
    }),

  addItem: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'POST',
      path: '/cart/items',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        productId: z.string(),
        variantId: z.string(),
        quantity: z.number().int().min(1).max(999),
        priceAtAdd: z.string(),
      })
    )
    .output(cartResponseSchema)
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const cart = await getOrCreateCart(db, authUser.id);
      await addItemToCart(db, cart.id, input);

      const cartWithItems = await getCartWithItems(db, cart.id);
      if (!cartWithItems) {
        throw new ORPCError('NOT_FOUND', { message: 'Cart not found' });
      }

      return cartWithItems;
    }),

  updateItem: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'PATCH',
      path: '/cart/items/:id',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        id: z.string(),
        quantity: z.number().int().min(0).max(999),
      })
    )
    .output(cartResponseSchema)
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const [itemBeforeUpdate] = await db
        .select({ cartId: cartItems.cartId })
        .from(cartItems)
        .where(eq(cartItems.id, input.id))
        .limit(1);

      if (!itemBeforeUpdate) {
        throw new ORPCError('NOT_FOUND', { message: 'Cart item not found' });
      }

      const cart = await getOrCreateCart(db, authUser.id);
      if (itemBeforeUpdate.cartId !== cart.id) {
        throw new ORPCError('FORBIDDEN', { message: 'Cart item does not belong to your cart' });
      }

      await updateCartItem(db, input.id, input.quantity);

      const cartWithItems = await getCartWithItems(db, cart.id);
      if (!cartWithItems) {
        throw new ORPCError('NOT_FOUND', { message: 'Cart not found' });
      }

      return cartWithItems;
    }),

  removeItem: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'DELETE',
      path: '/cart/items/:id',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(cartResponseSchema)
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const [itemBeforeDelete] = await db
        .select({ cartId: cartItems.cartId })
        .from(cartItems)
        .where(eq(cartItems.id, input.id))
        .limit(1);

      if (!itemBeforeDelete) {
        throw new ORPCError('NOT_FOUND', { message: 'Cart item not found' });
      }

      const cart = await getOrCreateCart(db, authUser.id);
      if (itemBeforeDelete.cartId !== cart.id) {
        throw new ORPCError('FORBIDDEN', { message: 'Cart item does not belong to your cart' });
      }

      await removeCartItem(db, input.id);

      const cartWithItems = await getCartWithItems(db, cart.id);
      if (!cartWithItems) {
        throw new ORPCError('NOT_FOUND', { message: 'Cart not found' });
      }

      return cartWithItems;
    }),

  clearCart: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'DELETE',
      path: '/cart',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({}))
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const cart = await getOrCreateCart(db, authUser.id);
      await clearCart(db, cart.id);

      return { success: true };
    }),
};

