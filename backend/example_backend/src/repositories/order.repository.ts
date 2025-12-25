import { eq, and, gte, lte, count, desc } from 'drizzle-orm';
import { DB } from '../utils/db.utils';
import {
  orders,
  orderItems,
  orderVendorTracking,
  InsertOrder,
  InsertOrderItem,
  InsertOrderVendorTracking,
} from '../schemas/order.schema';
import { products, productVariants } from '../schemas/product.schema';
import { shippingAddresses } from '../schemas/address.schema';
import { users } from '../schemas/user.schema';
import {
  PaginationParams,
  formatPaginatedResponse,
} from '../utils/pagination.utils';
import { v4 as uuidv4 } from 'uuid';

export async function createOrder(db: DB, data: Omit<InsertOrder, 'id'>) {
  const id = uuidv4();
  const [order] = await db
    .insert(orders)
    .values({
      ...data,
      id,
    })
    .returning();
  return order;
}

export async function createOrderItem(
  db: DB,
  data: Omit<InsertOrderItem, 'id'>
) {
  const id = uuidv4();
  const [item] = await db
    .insert(orderItems)
    .values({
      ...data,
      id,
    })
    .returning();
  return item;
}

export async function createOrderVendorTracking(
  db: DB,
  data: Omit<InsertOrderVendorTracking, 'id'>
) {
  const id = uuidv4();
  const [tracking] = await db
    .insert(orderVendorTracking)
    .values({
      ...data,
      id,
    })
    .returning();
  return tracking;
}

export async function getOrderById(db: DB, id: string) {
  const [order] = await db
    .select()
    .from(orders)
    .where(eq(orders.id, id))
    .limit(1);

  if (!order) return null;

  const items = await db
    .select({
      item: orderItems,
      product: products,
      variant: productVariants,
    })
    .from(orderItems)
    .innerJoin(products, eq(orderItems.productId, products.id))
    .innerJoin(productVariants, eq(orderItems.variantId, productVariants.id))
    .where(eq(orderItems.orderId, id));

  const tracking = await db
    .select()
    .from(orderVendorTracking)
    .where(eq(orderVendorTracking.orderId, id));

  const [address] = await db
    .select()
    .from(shippingAddresses)
    .where(eq(shippingAddresses.id, order.shippingAddressId))
    .limit(1);

  return {
    ...order,
    items,
    vendorTracking: tracking,
    shippingAddress: address,
  };
}

export async function getOrderByOrderNumber(db: DB, orderNumber: string) {
  const [order] = await db
    .select()
    .from(orders)
    .where(eq(orders.orderNumber, orderNumber))
    .limit(1);
  return order || null;
}

export async function listUserOrders(
  db: DB,
  userId: string,
  pagination: PaginationParams
) {
  const [totalResult] = await db
    .select({ count: count() })
    .from(orders)
    .where(eq(orders.userId, userId));

  const total = totalResult?.count || 0;

  const results = await db
    .select()
    .from(orders)
    .where(eq(orders.userId, userId))
    .orderBy(desc(orders.createdAt))
    .limit(pagination.limit)
    .offset(pagination.offset);

  return formatPaginatedResponse(
    results,
    total,
    pagination.page,
    pagination.limit
  );
}

export async function listVendorOrders(
  db: DB,
  vendorId: string,
  pagination: PaginationParams
) {
  const [totalResult] = await db
    .select({ count: count() })
    .from(orderVendorTracking)
    .where(eq(orderVendorTracking.vendorId, vendorId));

  const total = totalResult?.count || 0;

  const results = await db
    .select({
      tracking: orderVendorTracking,
      order: orders,
    })
    .from(orderVendorTracking)
    .innerJoin(orders, eq(orderVendorTracking.orderId, orders.id))
    .where(eq(orderVendorTracking.vendorId, vendorId))
    .orderBy(desc(orders.createdAt))
    .limit(pagination.limit)
    .offset(pagination.offset);

  return formatPaginatedResponse(
    results,
    total,
    pagination.page,
    pagination.limit
  );
}

export async function listAllOrders(
  db: DB,
  filters: {
    status?: string;
    paymentStatus?: string;
    startDate?: Date;
    endDate?: Date;
  },
  pagination: PaginationParams
) {
  const conditions = [];

  if (filters.status) {
    conditions.push(eq(orders.status, filters.status));
  }

  if (filters.paymentStatus) {
    conditions.push(eq(orders.paymentStatus, filters.paymentStatus));
  }

  if (filters.startDate) {
    conditions.push(gte(orders.createdAt, filters.startDate));
  }

  if (filters.endDate) {
    conditions.push(lte(orders.createdAt, filters.endDate));
  }

  const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

  const [totalResult] = await db
    .select({ count: count() })
    .from(orders)
    .where(whereClause);

  const total = totalResult?.count || 0;

  const results = await db
    .select()
    .from(orders)
    .where(whereClause)
    .orderBy(desc(orders.createdAt))
    .limit(pagination.limit)
    .offset(pagination.offset);

  return formatPaginatedResponse(
    results,
    total,
    pagination.page,
    pagination.limit
  );
}

export async function updateOrderStatus(
  db: DB,
  id: string,
  status: string
) {
  const [order] = await db
    .update(orders)
    .set({ status, updatedAt: new Date() })
    .where(eq(orders.id, id))
    .returning();
  return order || null;
}

export async function updateOrderPaymentStatus(
  db: DB,
  id: string,
  paymentStatus: string,
  paymentIntentId?: string
) {
  const [order] = await db
    .update(orders)
    .set({
      paymentStatus,
      paymentIntentId,
      updatedAt: new Date(),
    })
    .where(eq(orders.id, id))
    .returning();
  return order || null;
}

export async function updateVendorOrderStatus(
  db: DB,
  orderId: string,
  vendorId: string,
  status: string
) {
  const [tracking] = await db
    .update(orderVendorTracking)
    .set({ status, updatedAt: new Date() })
    .where(
      and(
        eq(orderVendorTracking.orderId, orderId),
        eq(orderVendorTracking.vendorId, vendorId)
      )
    )
    .returning();
  return tracking || null;
}

export async function addTrackingNumber(
  db: DB,
  orderId: string,
  vendorId: string,
  trackingNumber: string
) {
  const [tracking] = await db
    .update(orderVendorTracking)
    .set({
      trackingNumber,
      shippedAt: new Date(),
      status: 'shipped',
      updatedAt: new Date(),
    })
    .where(
      and(
        eq(orderVendorTracking.orderId, orderId),
        eq(orderVendorTracking.vendorId, vendorId)
      )
    )
    .returning();
  return tracking || null;
}

export async function getOrderItems(db: DB, orderId: string) {
  return await db
    .select()
    .from(orderItems)
    .where(eq(orderItems.orderId, orderId));
}

export async function getVendorOrderTracking(
  db: DB,
  orderId: string,
  vendorId: string
) {
  const [tracking] = await db
    .select()
    .from(orderVendorTracking)
    .where(
      and(
        eq(orderVendorTracking.orderId, orderId),
        eq(orderVendorTracking.vendorId, vendorId)
      )
    )
    .limit(1);
  return tracking || null;
}

