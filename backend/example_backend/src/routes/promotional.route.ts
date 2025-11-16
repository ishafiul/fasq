import z from "zod/v3";
import { ORPCError } from '@orpc/server';
import { publicProcedure, protectedProcedure } from '../procedures';
import type { TRPCContext } from '../context';
import {
  createPromotionalContent,
  getPromotionalContent,
  getBestDeals,
  getTopProducts,
  getCurrentOffers,
  getFeaturedProducts,
  updatePromotionalContent,
  deletePromotionalContent,
} from '../repositories/promotional.repository';

const OPENAPI_TAG = 'Promotional';

export const promotionalRoutes = {
  createPromotionalContent: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'POST',
      path: '/promotional-content',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        type: z.enum(['banner', 'best_deals', 'top_products', 'current_offers']),
        title: z.string().min(3).max(255),
        description: z.string().max(1000).optional(),
        imageUrl: z.string().url().optional(),
        link: z.string().url().optional(),
        displayOrder: z.number().int().min(0).optional(),
        startDate: z.string(),
        endDate: z.string(),
        isActive: z.boolean().optional(),
        productIds: z.array(z.string()).optional(),
        categoryIds: z.array(z.string()).optional(),
      })
    )
    .output(z.object({ id: z.string() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const content = await createPromotionalContent(db, {
        ...input,
        startDate: new Date(input.startDate),
        endDate: new Date(input.endDate),
      });

      return content;
    }),

  getBestDeals: publicProcedure
    .route({
      method: 'GET',
      path: '/promotional/best-deals',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({}))
    .output(z.array(z.any()))
    .handler(async ({ context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const deals = await getBestDeals(db);
      return deals;
    }),

  getTopProducts: publicProcedure
    .route({
      method: 'GET',
      path: '/promotional/top-products',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({}))
    .output(z.array(z.any()))
    .handler(async ({ context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const products = await getTopProducts(db);
      return products;
    }),

  getCurrentOffers: publicProcedure
    .route({
      method: 'GET',
      path: '/promotional/current-offers',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({}))
    .output(z.array(z.any()))
    .handler(async ({ context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const offers = await getCurrentOffers(db);
      return offers;
    }),

  getFeatured: publicProcedure
    .route({
      method: 'GET',
      path: '/promotional/featured',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({}))
    .output(z.array(z.any()))
    .handler(async ({ context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const featured = await getFeaturedProducts(db);
      return featured;
    }),

  updatePromotionalContent: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'PATCH',
      path: '/promotional-content/:id',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        id: z.string(),
        title: z.string().min(3).max(255).optional(),
        description: z.string().max(1000).optional(),
        imageUrl: z.string().url().optional(),
        link: z.string().url().optional(),
        displayOrder: z.number().int().min(0).optional(),
        startDate: z.string().optional(),
        endDate: z.string().optional(),
        isActive: z.boolean().optional(),
        productIds: z.array(z.string()).optional(),
        categoryIds: z.array(z.string()).optional(),
      })
    )
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const { id, startDate, endDate, ...updateData } = input;
      
      const data: any = updateData;
      if (startDate) data.startDate = new Date(startDate);
      if (endDate) data.endDate = new Date(endDate);

      const content = await updatePromotionalContent(db, id, data);
      if (!content) {
        throw new ORPCError('NOT_FOUND', { message: 'Promotional content not found' });
      }

      return { success: true };
    }),

  deletePromotionalContent: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'DELETE',
      path: '/promotional-content/:id',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const content = await deletePromotionalContent(db, input.id);
      if (!content) {
        throw new ORPCError('NOT_FOUND', { message: 'Promotional content not found' });
      }

      return { success: true };
    }),
};

