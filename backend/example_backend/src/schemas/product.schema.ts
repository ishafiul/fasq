import { pgTable, text, numeric, integer, boolean } from "drizzle-orm/pg-core";
import { z } from "zod/v3";
import { oz } from "@orpc/zod";
import { timestamps } from "./common.schema";
import { relations } from "drizzle-orm";
import { vendors } from "./vendor.schema";
import { categories } from "./category.schema";

export const productStatusEnum = ["draft", "published", "archived"] as const;

export const products = pgTable("products", {
  id: text("id").primaryKey(),
  vendorId: text("vendor_id")
    .notNull()
    .references(() => vendors.id, { onDelete: "cascade" }),
  categoryId: text("category_id").references(() => categories.id, {
    onDelete: "set null",
  }),
  name: text("name").notNull(),
  slug: text("slug").notNull().unique(),
  description: text("description"),
  basePrice: numeric("base_price", { precision: 10, scale: 2 }).notNull(),
  status: text("status").notNull().default("draft"),
  tags: text("tags").array(),
  ...timestamps,
});

export const productVariants = pgTable("product_variants", {
  id: text("id").primaryKey(),
  productId: text("product_id")
    .notNull()
    .references(() => products.id, { onDelete: "cascade" }),
  sku: text("sku").notNull().unique(),
  name: text("name").notNull(),
  price: numeric("price", { precision: 10, scale: 2 }).notNull(),
  compareAtPrice: numeric("compare_at_price", { precision: 10, scale: 2 }),
  inventoryQuantity: integer("inventory_quantity").notNull().default(0),
  lowStockThreshold: integer("low_stock_threshold").notNull().default(10),
  ...timestamps,
});

export const productVariantOptions = pgTable("product_variant_options", {
  id: text("id").primaryKey(),
  variantId: text("variant_id")
    .notNull()
    .references(() => productVariants.id, { onDelete: "cascade" }),
  optionType: text("option_type").notNull(),
  optionValue: text("option_value").notNull(),
  ...timestamps,
});

export const productImages = pgTable("product_images", {
  id: text("id").primaryKey(),
  productId: text("product_id")
    .notNull()
    .references(() => products.id, { onDelete: "cascade" }),
  variantId: text("variant_id").references(() => productVariants.id, {
    onDelete: "cascade",
  }),
  url: text("url").notNull(),
  displayOrder: integer("display_order").notNull().default(0),
  isMain: boolean("is_main").notNull().default(false),
  ...timestamps,
});

export const productsRelations = relations(products, ({ one, many }) => ({
  vendor: one(vendors, {
    fields: [products.vendorId],
    references: [vendors.id],
  }),
  category: one(categories, {
    fields: [products.categoryId],
    references: [categories.id],
  }),
  variants: many(productVariants),
  images: many(productImages),
}));

export const productVariantsRelations = relations(
  productVariants,
  ({ one, many }) => ({
    product: one(products, {
      fields: [productVariants.productId],
      references: [products.id],
    }),
    options: many(productVariantOptions),
    images: many(productImages),
  })
);

export const productVariantOptionsRelations = relations(
  productVariantOptions,
  ({ one }) => ({
    variant: one(productVariants, {
      fields: [productVariantOptions.variantId],
      references: [productVariants.id],
    }),
  })
);

export const productImagesRelations = relations(productImages, ({ one }) => ({
  product: one(products, {
    fields: [productImages.productId],
    references: [products.id],
  }),
  variant: one(productVariants, {
    fields: [productImages.variantId],
    references: [productVariants.id],
  }),
}));

// Pure zod v3 schemas for products
export const insertProductSchema = z.object({
  id: z.string().optional(),
  vendorId: z.string(),
  categoryId: z.string().nullable().optional(),
  name: z.string().min(3).max(500),
  slug: z
    .string()
    .min(3)
    .max(500)
    .regex(/^[a-z0-9-]+$/),
  description: z.string().max(5000).nullable().optional(),
  basePrice: z.string().regex(/^\d+(\.\d{1,2})?$/),
  status: z.enum(productStatusEnum),
  tags: z.array(z.string()).nullable().optional(),
  createdAt: z.coerce.date().optional(),
  updatedAt: z.coerce.date().optional(),
});

