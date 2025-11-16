import { SQL, and, or, gte, lte, eq, ilike, asc, desc, sql } from 'drizzle-orm';
import { products } from '../schemas/product.schema';
import z from "zod/v3";

export const sortOrderEnum = ['asc', 'desc'] as const;
export const productSortByEnum = ['price', 'createdAt', 'rating', 'name'] as const;

export const productFiltersSchema = z.object({
  categoryId: z.string().optional(),
  vendorId: z.string().optional(),
  minPrice: z.coerce.number().min(0).optional(),
  maxPrice: z.coerce.number().min(0).optional(),
  inStock: z.coerce.boolean().optional(),
  status: z.string().optional(),
  tags: z.string().optional(),
});

export const productSearchSchema = z.object({
  search: z.string().optional(),
  sortBy: z.enum(productSortByEnum).optional().default('createdAt'),
  sortOrder: z.enum(sortOrderEnum).optional().default('desc'),
});

export type ProductFilters = z.infer<typeof productFiltersSchema>;
export type ProductSearch = z.infer<typeof productSearchSchema>;

export function buildProductSearchConditions(
  filters: ProductFilters,
  search?: string
): SQL<unknown>[] {
  const conditions: SQL<unknown>[] = [];

  if (filters.categoryId) {
    conditions.push(eq(products.categoryId, filters.categoryId));
  }

  if (filters.vendorId) {
    conditions.push(eq(products.vendorId, filters.vendorId));
  }

  if (filters.minPrice !== undefined) {
    conditions.push(gte(products.basePrice, filters.minPrice.toString()));
  }

  if (filters.maxPrice !== undefined) {
    conditions.push(lte(products.basePrice, filters.maxPrice.toString()));
  }

  if (filters.status) {
    conditions.push(eq(products.status, filters.status));
  }

  if (search) {
    conditions.push(
      or(
        ilike(products.name, `%${search}%`),
        ilike(products.description, `%${search}%`),
        sql`EXISTS (
          SELECT 1 FROM unnest(${products.tags}) AS tag
          WHERE LOWER(tag) LIKE LOWER(${`%${search}%`})
        )`
      )!
    );
  }

  if (filters.tags) {
    const tagList = filters.tags.split(',').map((t) => t.trim());
    const tagConditions = tagList.map((tag) =>
      sql`${tag} = ANY(${products.tags})`
    );
    if (tagConditions.length > 0) {
      conditions.push(or(...tagConditions)!);
    }
  }

  return conditions;
}

export function getProductSortColumn(
  sortBy: string,
  sortOrder: 'asc' | 'desc'
): SQL<unknown> {
  const orderFn = sortOrder === 'asc' ? asc : desc;

  switch (sortBy) {
    case 'price':
      return orderFn(products.basePrice);
    case 'name':
      return orderFn(products.name);
    case 'createdAt':
    default:
      return orderFn(products.createdAt);
  }
}

