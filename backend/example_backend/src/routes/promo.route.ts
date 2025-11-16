import z from "zod/v3";
import { ORPCError } from '@orpc/server';
import { protectedProcedure } from '../procedures';
import type { TRPCContext } from '../context';
import {
  createPromoCode,
  getPromoCodeByCode,
  validatePromoCode,
  updatePromoCode,
  deactivatePromoCode,
  listPromoCodes,
} from '../repositories/promo.repository';
import { getPaginationParams, paginationQuerySchema } from '../utils/pagination.utils';

const OPENAPI_TAG = 'PromoCode';

export const promoRoutes = {
  createPromoCode: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'POST',
      path: '/promo-codes',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        code: z.string().min(3).max(50).toUpperCase(),
        description: z.string().max(500).optional(),
        discountType: z.enum(['percentage', 'fixed']),
        discountValue: z.string(),
        minOrderValue: z.string().optional(),
        maxDiscountAmount: z.string().optional(),
        usageLimit: z.number().int().min(1).optional(),
        validFrom: z.string(),
        validUntil: z.string(),
        isActive: z.boolean().optional(),
        applicableCategories: z.array(z.string()).optional(),
        applicableVendors: z.array(z.string()).optional(),
      })
    )
    .output(z.object({ id: z.string(), code: z.string() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const promoCode = await createPromoCode(db, {
        ...input,
        validFrom: new Date(input.validFrom),
        validUntil: new Date(input.validUntil),
      });

      return promoCode;
    }),

  listPromoCodes: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'GET',
      path: '/promo-codes',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        isActive: z.coerce.boolean().optional(),
      }).merge(paginationQuerySchema)
    )
    .output(
      z.object({
        data: z.array(z.any()),
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
      const result = await listPromoCodes(db, { isActive: input.isActive }, pagination);

      return result;
    }),

  validatePromoCode: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'POST',
      path: '/promo-codes/validate',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        code: z.string(),
        orderValue: z.number().min(0),
        categoryIds: z.array(z.string()).optional(),
        vendorIds: z.array(z.string()).optional(),
      })
    )
    .output(
      z.object({
        valid: z.boolean(),
        error: z.string().optional(),
        promoCode: z.any().optional(),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const result = await validatePromoCode(
        db,
        input.code,
        input.orderValue,
        input.categoryIds,
        input.vendorIds
      );

      return result;
    }),

  updatePromoCode: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'PATCH',
      path: '/promo-codes/:id',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        id: z.string(),
        description: z.string().max(500).optional(),
        discountValue: z.string().optional(),
        minOrderValue: z.string().optional(),
        maxDiscountAmount: z.string().optional(),
        usageLimit: z.number().int().min(1).optional(),
        validFrom: z.string().optional(),
        validUntil: z.string().optional(),
        isActive: z.boolean().optional(),
        applicableCategories: z.array(z.string()).optional(),
        applicableVendors: z.array(z.string()).optional(),
      })
    )
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const { id, validFrom, validUntil, ...updateData } = input;
      
      const data: any = updateData;
      if (validFrom) data.validFrom = new Date(validFrom);
      if (validUntil) data.validUntil = new Date(validUntil);

      const promoCode = await updatePromoCode(db, id, data);
      if (!promoCode) {
        throw new ORPCError('NOT_FOUND', { message: 'Promo code not found' });
      }

      return { success: true };
    }),

  deactivatePromoCode: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'DELETE',
      path: '/promo-codes/:id',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const promoCode = await deactivatePromoCode(db, input.id);
      if (!promoCode) {
        throw new ORPCError('NOT_FOUND', { message: 'Promo code not found' });
      }

      return { success: true };
    }),
};

