import { pgTable, text, boolean, integer } from 'drizzle-orm/pg-core';
import z from 'zod/v3';
import { oz } from '@orpc/zod';
import { timestamps } from './common.schema';
import { relations } from 'drizzle-orm';

export const categories = pgTable('categories', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  slug: text('slug').notNull().unique(),
  description: text('description'),
  parentId: text('parent_id'),
  imageUrl: text('image_url'),
  isActive: boolean('is_active').notNull().default(true),
  displayOrder: integer('display_order').notNull().default(0),
  ...timestamps,
});

export const categoriesRelations = relations(categories, ({ one, many }) => ({
  parent: one(categories, {
    fields: [categories.parentId],
    references: [categories.id],
    relationName: 'category_parent',
  }),
  children: many(categories, {
    relationName: 'category_parent',
  }),
}));

export const insertCategorySchema = z.object({
  id: z.string().optional(),
  name: z.string().min(2).max(255),
  slug: z.string().min(2).max(255).regex(/^[a-z0-9-]+$/),
  description: z.string().max(1000).nullable().optional(),
  parentId: z.string().nullable().optional(),
  imageUrl: z.string().nullable().optional(),
  isActive: z.boolean().optional(),
  displayOrder: z.number().int().min(0).optional(),
  createdAt: z.coerce.date().optional(),
  updatedAt: z.coerce.date().optional(),
});

export const selectCategorySchema = z.object({
  id: z.string(),
  name: z.string(),
  slug: z.string(),
  description: z.string().nullable(),
  parentId: z.string().nullable(),
  imageUrl: z.string().nullable(),
  isActive: z.boolean(),
  displayOrder: z.number(),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
});

// Category response schema (for single category)
export const categoryResponseSchema = oz.openapi(
  selectCategorySchema,
  {
    title: 'CategoryResponse',
  }
);

// Category tree node schema (recursive structure with children)
type CategoryTreeNodeType = z.infer<typeof selectCategorySchema> & {
  children: CategoryTreeNodeType[];
};

const createCategoryTreeNodeSchema = (): z.ZodType<CategoryTreeNodeType> => {
  return selectCategorySchema.extend({
    children: z.lazy(() => z.array(createCategoryTreeNodeSchema())),
  });
};

const _categoryTreeNodeSchema = createCategoryTreeNodeSchema();

export const categoryTreeNodeSchema = oz.openapi(
  _categoryTreeNodeSchema,
  {
    title: 'CategoryTreeNode',
  }
);

// Input schemas for API routes
export const createCategoryInputSchema = insertCategorySchema.omit({ id: true }).extend({
  parentId: z.string().optional(),
  imageUrl: z.string().url().optional(),
});

export const updateCategoryInputSchema = insertCategorySchema.omit({ id: true }).partial().extend({
  isActive: z.boolean().optional(),
});

// Output schema for create category (minimal response)
export const createCategoryOutputSchema = categoryResponseSchema.pick({
  id: true,
  name: true,
  slug: true,
});

export type SelectCategory = z.infer<typeof selectCategorySchema>;
export type InsertCategory = z.infer<typeof insertCategorySchema>;
export type CategoryResponse = z.infer<typeof categoryResponseSchema>;
export type CategoryTreeNode = CategoryTreeNodeType;
export type CreateCategoryInput = z.infer<typeof createCategoryInputSchema>;
export type UpdateCategoryInput = z.infer<typeof updateCategoryInputSchema>;

