import { pgTable, text, numeric, integer, timestamp, boolean } from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import { z } from 'zod';
import { timestamps } from './common.schema';

export const discountTypeEnum = ['percentage', 'fixed'] as const;

export const promoCodes = pgTable('promo_codes', {
  id: text('id').primaryKey(),
  code: text('code').notNull().unique(),
  description: text('description'),
  discountType: text('discount_type').notNull(),
  discountValue: numeric('discount_value', {
    precision: 10,
    scale: 2,
  }).notNull(),
  minOrderValue: numeric('min_order_value', { precision: 10, scale: 2 }),
  maxDiscountAmount: numeric('max_discount_amount', {
    precision: 10,
    scale: 2,
  }),
  usageLimit: integer('usage_limit'),
  usedCount: integer('used_count').notNull().default(0),
  validFrom: timestamp('valid_from').notNull(),
  validUntil: timestamp('valid_until').notNull(),
  isActive: boolean('is_active').notNull().default(true),
  applicableCategories: text('applicable_categories').array(),
  applicableVendors: text('applicable_vendors').array(),
  ...timestamps,
});

export const insertPromoCodeSchema = createInsertSchema(promoCodes, {
  code: z.string().min(3).max(50).toUpperCase(),
  description: z.string().max(500).optional(),
  discountType: z.enum(discountTypeEnum),
  discountValue: z.string().regex(/^\d+(\.\d{1,2})?$/),
  minOrderValue: z.string().regex(/^\d+(\.\d{1,2})?$/).optional(),
  maxDiscountAmount: z.string().regex(/^\d+(\.\d{1,2})?$/).optional(),
  usageLimit: z.number().int().min(1).optional(),
  validFrom: z.date(),
  validUntil: z.date(),
  isActive: z.boolean().optional(),
  applicableCategories: z.array(z.string()).optional(),
  applicableVendors: z.array(z.string()).optional(),
});

export const selectPromoCodeSchema = createSelectSchema(promoCodes);

export type SelectPromoCode = z.infer<typeof selectPromoCodeSchema>;
export type InsertPromoCode = z.infer<typeof insertPromoCodeSchema>;

