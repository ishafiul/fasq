import z from "zod/v3";
import { ORPCError } from '@orpc/server';
import { publicProcedure, protectedProcedure } from '../procedures';
import type { TRPCContext } from '../context';
import {
  createReview,
  updateReview,
  deleteReview,
  getProductReviews,
  getProductRating,
  approveReview,
  rejectReview,
  checkUserHasPurchased,
} from '../repositories/review.repository';
import { getPaginationParams, paginationQuerySchema } from '../utils/pagination.utils';

const OPENAPI_TAG = 'Review';

export const reviewRoutes = {
  createReview: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'POST',
      path: '/products/:productId/reviews',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        productId: z.string(),
        rating: z.number().int().min(1).max(5),
        title: z.string().min(3).max(255),
        comment: z.string().max(2000).optional(),
        orderId: z.string().optional(),
      })
    )
    .output(z.object({ id: z.string() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const hasPurchased = await checkUserHasPurchased(db, authUser.id, input.productId);

      const review = await createReview(db, {
        productId: input.productId,
        userId: authUser.id,
        orderId: input.orderId,
        rating: input.rating,
        title: input.title,
        comment: input.comment,
        isVerifiedPurchase: hasPurchased,
        status: 'pending',
      });

      return review;
    }),

  getProductReviews: publicProcedure
    .route({
      method: 'GET',
      path: '/products/:productId/reviews',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        productId: z.string(),
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
        rating: z.object({
          averageRating: z.number(),
          totalReviews: z.number(),
        }),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const pagination = getPaginationParams(input);
      const [reviews, rating] = await Promise.all([
        getProductReviews(db, input.productId, pagination, 'approved'),
        getProductRating(db, input.productId),
      ]);

      return { ...reviews, rating };
    }),

  updateReview: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'PATCH',
      path: '/reviews/:id',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        id: z.string(),
        rating: z.number().int().min(1).max(5).optional(),
        title: z.string().min(3).max(255).optional(),
        comment: z.string().max(2000).optional(),
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

      const { id, ...updateData } = input;
      const review = await updateReview(db, id, authUser.id, updateData);
      if (!review) {
        throw new ORPCError('NOT_FOUND', { message: 'Review not found' });
      }

      return { success: true };
    }),

  deleteReview: protectedProcedure({ anyOf: ['user', 'admin'] })
    .route({
      method: 'DELETE',
      path: '/reviews/:id',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
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
      const userId = isAdmin ? undefined : authUser.id;

      const review = await deleteReview(db, input.id, userId);
      if (!review) {
        throw new ORPCError('NOT_FOUND', { message: 'Review not found' });
      }

      return { success: true };
    }),

  approveReview: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'PATCH',
      path: '/reviews/:id/approve',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const review = await approveReview(db, input.id);
      if (!review) {
        throw new ORPCError('NOT_FOUND', { message: 'Review not found' });
      }

      return { success: true };
    }),

  rejectReview: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'PATCH',
      path: '/reviews/:id/reject',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const review = await rejectReview(db, input.id);
      if (!review) {
        throw new ORPCError('NOT_FOUND', { message: 'Review not found' });
      }

      return { success: true };
    }),
};

