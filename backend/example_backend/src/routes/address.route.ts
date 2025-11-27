import z from "zod/v3";
import { ORPCError } from '@orpc/server';
import { protectedProcedure } from '../procedures';
import type { TRPCContext } from '../context';
import {
  createAddress,
  updateAddress,
  deleteAddress,
  setDefaultAddress,
  listUserAddresses,
  getAddressById,
} from '../repositories/address.repository';
import { addressResponseSchema } from '../schemas/address.schema';

const OPENAPI_TAG = 'Address';

export const addressRoutes = {
  createAddress: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'POST',
      path: '/addresses',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        fullName: z.string().min(2).max(255),
        phoneNumber: z.string().min(10).max(20),
        addressLine1: z.string().min(5).max(500),
        addressLine2: z.string().max(500).optional(),
        city: z.string().min(2).max(100),
        state: z.string().min(2).max(100),
        postalCode: z.string().min(3).max(20),
        country: z.string().min(2).max(100),
        isDefault: z.boolean().optional(),
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

      const address = await createAddress(db, {
        ...input,
        userId: authUser.id,
      });

      return address;
    }),

  listAddresses: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'GET',
      path: '/addresses',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({}))
    .output(z.array(addressResponseSchema))
    .handler(async ({ context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const addresses = await listUserAddresses(db, authUser.id);
      return addresses;
    }),

  updateAddress: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'PATCH',
      path: '/addresses/:id',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        id: z.string(),
        fullName: z.string().min(2).max(255).optional(),
        phoneNumber: z.string().min(10).max(20).optional(),
        addressLine1: z.string().min(5).max(500).optional(),
        addressLine2: z.string().max(500).optional(),
        city: z.string().min(2).max(100).optional(),
        state: z.string().min(2).max(100).optional(),
        postalCode: z.string().min(3).max(20).optional(),
        country: z.string().min(2).max(100).optional(),
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
      const address = await updateAddress(db, id, authUser.id, updateData);
      if (!address) {
        throw new ORPCError('NOT_FOUND', { message: 'Address not found' });
      }

      return { success: true };
    }),

  deleteAddress: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'DELETE',
      path: '/addresses/:id',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const address = await deleteAddress(db, input.id, authUser.id);
      if (!address) {
        throw new ORPCError('NOT_FOUND', { message: 'Address not found' });
      }

      return { success: true };
    }),

  setDefaultAddress: protectedProcedure({ anyOf: ['user'] })
    .route({
      method: 'PATCH',
      path: '/addresses/:id/default',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const address = await setDefaultAddress(db, input.id, authUser.id);
      if (!address) {
        throw new ORPCError('NOT_FOUND', { message: 'Address not found' });
      }

      return { success: true };
    }),
};

