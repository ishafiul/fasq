import { eq, and, count, sql } from 'drizzle-orm';
import { DB } from '../utils/db.utils';
import {
  products,
  productVariants,
  productVariantOptions,
  productImages,
  InsertProduct,
  InsertProductVariant,
  InsertProductVariantOption,
  InsertProductImage,
} from '../schemas/product.schema';
import {
  PaginationParams,
  formatPaginatedResponse,
} from '../utils/pagination.utils';
import {
  buildProductSearchConditions,
  getProductSortColumn,
  ProductFilters,
  ProductSearch,
} from '../utils/search.utils';
import { v4 as uuidv4 } from 'uuid';

export async function createProduct(
  db: DB,
  data: Omit<InsertProduct, 'id'>
) {
  const id = uuidv4();
  const [product] = await db
    .insert(products)
    .values({
      ...data,
      id,
    })
    .returning();
  return product;
}

export async function getProductById(db: DB, id: string) {
  const [product] = await db
    .select()
    .from(products)
    .where(eq(products.id, id))
    .limit(1);
  return product || null;
}

export async function getProductBySlug(db: DB, slug: string) {
  const [product] = await db
    .select()
    .from(products)
    .where(eq(products.slug, slug))
    .limit(1);
  return product || null;
}

export async function updateProduct(
  db: DB,
  id: string,
  data: Partial<Omit<InsertProduct, 'id'>>
) {
  const [product] = await db
    .update(products)
    .set({ ...data, updatedAt: new Date() })
    .where(eq(products.id, id))
    .returning();
  return product || null;
}

export async function deleteProduct(db: DB, id: string) {
  const [product] = await db
    .delete(products)
    .where(eq(products.id, id))
    .returning();
  return product || null;
}

export async function listProducts(
  db: DB,
  filters: ProductFilters,
  search: ProductSearch,
  pagination: PaginationParams
) {
  const conditions = buildProductSearchConditions(filters, search.search);
  const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

  const [totalResult] = await db
    .select({ count: count() })
    .from(products)
    .where(whereClause);

  const total = totalResult?.count || 0;

  const sortColumn = getProductSortColumn(search.sortBy, search.sortOrder);

  const results = await db
    .select()
    .from(products)
    .where(whereClause)
    .orderBy(sortColumn)
    .limit(pagination.limit)
    .offset(pagination.offset);

  return formatPaginatedResponse(
    results,
    total,
    pagination.page,
    pagination.limit
  );
}

export async function createVariant(
  db: DB,
  data: Omit<InsertProductVariant, 'id'>
) {
  const id = uuidv4();
  const [variant] = await db
    .insert(productVariants)
    .values({
      ...data,
      id,
    })
    .returning();
  return variant;
}

export async function getVariantById(db: DB, id: string) {
  const [variant] = await db
    .select()
    .from(productVariants)
    .where(eq(productVariants.id, id))
    .limit(1);
  return variant || null;
}

export async function getVariantsBySKU(db: DB, sku: string) {
  const [variant] = await db
    .select()
    .from(productVariants)
    .where(eq(productVariants.sku, sku))
    .limit(1);
  return variant || null;
}

export async function getProductVariants(db: DB, productId: string) {
  return await db
    .select()
    .from(productVariants)
    .where(eq(productVariants.productId, productId));
}

export async function updateVariant(
  db: DB,
  id: string,
  data: Partial<Omit<InsertProductVariant, 'id' | 'productId'>>
) {
  const [variant] = await db
    .update(productVariants)
    .set({ ...data, updatedAt: new Date() })
    .where(eq(productVariants.id, id))
    .returning();
  return variant || null;
}

export async function updateInventory(
  db: DB,
  variantId: string,
  quantity: number
) {
  const [variant] = await db
    .update(productVariants)
    .set({
      inventoryQuantity: sql`${productVariants.inventoryQuantity} + ${quantity}`,
      updatedAt: new Date(),
    })
    .where(eq(productVariants.id, variantId))
    .returning();
  return variant || null;
}

export async function checkStock(
  db: DB,
  variantId: string,
  requiredQuantity: number
): Promise<boolean> {
  const [variant] = await db
    .select()
    .from(productVariants)
    .where(eq(productVariants.id, variantId))
    .limit(1);

  return variant ? variant.inventoryQuantity >= requiredQuantity : false;
}

export async function addProductImage(
  db: DB,
  data: Omit<InsertProductImage, 'id'>
) {
  const id = uuidv4();
  const [image] = await db
    .insert(productImages)
    .values({
      ...data,
      id,
    })
    .returning();
  return image;
}

export async function deleteProductImage(db: DB, id: string) {
  const [image] = await db
    .delete(productImages)
    .where(eq(productImages.id, id))
    .returning();
  return image || null;
}

export async function getProductImages(db: DB, productId: string) {
  return await db
    .select()
    .from(productImages)
    .where(eq(productImages.productId, productId))
    .orderBy(productImages.displayOrder);
}

export async function reorderImages(
  db: DB,
  imageOrders: { id: string; displayOrder: number }[]
) {
  const updates = imageOrders.map((item) =>
    db
      .update(productImages)
      .set({ displayOrder: item.displayOrder, updatedAt: new Date() })
      .where(eq(productImages.id, item.id))
  );

  await Promise.all(updates);
}

export async function createVariantOption(
  db: DB,
  data: Omit<InsertProductVariantOption, 'id'>
) {
  const id = uuidv4();
  const [option] = await db
    .insert(productVariantOptions)
    .values({
      ...data,
      id,
    })
    .returning();
  return option;
}

export async function getVariantOptions(db: DB, variantId: string) {
  return await db
    .select()
    .from(productVariantOptions)
    .where(eq(productVariantOptions.variantId, variantId));
}

