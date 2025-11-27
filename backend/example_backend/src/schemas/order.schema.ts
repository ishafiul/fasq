import {
  pgTable,
  text,
  numeric,
  integer,
  timestamp,
} from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import z from 'zod/v3';
import { timestamps } from './common.schema';
import { relations } from 'drizzle-orm';
import { users } from './user.schema';
import { shippingAddresses } from './address.schema';
import { products, productVariants, selectProductSchema, selectProductVariantSchema } from './product.schema';
import { vendors } from './vendor.schema';
import { promoCodes } from './promo.schema';

export const orderStatusEnum = [
  'pending',
  'confirmed',
  'processing',
  'shipped',
  'delivered',
  'cancelled',
] as const;

export const paymentStatusEnum = [
  'pending',
  'completed',
  'failed',
  'refunded',
] as const;

export const orders = pgTable('orders', {
  id: text('id').primaryKey(),
  userId: text('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'restrict' }),
  shippingAddressId: text('shipping_address_id')
    .notNull()
    .references(() => shippingAddresses.id, { onDelete: 'restrict' }),
  orderNumber: text('order_number').notNull().unique(),
  subtotal: numeric('subtotal', { precision: 10, scale: 2 }).notNull(),
  discountAmount: numeric('discount_amount', {
    precision: 10,
    scale: 2,
  }).default('0'),
  promoCodeId: text('promo_code_id').references(() => promoCodes.id, {
    onDelete: 'set null',
  }),
  shippingCost: numeric('shipping_cost', { precision: 10, scale: 2 }).default(
    '0'
  ),
  taxAmount: numeric('tax_amount', { precision: 10, scale: 2 }).default('0'),
  total: numeric('total', { precision: 10, scale: 2 }).notNull(),
  status: text('status').notNull().default('pending'),
  paymentStatus: text('payment_status').notNull().default('pending'),
  paymentMethod: text('payment_method'),
  paymentIntentId: text('payment_intent_id'),
  notes: text('notes'),
  ...timestamps,
});

export const orderItems = pgTable('order_items', {
  id: text('id').primaryKey(),
  orderId: text('order_id')
    .notNull()
    .references(() => orders.id, { onDelete: 'cascade' }),
  productId: text('product_id')
    .notNull()
    .references(() => products.id, { onDelete: 'restrict' }),
  variantId: text('variant_id')
    .notNull()
    .references(() => productVariants.id, { onDelete: 'restrict' }),
  vendorId: text('vendor_id')
    .notNull()
    .references(() => vendors.id, { onDelete: 'restrict' }),
  quantity: integer('quantity').notNull(),
  unitPrice: numeric('unit_price', { precision: 10, scale: 2 }).notNull(),
  totalPrice: numeric('total_price', { precision: 10, scale: 2 }).notNull(),
  status: text('status').notNull().default('pending'),
  ...timestamps,
});

export const orderVendorTracking = pgTable('order_vendor_tracking', {
  id: text('id').primaryKey(),
  orderId: text('order_id')
    .notNull()
    .references(() => orders.id, { onDelete: 'cascade' }),
  vendorId: text('vendor_id')
    .notNull()
    .references(() => vendors.id, { onDelete: 'restrict' }),
  subtotal: numeric('subtotal', { precision: 10, scale: 2 }).notNull(),
  status: text('status').notNull().default('pending'),
  trackingNumber: text('tracking_number'),
  shippedAt: timestamp('shipped_at'),
  deliveredAt: timestamp('delivered_at'),
  ...timestamps,
});

export const ordersRelations = relations(orders, ({ one, many }) => ({
  user: one(users, {
    fields: [orders.userId],
    references: [users.id],
  }),
  shippingAddress: one(shippingAddresses, {
    fields: [orders.shippingAddressId],
    references: [shippingAddresses.id],
  }),
  promoCode: one(promoCodes, {
    fields: [orders.promoCodeId],
    references: [promoCodes.id],
  }),
  items: many(orderItems),
  vendorTracking: many(orderVendorTracking),
}));

export const orderItemsRelations = relations(orderItems, ({ one }) => ({
  order: one(orders, {
    fields: [orderItems.orderId],
    references: [orders.id],
  }),
  product: one(products, {
    fields: [orderItems.productId],
    references: [products.id],
  }),
  variant: one(productVariants, {
    fields: [orderItems.variantId],
    references: [productVariants.id],
  }),
  vendor: one(vendors, {
    fields: [orderItems.vendorId],
    references: [vendors.id],
  }),
}));

export const orderVendorTrackingRelations = relations(
  orderVendorTracking,
  ({ one }) => ({
    order: one(orders, {
      fields: [orderVendorTracking.orderId],
      references: [orders.id],
    }),
    vendor: one(vendors, {
      fields: [orderVendorTracking.vendorId],
      references: [vendors.id],
    }),
  })
);

// Using type assertions for drizzle-zod compatibility with zod v3
export const insertOrderSchema = createInsertSchema(orders, {
  orderNumber: z.string().min(6).max(50),
  subtotal: z.string().regex(/^\d+(\.\d{1,2})?$/),
  discountAmount: z.string().regex(/^\d+(\.\d{1,2})?$/).optional(),
  shippingCost: z.string().regex(/^\d+(\.\d{1,2})?$/).optional(),
  taxAmount: z.string().regex(/^\d+(\.\d{1,2})?$/).optional(),
  total: z.string().regex(/^\d+(\.\d{1,2})?$/),
  status: z.enum(orderStatusEnum),
  paymentStatus: z.enum(paymentStatusEnum),
  notes: z.string().max(1000).optional(),
} as any) as any;

export const insertOrderItemSchema = createInsertSchema(orderItems, {
  quantity: z.number().int().min(1),
  unitPrice: z.string().regex(/^\d+(\.\d{1,2})?$/),
  totalPrice: z.string().regex(/^\d+(\.\d{1,2})?$/),
  status: z.enum(orderStatusEnum),
} as any) as any;

export const insertOrderVendorTrackingSchema = createInsertSchema(
  orderVendorTracking,
  {
    subtotal: z.string().regex(/^\d+(\.\d{1,2})?$/),
    status: z.enum(orderStatusEnum),
    trackingNumber: z.string().max(255).optional(),
  } as any
) as any;

export const selectOrderSchema = createSelectSchema(orders) as any;
export const selectOrderItemSchema = createSelectSchema(orderItems) as any;
export const selectOrderVendorTrackingSchema =
  createSelectSchema(orderVendorTracking) as any;

// Order response schemas for API responses
export const orderVendorTrackingResponseSchema = selectOrderVendorTrackingSchema;

export const orderItemResponseSchema = (selectOrderItemSchema as any).extend({
  product: selectProductSchema,
  variant: selectProductVariantSchema,
});

export const orderListItemResponseSchema = selectOrderSchema;

// Vendor order response schema (for vendor orders list with tracking)
export const vendorOrderListItemResponseSchema = z.object({
  tracking: orderVendorTrackingResponseSchema,
  order: orderListItemResponseSchema,
});

export const orderResponseSchema = (selectOrderSchema as any).extend({
  items: z.array(orderItemResponseSchema),
  vendorTracking: z.array(orderVendorTrackingResponseSchema),
  shippingAddress: z.object({
    id: z.string(),
    userId: z.string(),
    fullName: z.string(),
    phoneNumber: z.string(),
    addressLine1: z.string(),
    addressLine2: z.string().nullable(),
    city: z.string(),
    state: z.string(),
    postalCode: z.string(),
    country: z.string(),
    isDefault: z.boolean(),
    createdAt: z.coerce.date(),
    updatedAt: z.coerce.date(),
  }),
});

export type SelectOrder = z.infer<typeof selectOrderSchema>;
export type SelectOrderItem = z.infer<typeof selectOrderItemSchema>;
export type SelectOrderVendorTracking = z.infer<
  typeof selectOrderVendorTrackingSchema
>;
export type InsertOrder = z.infer<typeof insertOrderSchema>;
export type InsertOrderItem = z.infer<typeof insertOrderItemSchema>;
export type InsertOrderVendorTracking = z.infer<
  typeof insertOrderVendorTrackingSchema
>;
export type OrderResponse = z.infer<typeof orderResponseSchema>;
export type OrderListItemResponse = z.infer<typeof orderListItemResponseSchema>;
export type OrderItemResponse = z.infer<typeof orderItemResponseSchema>;
export type OrderVendorTrackingResponse = z.infer<typeof orderVendorTrackingResponseSchema>;
export type VendorOrderListItemResponse = z.infer<typeof vendorOrderListItemResponseSchema>;

