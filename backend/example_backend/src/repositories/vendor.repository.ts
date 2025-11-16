import { eq, and, ilike, count } from 'drizzle-orm';
import { DB } from '../utils/db.utils';
import { vendors, InsertVendor } from '../schemas/vendor.schema';
import { PaginationParams, formatPaginatedResponse } from '../utils/pagination.utils';
import { v4 as uuidv4 } from 'uuid';

export async function createVendor(db: DB, data: Omit<InsertVendor, 'id'>) {
  const id = uuidv4();
  const [vendor] = await db
    .insert(vendors)
    .values({
      ...data,
      id,
    })
    .returning();
  return vendor;
}

export async function getVendorById(db: DB, id: string) {
  const [vendor] = await db
    .select()
    .from(vendors)
    .where(eq(vendors.id, id))
    .limit(1);
  return vendor || null;
}

export async function getVendorByUserId(db: DB, userId: string) {
  const [vendor] = await db
    .select()
    .from(vendors)
    .where(eq(vendors.userId, userId))
    .limit(1);
  return vendor || null;
}

export async function updateVendorStatus(
  db: DB,
  id: string,
  status: 'pending' | 'approved' | 'suspended'
) {
  const [vendor] = await db
    .update(vendors)
    .set({ status, updatedAt: new Date() })
    .where(eq(vendors.id, id))
    .returning();
  return vendor || null;
}

export async function updateVendor(
  db: DB,
  id: string,
  data: Partial<Omit<InsertVendor, 'id' | 'userId'>>
) {
  const [vendor] = await db
    .update(vendors)
    .set({ ...data, updatedAt: new Date() })
    .where(eq(vendors.id, id))
    .returning();
  return vendor || null;
}

export async function listVendors(
  db: DB,
  filters: { status?: string; search?: string },
  pagination: PaginationParams
) {
  const conditions = [];

  if (filters.status) {
    conditions.push(eq(vendors.status, filters.status));
  }

  if (filters.search) {
    conditions.push(ilike(vendors.businessName, `%${filters.search}%`));
  }

  const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

  const [totalResult] = await db
    .select({ count: count() })
    .from(vendors)
    .where(whereClause);

  const total = totalResult?.count || 0;

  const results = await db
    .select()
    .from(vendors)
    .where(whereClause)
    .limit(pagination.limit)
    .offset(pagination.offset)
    .orderBy(vendors.createdAt);

  return formatPaginatedResponse(results, total, pagination.page, pagination.limit);
}