export const selectProductSchema = oz.openapi(
  z.object({
    id: z.string(),
    vendorId: z.string(),
    categoryId: z.string().nullable(),
    name: z.string(),
    slug: z.string(),
    description: z.string().nullable(),
    basePrice: z.string(),
    status: z.string(),
    tags: z.array(z.string()).nullable(),
    createdAt: z.coerce.date(),
    updatedAt: z.coerce.date(),
  }),
  {
    title: "Product",
  }
);

export const insertProductVariantSchema = z.object({
  id: z.string().optional(),
  productId: z.string(),
  sku: z.string().min(3).max(100),
  name: z.string().min(1).max(255),
  price: z.string().regex(/^\d+(\.\d{1,2})?$/),
  compareAtPrice: z
    .string()
    .regex(/^\d+(\.\d{1,2})?$/)
    .nullable()
    .optional(),
  inventoryQuantity: z.number().int().min(0),
  lowStockThreshold: z.number().int().min(0),
  createdAt: z.coerce.date().optional(),
  updatedAt: z.coerce.date().optional(),
});

export const selectProductVariantSchema = z.object({
  id: z.string(),
  productId: z.string(),
  sku: z.string(),
  name: z.string(),
  price: z.string(),
  compareAtPrice: z.string().nullable(),
  inventoryQuantity: z.number(),
  lowStockThreshold: z.number(),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
});

export const insertProductVariantOptionSchema = z.object({
  id: z.string().optional(),
  variantId: z.string(),
  optionType: z.string().min(1).max(50),
  optionValue: z.string().min(1).max(255),
  createdAt: z.coerce.date().optional(),
  updatedAt: z.coerce.date().optional(),
});

export const selectProductVariantOptionSchema = z.object({
  id: z.string(),
  variantId: z.string(),
  optionType: z.string(),
  optionValue: z.string(),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
});

export const insertProductImageSchema = z.object({
  id: z.string().optional(),
  productId: z.string(),
  variantId: z.string().nullable().optional(),
  url: z.string().url(),
  displayOrder: z.number().int().min(0).optional(),
  isMain: z.boolean().optional(),
  createdAt: z.coerce.date().optional(),
  updatedAt: z.coerce.date().optional(),
});

export const selectProductImageSchema = z.object({
  id: z.string(),
  productId: z.string(),
  variantId: z.string().nullable(),
  url: z.string(),
  displayOrder: z.number(),
  isMain: z.boolean(),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
});

// Product response schemas for API responses
export const productImageResponseSchema = selectProductImageSchema;
export const productVariantOptionResponseSchema =
  selectProductVariantOptionSchema;
export const productVariantResponseSchema = selectProductVariantSchema.extend({
  options: z.array(productVariantOptionResponseSchema),
});
export const productResponseSchema = oz.openapi(
  selectProductSchema.extend({
    images: z.array(productImageResponseSchema),
  }),
  {
    title: "ProductResponse",
  }
);
export const productDetailResponseSchema = oz.openapi(
  selectProductSchema.extend({
    variants: z.array(productVariantResponseSchema),
    images: z.array(productImageResponseSchema),
  }),
  {
    title: "ProductDetailResponse",
  }
);

// Type definitions
export type SelectProduct = z.infer<typeof selectProductSchema>;
export type SelectProductVariant = z.infer<typeof selectProductVariantSchema>;
export type SelectProductVariantOption = z.infer<
  typeof selectProductVariantOptionSchema
>;
export type SelectProductImage = z.infer<typeof selectProductImageSchema>;
export type InsertProduct = z.infer<typeof insertProductSchema>;
export type InsertProductVariant = z.infer<typeof insertProductVariantSchema>;
export type InsertProductVariantOption = z.infer<
  typeof insertProductVariantOptionSchema
>;
export type InsertProductImage = z.infer<typeof insertProductImageSchema>;
export type ProductResponse = z.infer<typeof productResponseSchema>;
export type ProductDetailResponse = z.infer<typeof productDetailResponseSchema>;
