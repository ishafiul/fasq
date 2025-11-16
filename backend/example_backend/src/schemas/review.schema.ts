import { pgTable, text, integer, boolean } from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import { z } from 'zod';
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

export const insertProductReviewSchema = createInsertSchema(productReviews, {
  rating: z.number().int().min(1).max(5),
  title: z.string().min(3).max(255),
  comment: z.string().max(2000).optional(),
  status: z.enum(reviewStatusEnum),
});

export const selectProductReviewSchema = createSelectSchema(productReviews);

export type SelectProductReview = z.infer<typeof selectProductReviewSchema>;
export type InsertProductReview = z.infer<typeof insertProductReviewSchema>;

