import { pgTable, text, boolean, timestamp } from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import { z } from 'zod';
import { timestamps } from './common.schema';
import { relations } from 'drizzle-orm';

export const users = pgTable('users', {
	id: text('id').primaryKey(),
	email: text('email').notNull().unique(),
	name: text('name'),
	isBanned: boolean('is_banned').notNull().default(false),
	bannedAt: timestamp('banned_at'),
	bannedUntil: timestamp('banned_until'),
	banReason: text('ban_reason'),
	...timestamps
});

export const insertUsersSchema = createInsertSchema(users);
export const selectUsersSchema = createSelectSchema(users);
export type SelectUser = z.infer<typeof selectUsersSchema>;

export const userRole = pgTable('user_role', {
    id: text('id').primaryKey(),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    role: text('role').notNull(),
    ...timestamps,
  });
  
  export const userRoleRelation = relations(users, ({ many }) => ({
    roles: many(userRole),
  }));

export const insertUserRolesSchema = createInsertSchema(userRole);
export const selectUserRolesSchema = createSelectSchema(userRole);
export type SelectUserRole = z.infer<typeof selectUserRolesSchema>;

