import { eq, and, count, desc, sql, avg } from 'drizzle-orm';
import { DB } from '../utils/db.utils';
import { productReviews, InsertProductReview } from '../schemas/review.schema';
import {
  PaginationParams,
  formatPaginatedResponse,
} from '../utils/pagination.utils';
import { v4 as uuidv4 } from 'uuid';

export async function createReview(
  db: DB,
  data: Omit<InsertProductReview, 'id' | 'createdAt' | 'updatedAt'>
) {
  const id = uuidv4();
  const [review] = await db
    .insert(productReviews)
    .values({
      ...data,
      id,
    } as any)
    .returning();
  return review;
}

export async function getReviewById(db: DB, id: string) {
  const [review] = await db
    .select()
    .from(productReviews)
    .where(eq(productReviews.id, id))
    .limit(1);
  return review || null;
}

export async function updateReview(
  db: DB,
  id: string,
  userId: string,
  data: Partial<Pick<InsertProductReview, 'rating' | 'title' | 'comment'>>
) {
  const [review] = await db
    .update(productReviews)
    .set({ ...data, updatedAt: new Date() })
    .where(and(eq(productReviews.id, id), eq(productReviews.userId, userId)))
    .returning();
  return review || null;
}

export async function deleteReview(db: DB, id: string, userId?: string) {
  const conditions = [eq(productReviews.id, id)];
  if (userId) {
    conditions.push(eq(productReviews.userId, userId));
  }

  const [review] = await db
    .delete(productReviews)
    .where(and(...conditions))
    .returning();
  return review || null;
}

export async function getProductReviews(
  db: DB,
  productId: string,
  pagination: PaginationParams,
  status: string = 'approved'
) {
  const [totalResult] = await db
    .select({ count: count() })
    .from(productReviews)
    .where(
      and(
        eq(productReviews.productId, productId),
        eq(productReviews.status, status)
      )
    );

  const total = totalResult?.count || 0;

  const results = await db
    .select()
    .from(productReviews)
    .where(
      and(
        eq(productReviews.productId, productId),
        eq(productReviews.status, status)
      )
    )
    .orderBy(desc(productReviews.createdAt))
    .limit(pagination.limit)
    .offset(pagination.offset);

  return formatPaginatedResponse(
    results,
    total,
    pagination.page,
    pagination.limit
  );
}

export async function getProductRating(db: DB, productId: string) {
  const [result] = await db
    .select({
      averageRating: avg(productReviews.rating),
      totalReviews: count(),
    })
    .from(productReviews)
    .where(
      and(
        eq(productReviews.productId, productId),
        eq(productReviews.status, 'approved')
      )
    );

  return {
    averageRating: result?.averageRating
      ? parseFloat(result.averageRating as string)
      : 0,
    totalReviews: result?.totalReviews || 0,
  };
}

export async function approveReview(db: DB, id: string) {
  const [review] = await db
    .update(productReviews)
    .set({ status: 'approved', updatedAt: new Date() })
    .where(eq(productReviews.id, id))
    .returning();
  return review || null;
}

export async function rejectReview(db: DB, id: string) {
  const [review] = await db
    .update(productReviews)
    .set({ status: 'rejected', updatedAt: new Date() })
    .where(eq(productReviews.id, id))
    .returning();
  return review || null;
}

export async function checkUserHasPurchased(
  db: DB,
  userId: string,
  productId: string
): Promise<boolean> {
  const result = await db.execute(sql`
    SELECT EXISTS(
      SELECT 1 FROM ${sql.identifier('order_items')} oi
      INNER JOIN ${sql.identifier('orders')} o ON oi.order_id = o.id
      WHERE o.user_id = ${userId}
        AND oi.product_id = ${productId}
        AND o.status = 'delivered'
    ) as has_purchased
  `);

  const rows = result.rows as Array<{ has_purchased: boolean }>;
  return rows[0]?.has_purchased === true;
}

