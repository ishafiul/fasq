import { eq, and, lte, gte } from 'drizzle-orm';
import { DB } from '../utils/db.utils';
import {
  promotionalContent,
  InsertPromotionalContent,
} from '../schemas/promotional.schema';
import { getProductsByIds } from './product.repository';
import { v4 as uuidv4 } from 'uuid';

export async function createPromotionalContent(
  db: DB,
  data: Omit<InsertPromotionalContent, 'id'>
) {
  const id = uuidv4();
  const [content] = await db
    .insert(promotionalContent)
    .values({
      ...data,
      id,
    })
    .returning();
  return content;
}

export async function getPromotionalContentById(db: DB, id: string) {
  const [content] = await db
    .select()
    .from(promotionalContent)
    .where(eq(promotionalContent.id, id))
    .limit(1);
  return content || null;
}

export async function getPromotionalContent(db: DB, type: string) {
  const now = new Date();

  const contents = await db
    .select()
    .from(promotionalContent)
    .where(
      and(
        eq(promotionalContent.type, type),
        eq(promotionalContent.isActive, true),
        lte(promotionalContent.startDate, now),
        gte(promotionalContent.endDate, now)
      )
    )
    .orderBy(promotionalContent.displayOrder);

  // Transform to include full product data instead of productIds
  const contentWithProducts = await Promise.all(
    contents.map(async (content) => {
      const products = content.productIds && content.productIds.length > 0
        ? await getProductsByIds(db, content.productIds)
        : [];
      
      const { productIds, ...rest } = content;
      return {
        ...rest,
        products,
      };
    })
  );

  return contentWithProducts;
}

export async function getBestDeals(db: DB) {
  return await getPromotionalContent(db, 'best_deals');
}

export async function getTopProducts(db: DB) {
  return await getPromotionalContent(db, 'top_products');
}

export async function getCurrentOffers(db: DB) {
  return await getPromotionalContent(db, 'current_offers');
}

export async function getFeaturedProducts(db: DB) {
  const now = new Date();

  const contents = await db
    .select()
    .from(promotionalContent)
    .where(
      and(
        eq(promotionalContent.isActive, true),
        lte(promotionalContent.startDate, now),
        gte(promotionalContent.endDate, now)
      )
    )
    .orderBy(promotionalContent.displayOrder)
    .limit(10);

  // Transform to include full product data instead of productIds
  const contentWithProducts = await Promise.all(
    contents.map(async (content) => {
      const products = content.productIds && content.productIds.length > 0
        ? await getProductsByIds(db, content.productIds)
        : [];
      
      const { productIds, ...rest } = content;
      return {
        ...rest,
        products,
      };
    })
  );

  return contentWithProducts;
}

export async function updatePromotionalContent(
  db: DB,
  id: string,
  data: Partial<Omit<InsertPromotionalContent, 'id'>>
) {
  const [content] = await db
    .update(promotionalContent)
    .set({ ...data, updatedAt: new Date() })
    .where(eq(promotionalContent.id, id))
    .returning();
  return content || null;
}

export async function deletePromotionalContent(db: DB, id: string) {
  const [content] = await db
    .delete(promotionalContent)
    .where(eq(promotionalContent.id, id))
    .returning();
  return content || null;
}

export async function deactivatePromotionalContent(db: DB, id: string) {
  const [content] = await db
    .update(promotionalContent)
    .set({ isActive: false, updatedAt: new Date() })
    .where(eq(promotionalContent.id, id))
    .returning();
  return content || null;
}

