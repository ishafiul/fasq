import { pgTable, text, integer, timestamp, boolean } from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import z from 'zod/v3';
import { timestamps, promotionalTypeSchema } from './common.schema';
import { productResponseSchema, productImageResponseSchema } from './product.schema';

export const promotionalContent = pgTable('promotional_content', {
  id: text('id').primaryKey(),
  type: text('type').notNull(),
  title: text('title').notNull(),
  description: text('description'),
  imageUrl: text('image_url'),
  link: text('link'),
  displayOrder: integer('display_order').notNull().default(0),
  startDate: timestamp('start_date').notNull(),
  endDate: timestamp('end_date').notNull(),
  isActive: boolean('is_active').notNull().default(true),
  productIds: text('product_ids').array(),
  categoryIds: text('category_ids').array(),
  ...timestamps,
});

export const insertPromotionalContentSchema = (createInsertSchema(
  promotionalContent
) as any).extend({
  type: promotionalTypeSchema,
    title: z.string().min(3).max(255),
    description: z.string().max(1000).optional(),
    imageUrl: z.string().url().optional(),
    link: z.string().url().optional(),
    displayOrder: z.number().int().min(0).optional(),
    startDate: z.date(),
    endDate: z.date(),
    isActive: z.boolean().optional(),
    productIds: z.array(z.string()).optional(),
    categoryIds: z.array(z.string()).optional(),
});

export const selectPromotionalContentSchema =
  createSelectSchema(promotionalContent) as unknown as z.ZodType<any>;

// Product schemas are imported from product.schema.ts

// Promotional content response schema (with products instead of productIds)
export const promotionalContentResponseSchema = z.object({
  id: z.string(),
  type: z.string(),
  title: z.string(),
  description: z.string().nullable(),
  imageUrl: z.string().nullable(),
  link: z.string().nullable(),
  displayOrder: z.number(),
  startDate: z.coerce.date(),
  endDate: z.coerce.date(),
  isActive: z.boolean(),
  categoryIds: z.array(z.string()).nullable(),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
  products: z.array(productResponseSchema),
});

export type SelectPromotionalContent = z.infer<
  typeof selectPromotionalContentSchema
>;
export type InsertPromotionalContent = z.infer<
  typeof insertPromotionalContentSchema
> & {
  type: z.infer<typeof promotionalTypeSchema>;
  title: string;
  description?: string;
  imageUrl?: string;
  link?: string;
  displayOrder?: number;
  startDate: Date;
  endDate: Date;
  isActive?: boolean;
  productIds?: string[];
  categoryIds?: string[];
};
export type PromotionalContentResponse = z.infer<
  typeof promotionalContentResponseSchema
>;
export type ProductResponse = z.infer<typeof productResponseSchema>;
export type ProductImageResponse = z.infer<typeof productImageResponseSchema>;

