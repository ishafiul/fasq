import z from "zod/v3";
import { ORPCError } from '@orpc/server';
import { publicProcedure, protectedProcedure } from '../procedures';
import type { TRPCContext } from '../context';
import {
  createProduct,
  getProductById,
  updateProduct,
  deleteProduct,
  listProducts,
  createVariant,
  updateVariant,
  getProductVariants,
  addProductImage,
  deleteProductImage,
  getProductImages,
  updateInventory,
  createVariantOption,
  getVariantOptions,
} from '../repositories/product.repository';
import { getVendorByUserId } from '../repositories/vendor.repository';
import {
  getPaginationParams,
  paginationQuerySchema,
} from '../utils/pagination.utils';
import {
  productFiltersSchema,
  productSearchSchema,
} from '../utils/search.utils';
import { generateUploadToken, generateProductImageKey, getPublicUrl } from '../utils/r2.utils';

const OPENAPI_TAG = 'Product';

export const productRoutes = {
  createProduct: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'POST',
      path: '/products',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        name: z.string().min(3).max(500),
        slug: z.string().min(3).max(500),
        description: z.string().max(5000).optional(),
        categoryId: z.string().optional(),
        basePrice: z.string(),
        status: z.enum(['draft', 'published', 'archived']).optional(),
        tags: z.array(z.string()).optional(),
        vendorId: z.string().optional(),
      })
    )
    .output(z.object({ id: z.string(), name: z.string(), slug: z.string() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const authUser = ctx.get('authUser');
      const authUserRoles = ctx.get('authUserRoles') || [];

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const isAdmin = authUserRoles.includes('admin') || authUserRoles.includes('superadmin');
      
      let vendorId: string;
      if (isAdmin && input.vendorId) {
        vendorId = input.vendorId;
      } else {
        const vendor = await getVendorByUserId(db, authUser.id);
        if (!vendor || vendor.status !== 'approved') {
          throw new ORPCError('FORBIDDEN', {
            message: 'No approved vendor account found',
          });
        }
        vendorId = vendor.id;
      }

      const { vendorId: _, ...productData } = input;
      const product = await createProduct(db, {
        ...productData,
        vendorId,
        status: input.status || 'draft',
      });

      return product;
    }),

  listProducts: publicProcedure
    .route({
      method: 'GET',
      path: '/products',
      tags: [OPENAPI_TAG],
    })
    .input(
      productFiltersSchema.merge(productSearchSchema).merge(paginationQuerySchema)
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
      const filters = productFiltersSchema.parse(input);
      const search = productSearchSchema.parse(input);

      const result = await listProducts(db, filters, search, pagination);
      return result;
    }),

  getProduct: publicProcedure
    .route({
      method: 'GET',
      path: '/products/:id',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ id: z.string() }))
    .output(z.any())
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const product = await getProductById(db, input.id);
      if (!product) {
        throw new ORPCError('NOT_FOUND', { message: 'Product not found' });
      }

      const [variants, images] = await Promise.all([
        getProductVariants(db, input.id),
        getProductImages(db, input.id),
      ]);

      const variantsWithOptions = await Promise.all(
        variants.map(async (variant) => ({
          ...variant,
          options: await getVariantOptions(db, variant.id),
        }))
      );

      return {
        ...product,
        variants: variantsWithOptions,
        images,
      };
    }),

  updateProduct: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'PATCH',
      path: '/products/:id',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        id: z.string(),
        name: z.string().min(3).max(500).optional(),
        description: z.string().max(5000).optional(),
        categoryId: z.string().optional(),
        basePrice: z.string().optional(),
        status: z.enum(['draft', 'published', 'archived']).optional(),
        tags: z.array(z.string()).optional(),
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

      const product = await getProductById(db, input.id);
      if (!product) {
        throw new ORPCError('NOT_FOUND', { message: 'Product not found' });
      }

      const isAdmin = authUserRoles.includes('admin') || authUserRoles.includes('superadmin');
      
      if (!isAdmin) {
        const vendor = await getVendorByUserId(db, authUser.id);
        if (!vendor || vendor.id !== product.vendorId) {
          throw new ORPCError('FORBIDDEN', {
            message: 'Not authorized to update this product',
          });
        }
      }

      const { id, ...updateData } = input;
      await updateProduct(db, id, updateData);

      return { success: true };
    }),

  deleteProduct: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'DELETE',
      path: '/products/:id',
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

      const product = await getProductById(db, input.id);
      if (!product) {
        throw new ORPCError('NOT_FOUND', { message: 'Product not found' });
      }

      const isAdmin = authUserRoles.includes('admin') || authUserRoles.includes('superadmin');
      
      if (!isAdmin) {
        const vendor = await getVendorByUserId(db, authUser.id);
        if (!vendor || vendor.id !== product.vendorId) {
          throw new ORPCError('FORBIDDEN', {
            message: 'Not authorized to delete this product',
          });
        }
      }

      await deleteProduct(db, input.id);
      return { success: true };
    }),

  requestImageUpload: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'POST',
      path: '/products/:productId/images/upload-url',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        productId: z.string(),
        filename: z.string(),
        contentType: z.string(),
      })
    )
    .output(
      z.object({
        token: z.string(),
        key: z.string(),
        publicUrl: z.string(),
        uploadUrl: z.string(),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');
      const env = ctx.env;
      const authUser = ctx.get('authUser');
      const authUserRoles = ctx.get('authUserRoles') || [];

      if (!authUser) {
        throw new ORPCError('UNAUTHORIZED', { message: 'User not authenticated' });
      }

      const product = await getProductById(db, input.productId);
      if (!product) {
        throw new ORPCError('NOT_FOUND', { message: 'Product not found' });
      }

      const isAdmin = authUserRoles.includes('admin') || authUserRoles.includes('superadmin');
      
      if (!isAdmin) {
        const vendor = await getVendorByUserId(db, authUser.id);
        if (!vendor || vendor.id !== product.vendorId) {
          throw new ORPCError('FORBIDDEN', {
            message: 'Not authorized to upload images for this product',
          });
        }
      }

      const key = generateProductImageKey(product.vendorId, input.productId, input.filename);
      const { token } = await generateUploadToken(key);
      const publicUrl = getPublicUrl(env.R2_PUBLIC_URL, key);
      const uploadUrl = `/api/upload/image`;

      return { token, key, publicUrl, uploadUrl };
    }),

  uploadImage: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'POST',
      path: '/upload/image',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        token: z.string(),
        file: z.any(),
      })
    )
    .output(z.object({ success: z.boolean(), url: z.string() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const env = ctx.env;

      try {
        const decoded = JSON.parse(atob(input.token));
        const { key, expiresAt } = decoded;

        if (Date.now() > expiresAt) {
          throw new ORPCError('BAD_REQUEST', { message: 'Upload token expired' });
        }

        const formData = await ctx.c.req.formData();
        const file = formData.get('file') as File;
        
        if (!file) {
          throw new ORPCError('BAD_REQUEST', { message: 'No file provided' });
        }

        const arrayBuffer = await file.arrayBuffer();
        await env.R2_BUCKET.put(key, arrayBuffer, {
          httpMetadata: {
            contentType: file.type,
          },
        });

        const publicUrl = getPublicUrl(env.R2_PUBLIC_URL, key);
        return { success: true, url: publicUrl };
      } catch (error) {
        throw new ORPCError('INTERNAL_SERVER_ERROR', {
          message: 'Failed to upload image',
        });
      }
    }),

  addProductImage: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'POST',
      path: '/products/:productId/images',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        productId: z.string(),
        url: z.string().url(),
        variantId: z.string().optional(),
        displayOrder: z.number().int().min(0).optional(),
        isMain: z.boolean().optional(),
      })
    )
    .output(z.object({ id: z.string() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const image = await addProductImage(db, input);
      return image;
    }),

  deleteProductImage: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'DELETE',
      path: '/products/:productId/images/:imageId',
      tags: [OPENAPI_TAG],
    })
    .input(z.object({ productId: z.string(), imageId: z.string() }))
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const image = await deleteProductImage(db, input.imageId);
      if (!image) {
        throw new ORPCError('NOT_FOUND', { message: 'Image not found' });
      }

      return { success: true };
    }),

  createVariant: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'POST',
      path: '/products/:productId/variants',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        productId: z.string(),
        sku: z.string(),
        name: z.string(),
        price: z.string(),
        compareAtPrice: z.string().optional(),
        inventoryQuantity: z.number().int().min(0),
        lowStockThreshold: z.number().int().min(0).optional(),
        options: z.array(
          z.object({
            optionType: z.string(),
            optionValue: z.string(),
          })
        ).optional(),
      })
    )
    .output(z.object({ id: z.string() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      const { options, productId, ...variantFields } = input;
      
      const variant = await createVariant(db, {
        productId,
        sku: variantFields.sku,
        name: variantFields.name,
        price: variantFields.price,
        compareAtPrice: variantFields.compareAtPrice,
        inventoryQuantity: variantFields.inventoryQuantity,
        lowStockThreshold: variantFields.lowStockThreshold ?? 10,
      });

      if (options && options.length > 0) {
        await Promise.all(
          options.map((option) =>
            createVariantOption(db, {
              variantId: variant.id,
              optionType: option.optionType,
              optionValue: option.optionValue,
            })
          )
        );
      }

      return variant;
    }),

  updateVariantInventory: protectedProcedure({ anyOf: ['vendor', 'admin'] })
    .route({
      method: 'PATCH',
      path: '/products/:productId/variants/:variantId/inventory',
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        productId: z.string(),
        variantId: z.string(),
        quantity: z.number().int(),
      })
    )
    .output(z.object({ success: z.boolean() }))
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get('db');

      await updateInventory(db, input.variantId, input.quantity);
      return { success: true };
    }),
};

