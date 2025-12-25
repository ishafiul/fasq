import z from "zod/v3";
import { ORPCError } from '@orpc/server';
import { protectedProcedure } from '../procedures';
import type { TRPCContext } from '../context';
import {
  createOrder,
  createOrderItem,
  createOrderVendorTracking,
  getOrderById,
  listUserOrders,
  listVendorOrders,
  listAllOrders,
  updateOrderStatus,
  updateVendorOrderStatus,
  addTrackingNumber,
} from '../repositories/order.repository';
import { orderStatusSchema } from '../schemas/common.schema';
import { orderResponseSchema, orderListItemResponseSchema, vendorOrderListItemResponseSchema } from '../schemas/order.schema';
import { getOrCreateCart, getCartWithItems, clearCart } from '../repositories/cart.repository';
import { getPromoCodeByCode } from '../repositories/promo.repository';
import { getVendorByUserId } from '../repositories/vendor.repository';
import { getPaginationParams, paginationQuerySchema } from '../utils/pagination.utils';
import { calculateOrderTotals, generateOrderNumber, groupOrderItemsByVendor } from '../utils/order.utils';
import { updateInventory } from '../repositories/product.repository';

const OPENAPI_TAG = 'Order';

export const orderRoutes = {
  createOrder: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'POST',
      path: '/orders',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        shippingAddressId: z.string(),
        promoCode: z.string().optional(),
        paymentMethod: z.string().optional(),
        notes: z.string().max(1000).optional(),
      })
    )
    .output(z.object({ orderId: z.string(), orderNumber: z.string() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const cart = await getOrCreateCart(db, authUser.id);
      const cartData = await getCartWithItems(db, cart.id);
      if (!cartData || !cartData.items || cartData.items.length === 0) {
        throw new ORPCError('BAD_REQUEST', { message: 'Cart is empty' });
      }

      const cartItems = cartData.items.map(item => ({
        ...item.item,
        price: item.variant.price,
      }));

      let promoCodeData = null;
      if (input.promoCode) {
        promoCodeData = await getPromoCodeByCode(db, input.promoCode);
      }

      const totals = calculateOrderTotals(cartItems, promoCodeData, 0, 0);

      const orderNumber = generateOrderNumber();

      const order = await createOrder(db, {
        userId: authUser.id,
        shippingAddressId: input.shippingAddressId,
        orderNumber,
        subtotal: totals.subtotal,
        discountAmount: totals.discountAmount,
        promoCodeId: promoCodeData?.id,
        shippingCost: totals.shippingCost,
        taxAmount: totals.taxAmount,
        total: totals.total,
        status: 'pending',
        paymentStatus: 'pending',
        paymentMethod: input.paymentMethod,
        notes: input.notes,
      });

      for (const item of cartData.items) {
        const itemTotal = (parseFloat(item.variant.price) * item.item.quantity).toFixed(2);
        
        await createOrderItem(db, {
          orderId: order.id,
          productId: item.item.productId,
          variantId: item.item.variantId,
          vendorId: item.product.vendorId,
          quantity: item.item.quantity,
          unitPrice: item.variant.price,
          totalPrice: itemTotal,
          status: 'pending',
        });

        await updateInventory(db, item.item.variantId, -item.item.quantity);
      }

      const orderItems = cartData.items.map(item => ({
        vendorId: item.product.vendorId,
        totalPrice: (parseFloat(item.variant.price) * item.item.quantity).toFixed(2),
      }));

      const vendorGroups = groupOrderItemsByVendor(orderItems);

      for (const group of vendorGroups) {
        await createOrderVendorTracking(db, {
          orderId: order.id,
          vendorId: group.vendorId,
          subtotal: group.subtotal.toFixed(2),
          status: 'pending',
        });
      }

      await clearCart(db, cartData.cart.id);

      return {
        orderId: order.id,
        orderNumber: order.orderNumber,
      };
    }),

  getUserOrders: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'GET',
      path: '/orders',
      tags: [OPENAPI_TAG],
    })
    .input(paginationQuerySchema)
    .output(
      z.object({
        data: z.array(orderListItemResponseSchema),
        meta: z.object({
          total: z.number(),
          page: z.number(),
          limit: z.number(),
          totalPages: z.number(),
          hasNextPage: z.boolean(),
          hasPreviousPage: z.boolean(),
        }),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const pagination = getPaginationParams(input);
      const result = await listUserOrders(db, authUser.id, pagination);

      return result;
    }),

  getVendorOrders: protectedProcedure({ anyOf: ['vendor'] })
    .route({
      method: 'GET',
      path: '/orders/vendor',
      tags: [OPENAPI_TAG],
    })
    .input(paginationQuerySchema)
    .output(
      z.object({
        data: z.array(vendorOrderListItemResponseSchema),
        meta: z.object({
          total: z.number(),
          page: z.number(),
          limit: z.number(),
          totalPages: z.number(),
          hasNextPage: z.boolean(),
          hasPreviousPage: z.boolean(),
        }),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const vendor = await getVendorByUserId(db, authUser.id);
      if (!vendor) {
        throw new ORPCError('NOT_FOUND', { message: 'Vendor not found' });
      }

      const pagination = getPaginationParams(input);
      const result = await listVendorOrders(db, vendor.id, pagination);

      return result;
    }),

  getAllOrders: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'GET',
      path: '/orders/all',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        status: z.string().optional(),
        paymentStatus: z.string().optional(),
        startDate: z.string().optional(),
        endDate: z.string().optional(),
      }).merge(paginationQuerySchema)
    )
    .output(
      z.object({
        data: z.array(orderListItemResponseSchema),
        meta: z.object({
          total: z.number(),
          page: z.number(),
          limit: z.number(),
          totalPages: z.number(),
          hasNextPage: z.boolean(),
          hasPreviousPage: z.boolean(),
        }),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const pagination = getPaginationParams(input);
      const filters = {
        status: input.status,
        paymentStatus: input.paymentStatus,
        startDate: input.startDate ? new Date(input.startDate) : undefined,
        endDate: input.endDate ? new Date(input.endDate) : undefined,
      };

      const result = await listAllOrders(db, filters, pagination);
      return result;
    }),

  getOrder: protectedProcedure({ anyOf: ['user', 'vendor', 'admin'] })
    .route({
      method: 'GET',
      path: '/orders/:id',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(orderResponseSchema)
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');
      const authUserRoles = ctx.get('authUserRoles') || [];

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const order = await getOrderById(db, input.id);
      if (!order) {
        throw new ORPCError('NOT_FOUND', { message: 'Order not found' });
      }

      const isAdmin = authUserRoles.includes('admin') || authUserRoles.includes('superadmin');
      
      if (!isAdmin && order.userId !== authUser.id) {
        const vendor = await getVendorByUserId(db, authUser.id);
        if (!vendor) {
          throw new ORPCError('FORBIDDEN', { message: 'Not authorized to view this order' });
        }
      }

      return order;
    }),

  updateOrderStatus: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'PATCH',
      path: '/orders/:id/status',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        id: z.string(),
        status: orderStatusSchema,
      })
    )
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const order = await updateOrderStatus(db, input.id, input.status);
      if (!order) {
        throw new ORPCError('NOT_FOUND', { message: 'Order not found' });
      }

      return { success: true };
    }),

  updateVendorOrderStatus: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'PATCH',
      path: '/orders/:orderId/vendors/:vendorId/status',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        orderId: z.string(),
        vendorId: z.string(),
        status: orderStatusSchema,
      })
    )
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');
      const authUserRoles = ctx.get('authUserRoles') || [];

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const isAdmin = authUserRoles.includes('admin') || authUserRoles.includes('superadmin');
      
      if (!isAdmin) {
        const vendor = await getVendorByUserId(db, authUser.id);
        if (!vendor || vendor.id !== input.vendorId) {
          throw new ORPCError('FORBIDDEN', { message: 'Not authorized to update this vendor order' });
        }
      }

      const tracking = await updateVendorOrderStatus(db, input.orderId, input.vendorId, input.status);
      if (!tracking) {
        throw new ORPCError('NOT_FOUND', { message: 'Vendor order tracking not found' });
      }

      return { success: true };
    }),

  addTrackingNumber: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'PATCH',
      path: '/orders/:orderId/vendors/:vendorId/tracking',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        orderId: z.string(),
        vendorId: z.string(),
        trackingNumber: z.string(),
      })
    )
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');
      const authUserRoles = ctx.get('authUserRoles') || [];

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const isAdmin = authUserRoles.includes('admin') || authUserRoles.includes('superadmin');
      
      if (!isAdmin) {
        const vendor = await getVendorByUserId(db, authUser.id);
        if (!vendor || vendor.id !== input.vendorId) {
          throw new ORPCError('FORBIDDEN', { message: 'Not authorized to add tracking for this vendor order' });
        }
      }

      const tracking = await addTrackingNumber(db, input.orderId, input.vendorId, input.trackingNumber);
      if (!tracking) {
        throw new ORPCError('NOT_FOUND', { message: 'Vendor order tracking not found' });
      }

      return { success: true };
    }),
};

