import z from "zod/v3";
import { ORPCError } from '@orpc/server';
import { publicProcedure, protectedProcedure } from '../procedures';
import type { TRPCContext } from '../context';
import {
  createCategory,
  getCategoryById,
  getCategoryTree,
  updateCategory,
  deleteCategory,
} from '../repositories/category.repository';

const OPENAPI_TAG = 'Category';

export const categoryRoutes = {
  createCategory: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'POST',
      path: '/categories',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        name: z.string().min(2).max(255),
        slug: z.string().min(2).max(255).regex(/^[a-z0-9-]+$/),
        description: z.string().max(1000).optional(),
        parentId: z.string().optional(),
        imageUrl: z.string().optional(),
        displayOrder: z.number().int().min(0).optional(),
      })
    )
    .output(z.object({ id: z.string(), name: z.string(), slug: z.string() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const category = await createCategory(db, input);
      return category;
    }),

  getCategoryTree: publicProcedure
    .route({
      method: 'GET',
      path: '/categories',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({}))
    .output(z.array(z.any()))
    .handler(async ({ context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const tree = await getCategoryTree(db);
      return tree;
    }),

  getCategory: publicProcedure
    .route({
      method: 'GET',
      path: '/categories/:id',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(z.object({ id: z.string(), name: z.string(), slug: z.string() }).passthrough())
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const category = await getCategoryById(db, input.id);
      if (!category) {
        throw new ORPCError('NOT_FOUND', { message: 'Category not found' });
      }

      return category;
    }),

  updateCategory: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'PATCH',
      path: '/categories/:id',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        id: z.string(),
        name: z.string().min(2).max(255).optional(),
        slug: z.string().min(2).max(255).regex(/^[a-z0-9-]+$/).optional(),
        description: z.string().max(1000).optional(),
        imageUrl: z.string().optional(),
        isActive: z.boolean().optional(),
        displayOrder: z.number().int().min(0).optional(),
      })
    )
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const { id, ...updateData } = input;
      const category = await updateCategory(db, id, updateData);
      if (!category) {
        throw new ORPCError('NOT_FOUND', { message: 'Category not found' });
      }

      return { success: true };
    }),

  deleteCategory: protectedProcedure({ anyOf: ['admin'] })
    .route({
      method: 'DELETE',
      path: '/categories/:id',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const category = await deleteCategory(db, input.id);
      if (!category) {
        throw new ORPCError('NOT_FOUND', { message: 'Category not found' });
      }

      return { success: true };
    }),
};

