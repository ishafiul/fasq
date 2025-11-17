import { timestamp } from 'drizzle-orm/pg-core';
import z from 'zod/v3';

export const timestamps = {
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at')
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
};

// Shared enum schemas for API/types (used by routes & OpenAPI)

export const orderStatusEnum = [
  'pending',
  'confirmed',
  'processing',
  'shipped',
  'delivered',
  'cancelled',
] as const;

export const orderStatusSchema = z.enum(orderStatusEnum);

export const vendorStatusEnum = ['pending', 'approved', 'suspended'] as const;
export const vendorStatusSchema = z.enum(vendorStatusEnum);

export const productStatusEnum = ['draft', 'published', 'archived'] as const;
export const productStatusSchema = z.enum(productStatusEnum);

export const sortByEnum = ['price', 'createdAt', 'rating', 'name'] as const;
export const sortBySchema = z.enum(sortByEnum);

export const sortOrderEnum = ['asc', 'desc'] as const;
export const sortOrderSchema = z.enum(sortOrderEnum);

export const discountTypeEnum = ['percentage', 'fixed'] as const;
export const discountTypeSchema = z.enum(discountTypeEnum);

export const promotionalTypeEnum = [
  'banner',
  'best_deals',
  'top_products',
  'current_offers',
] as const;
export const promotionalTypeSchema = z.enum(promotionalTypeEnum);

export const reviewStatusEnum = ['pending', 'approved', 'rejected'] as const;
export const reviewStatusSchema = z.enum(reviewStatusEnum);