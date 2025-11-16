import { pgTable, text, integer, timestamp, boolean } from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import { z } from 'zod';
import { timestamps } from './common.schema';

export const promotionalTypeEnum = [
  'banner',
  'best_deals',
  'top_products',
  'current_offers',
] as const;

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

export const insertPromotionalContentSchema = createInsertSchema(
  promotionalContent,
  {
    type: z.enum(promotionalTypeEnum),
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
  }
);

export const selectPromotionalContentSchema =
  createSelectSchema(promotionalContent);

export type SelectPromotionalContent = z.infer<
  typeof selectPromotionalContentSchema
>;
export type InsertPromotionalContent = z.infer<
  typeof insertPromotionalContentSchema
>;

