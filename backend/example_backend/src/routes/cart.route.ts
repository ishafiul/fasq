import z from "zod/v3";
import { ORPCError } from '@orpc/server';
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

const OPENAPI_TAG = 'Cart';

export const cartRoutes = {
  getCart: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'GET',
      path: '/cart',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({}))
    .output(z.any())
    .handler(async ({ context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const cart = await getOrCreateCart(db, authUser.id);
      const cartWithItems = await getCartWithItems(db, cart.id);

      return cartWithItems;
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
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const cart = await getOrCreateCart(db, authUser.id);
      await addItemToCart(db, cart.id, input);

      return { success: true };
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
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      await updateCartItem(db, input.id, input.quantity);
      return { success: true };
    }),

  removeItem: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'DELETE',
      path: '/cart/items/:id',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      await removeCartItem(db, input.id);
      return { success: true };
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

