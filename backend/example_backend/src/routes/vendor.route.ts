import z from "zod/v3";
import { ORPCError } from '@orpc/server';
import { publicProcedure, protectedProcedure } from '../procedures';
import type { TRPCContext } from '../context';
import {
  createVendor,
  getVendorById,
  getVendorByUserId,
  updateVendorStatus,
  updateVendor,
  listVendors,
} from '../repositories/vendor.repository';
import { vendorStatusSchema } from '../schemas/common.schema';
import { getPaginationParams, paginationQuerySchema } from '../utils/pagination.utils';

const OPENAPI_TAG = 'Vendor';

export const vendorRoutes = {
  applyVendor: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'POST',
      path: '/vendors/apply',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        businessName: z.string().min(3).max(255),
        description: z.string().max(1000).optional(),
      })
    )
    .output(
      z.object({
        id: z.string(),
        userId: z.string(),
        businessName: z.string(),
        status: z.string(),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const existing = await getVendorByUserId(db, authUser.id);
      if (existing) {
        throw new ORPCError('BAD_REQUEST', {
          message: 'Vendor application already exists',
        });
      }

      const vendor = await createVendor(db, {
        userId: authUser.id,
        businessName: input.businessName,
        description: input.description,
        status: 'pending',
      });

      return vendor;
    }),

  getVendor: publicProcedure
    .route({
      method: 'GET',
      path: '/vendors/:id',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(
      z.object({
        id: z.string(),
        businessName: z.string(),
        description: z.string().nullable(),
        logo: z.string().nullable(),
        status: z.string(),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const vendor = await getVendorById(db, input.id);
      if (!vendor) {
        throw new ORPCError('NOT_FOUND', { message: 'Vendor not found' });
      }

      return vendor;
    }),

  listVendors: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'GET',
      path: '/vendors',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        status: z.string().optional(),
        search: z.string().optional(),
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
      const result = await listVendors(
        db,
        { status: input.status, search: input.search },
        pagination
      );

      return result;
    }),

  updateVendorStatus: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'PATCH',
      path: '/vendors/:id/status',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        id: z.string(),
        status: vendorStatusSchema,
      })
    )
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const vendor = await updateVendorStatus(db, input.id, input.status);
      if (!vendor) {
        throw new ORPCError('NOT_FOUND', { message: 'Vendor not found' });
      }

      return { success: true };
    }),

  updateVendorProfile: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'PATCH',
      path: '/vendors/:id',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        id: z.string(),
        businessName: z.string().min(3).max(255).optional(),
        description: z.string().max(1000).optional(),
        logo: z.string().optional(),
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

      const vendor = await getVendorById(db, input.id);
      if (!vendor) {
        throw new ORPCError('NOT_FOUND', { message: 'Vendor not found' });
      }

      const isAdmin = authUserRoles.includes('admin') || authUserRoles.includes('superadmin');
      if (!isAdmin && vendor.userId !== authUser.id) {
        throw new ORPCError('FORBIDDEN', {
          message: 'Not authorized to update this vendor',
        });
      }

      const { id, ...updateData } = input;
      await updateVendor(db, input.id, updateData);

      return { success: true };
    }),
};

