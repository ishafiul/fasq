import { pgTable, text, integer, numeric, timestamp } from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import z from 'zod/v3';
import { oz } from '@orpc/zod';
import { timestamps } from './common.schema';
import { relations } from 'drizzle-orm';
import { users } from './user.schema';
import { products, productVariants, selectProductSchema, selectProductVariantSchema } from './product.schema';

export const carts = pgTable('carts', {
  id: text('id').primaryKey(),
  userId: text('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  expiresAt: timestamp('expires_at').notNull(),
  ...timestamps,
});

export const cartItems = pgTable('cart_items', {
  id: text('id').primaryKey(),
  cartId: text('cart_id')
    .notNull()
    .references(() => carts.id, { onDelete: 'cascade' }),
  productId: text('product_id')
    .notNull()
    .references(() => products.id, { onDelete: 'cascade' }),
  variantId: text('variant_id')
    .notNull()
    .references(() => productVariants.id, { onDelete: 'cascade' }),
  quantity: integer('quantity').notNull().default(1),
  priceAtAdd: numeric('price_at_add', { precision: 10, scale: 2 }).notNull(),
  ...timestamps,
});

export const cartsRelations = relations(carts, ({ one, many }) => ({
  user: one(users, {
    fields: [carts.userId],
    references: [users.id],
  }),
  items: many(cartItems),
}));

export const cartItemsRelations = relations(cartItems, ({ one }) => ({
  cart: one(carts, {
    fields: [cartItems.cartId],
    references: [carts.id],
  }),
  product: one(products, {
    fields: [cartItems.productId],
    references: [products.id],
  }),
  variant: one(productVariants, {
    fields: [cartItems.variantId],
    references: [productVariants.id],
  }),
}));

// Using type assertions for drizzle-zod compatibility with zod v3
export const insertCartSchema = createInsertSchema(carts) as any;
export const insertCartItemSchema = createInsertSchema(cartItems, {
  quantity: z.number().int().min(1).max(999),
  priceAtAdd: z.string().regex(/^\d+(\.\d{1,2})?$/),
} as any) as any;

export const selectCartSchema = z.object({
  id: z.string(),
  userId: z.string(),
  expiresAt: z.coerce.date(),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
});

export const selectCartItemSchema = z.object({
  id: z.string(),
  cartId: z.string(),
  productId: z.string(),
  variantId: z.string(),
  quantity: z.number(),
  priceAtAdd: z.string(),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
});

// Cart response schemas for API responses
// The repository returns items as { item, product, variant } structure
export const cartItemResponseSchema = z.object({
  item: selectCartItemSchema,
  product: selectProductSchema,
  variant: selectProductVariantSchema,
});

export const cartResponseSchema = oz.openapi(
  z.object({
  cart: selectCartSchema,
  items: z.array(cartItemResponseSchema),
  }),
  {
    title: 'CartResponse',
  }
);

export type SelectCart = z.infer<typeof selectCartSchema>;
export type SelectCartItem = z.infer<typeof selectCartItemSchema>;
export type InsertCart = z.infer<typeof insertCartSchema>;
export type InsertCartItem = z.infer<typeof insertCartItemSchema>;
export type CartResponse = z.infer<typeof cartResponseSchema>;
export type CartItemResponse = z.infer<typeof cartItemResponseSchema>;

