import { eq, and, gte, lte, count, sql } from 'drizzle-orm';
import { DB } from '../utils/db.utils';
import { promoCodes, InsertPromoCode, SelectPromoCode } from '../schemas/promo.schema';
import {
  PaginationParams,
  formatPaginatedResponse,
} from '../utils/pagination.utils';
import { v4 as uuidv4 } from 'uuid';

export async function createPromoCode(
  db: DB,
  data: Omit<InsertPromoCode, 'id'>
) {
  const id = uuidv4();
  const [promoCode] = await db
    .insert(promoCodes)
    .values({
      ...data,
      id,
    } as InsertPromoCode)
    .returning();
  return promoCode;
}

export async function getPromoCodeById(db: DB, id: string) {
  const [promoCode] = await db
    .select()
    .from(promoCodes)
    .where(eq(promoCodes.id, id))
    .limit(1);
  return promoCode || null;
}

export async function getPromoCodeByCode(db: DB, code: string) {
  const [promoCode] = await db
    .select()
    .from(promoCodes)
    .where(eq(promoCodes.code, code.toUpperCase()))
    .limit(1);
  return promoCode || null;
}

export async function validatePromoCode(
  db: DB,
  code: string,
  orderValue: number,
  categoryIds?: string[],
  vendorIds?: string[]
): Promise<{ valid: boolean; error?: string; promoCode?: SelectPromoCode }> {
  const promoCode = await getPromoCodeByCode(db, code);

  if (!promoCode) {
    return { valid: false, error: 'Promo code not found' };
  }

  if (!promoCode.isActive) {
    return { valid: false, error: 'Promo code is not active' };
  }

  const now = new Date();
  if (now < new Date(promoCode.validFrom)) {
    return { valid: false, error: 'Promo code is not yet valid' };
  }

  if (now > new Date(promoCode.validUntil)) {
    return { valid: false, error: 'Promo code has expired' };
  }

  if (promoCode.usageLimit && promoCode.usedCount >= promoCode.usageLimit) {
    return { valid: false, error: 'Promo code usage limit reached' };
  }

  if (promoCode.minOrderValue) {
    const minValue = parseFloat(promoCode.minOrderValue);
    if (orderValue < minValue) {
      return {
        valid: false,
        error: `Minimum order value of $${minValue.toFixed(2)} required`,
      };
    }
  }

  if (promoCode.applicableCategories && promoCode.applicableCategories.length > 0) {
    if (!categoryIds || categoryIds.length === 0) {
      return { valid: false, error: 'No applicable categories in cart' };
    }
    const hasMatch = categoryIds.some((id) =>
      promoCode.applicableCategories?.includes(id)
    );
    if (!hasMatch) {
      return { valid: false, error: 'Promo code not applicable to cart items' };
    }
  }

  if (promoCode.applicableVendors && promoCode.applicableVendors.length > 0) {
    if (!vendorIds || vendorIds.length === 0) {
      return { valid: false, error: 'No applicable vendors in cart' };
    }
    const hasMatch = vendorIds.some((id) =>
      promoCode.applicableVendors?.includes(id)
    );
    if (!hasMatch) {
      return { valid: false, error: 'Promo code not applicable to cart vendors' };
    }
  }

  return { valid: true, promoCode };
}

export async function usePromoCode(db: DB, id: string) {
  const [promoCode] = await db
    .update(promoCodes)
    .set({
      usedCount: sql`${promoCodes.usedCount} + 1`,
      updatedAt: new Date(),
    })
    .where(eq(promoCodes.id, id))
    .returning();
  return promoCode || null;
}

export async function updatePromoCode(
  db: DB,
  id: string,
  data: Partial<Omit<InsertPromoCode, 'id' | 'code'>>
) {
  const [promoCode] = await db
    .update(promoCodes)
    .set({ ...data, updatedAt: new Date() })
    .where(eq(promoCodes.id, id))
    .returning();
  return promoCode || null;
}

export async function deactivatePromoCode(db: DB, id: string) {
  const [promoCode] = await db
    .update(promoCodes)
    .set({ isActive: false, updatedAt: new Date() })
    .where(eq(promoCodes.id, id))
    .returning();
  return promoCode || null;
}

export async function listPromoCodes(
  db: DB,
  filters: { isActive?: boolean },
  pagination: PaginationParams
) {
  const conditions = [];

  if (filters.isActive !== undefined) {
    conditions.push(eq(promoCodes.isActive, filters.isActive));
  }

  const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

  const [totalResult] = await db
    .select({ count: count() })
    .from(promoCodes)
    .where(whereClause);

  const total = totalResult?.count || 0;

  const results = await db
    .select()
    .from(promoCodes)
    .where(whereClause)
    .orderBy(promoCodes.createdAt)
    .limit(pagination.limit)
    .offset(pagination.offset);

  return formatPaginatedResponse(
    results,
    total,
    pagination.page,
    pagination.limit
  );
}

