import { pgTable, text, timestamp } from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import { z } from 'zod';
import { timestamps } from './common.schema';
import { relations } from 'drizzle-orm';
import { users } from './user.schema';

export const vendorStatusEnum = ['pending', 'approved', 'suspended'] as const;

export const vendors = pgTable('vendors', {
  id: text('id').primaryKey(),
  userId: text('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  businessName: text('business_name').notNull(),
  description: text('description'),
  logo: text('logo'),
  status: text('status').notNull().default('pending'),
  ...timestamps,
});

export const vendorsRelations = relations(vendors, ({ one }) => ({
  user: one(users, {
    fields: [vendors.userId],
    references: [users.id],
  }),
}));

export const insertVendorSchema = createInsertSchema(vendors, {
  businessName: z.string().min(3).max(255),
  description: z.string().max(1000).optional(),
  status: z.enum(vendorStatusEnum),
});

export const selectVendorSchema = createSelectSchema(vendors);
export type SelectVendor = z.infer<typeof selectVendorSchema>;
export type InsertVendor = z.infer<typeof insertVendorSchema>;

