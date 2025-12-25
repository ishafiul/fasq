import { pgTable, text, integer, timestamp } from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import { timestamps } from './common.schema';

export const otps = pgTable('otps', {
	id: text('id').primaryKey(),
	otp: integer('otp').notNull(),
	email: text('email').notNull(),
	deviceUuId: text('deviceUuId').notNull(),
	expiredAt: timestamp('expiredAt').defaultNow(),
    ...timestamps,
});

export const insertOtpSchema = createInsertSchema(otps);
export const selectOtpSchema = createSelectSchema(otps);