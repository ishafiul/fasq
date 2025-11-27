import { pgTable, text, integer, boolean } from 'drizzle-orm/pg-core';
import z from 'zod/v3';
import { timestamps } from './common.schema';
import { relations } from 'drizzle-orm';
import { users } from './user.schema';
import { products } from './product.schema';
import { orders } from './order.schema';

export const reviewStatusEnum = ['pending', 'approved', 'rejected'] as const;

export const productReviews = pgTable('product_reviews', {
  id: text('id').primaryKey(),
  productId: text('product_id')
    .notNull()
    .references(() => products.id, { onDelete: 'cascade' }),
  userId: text('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  orderId: text('order_id').references(() => orders.id, {
    onDelete: 'set null',
  }),
  rating: integer('rating').notNull(),
  title: text('title').notNull(),
  comment: text('comment'),
  isVerifiedPurchase: boolean('is_verified_purchase')
    .notNull()
    .default(false),
  status: text('status').notNull().default('pending'),
  ...timestamps,
});

export const productReviewsRelations = relations(
  productReviews,
  ({ one }) => ({
    product: one(products, {
      fields: [productReviews.productId],
      references: [products.id],
    }),
    user: one(users, {
      fields: [productReviews.userId],
      references: [users.id],
    }),
    order: one(orders, {
      fields: [productReviews.orderId],
      references: [orders.id],
    }),
  })
);

// Pure zod v3 schemas for reviews
export const insertProductReviewSchema = z.object({
  id: z.string().optional(),
  productId: z.string(),
  userId: z.string(),
  orderId: z.string().nullable().optional(),
  rating: z.number().int().min(1).max(5),
  title: z.string().min(3).max(255),
  comment: z.string().max(2000).nullable().optional(),
  isVerifiedPurchase: z.boolean().optional(),
  status: z.enum(reviewStatusEnum).optional(),
  createdAt: z.coerce.date().optional(),
  updatedAt: z.coerce.date().optional(),
});

export const selectProductReviewSchema = z.object({
  id: z.string(),
  productId: z.string(),
  userId: z.string(),
  orderId: z.string().nullable(),
  rating: z.number(),
  title: z.string(),
  comment: z.string().nullable(),
  isVerifiedPurchase: z.boolean(),
  status: z.string(),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
});

// Review response schema for API responses
export const reviewResponseSchema = selectProductReviewSchema;

export type SelectProductReview = z.infer<typeof selectProductReviewSchema>;
export type InsertProductReview = z.infer<typeof insertProductReviewSchema>;
export type ReviewResponse = z.infer<typeof reviewResponseSchema>;

