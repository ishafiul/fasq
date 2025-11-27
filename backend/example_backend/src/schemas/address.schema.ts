import { pgTable, text, boolean } from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import z from 'zod/v3';
import { timestamps } from './common.schema';
import { relations } from 'drizzle-orm';
import { users } from './user.schema';

export const shippingAddresses = pgTable('shipping_addresses', {
  id: text('id').primaryKey(),
  userId: text('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  fullName: text('full_name').notNull(),
  phoneNumber: text('phone_number').notNull(),
  addressLine1: text('address_line1').notNull(),
  addressLine2: text('address_line2'),
  city: text('city').notNull(),
  state: text('state').notNull(),
  postalCode: text('postal_code').notNull(),
  country: text('country').notNull(),
  isDefault: boolean('is_default').notNull().default(false),
  ...timestamps,
});

export const shippingAddressesRelations = relations(
  shippingAddresses,
  ({ one }) => ({
    user: one(users, {
      fields: [shippingAddresses.userId],
      references: [users.id],
    }),
  })
);

// Using type assertions for drizzle-zod compatibility with zod v3
export const insertShippingAddressSchema = createInsertSchema(
  shippingAddresses,
  {
    fullName: z.string().min(2).max(255),
    phoneNumber: z.string().min(10).max(20),
    addressLine1: z.string().min(5).max(500),
    addressLine2: z.string().max(500).optional(),
    city: z.string().min(2).max(100),
    state: z.string().min(2).max(100),
    postalCode: z.string().min(3).max(20),
    country: z.string().min(2).max(100),
    isDefault: z.boolean().optional(),
  } as any
) as any;

export const selectShippingAddressSchema = createSelectSchema(shippingAddresses) as any;

// Address response schema for API responses
export const addressResponseSchema = selectShippingAddressSchema;

export type SelectShippingAddress = z.infer<typeof selectShippingAddressSchema>;
export type InsertShippingAddress = z.infer<typeof insertShippingAddressSchema>;
export type AddressResponse = z.infer<typeof addressResponseSchema>;

