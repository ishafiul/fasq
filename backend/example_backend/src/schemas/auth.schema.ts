import { pgTable, text, timestamp, boolean } from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import { z } from 'zod';

export const auths = pgTable('auths', {
	id: text('id').primaryKey(),
	userId: text('userId').notNull(),
	deviceId: text('deviceId').notNull(),
	lastRefresh: timestamp('lastRefresh').defaultNow(),
	isTrusted: boolean('is_trusted').notNull().default(false),
	trustedAt: timestamp('trusted_at'),
});

export const insertAuthsSchema = createInsertSchema(auths);
export const selectAuthsSchema = createSelectSchema(auths);
export type SelectAuth = z.infer<typeof selectAuthsSchema>;