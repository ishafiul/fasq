import { eq, and } from 'drizzle-orm';
import { DB } from '../utils/db.utils';
import { shippingAddresses, InsertShippingAddress } from '../schemas/address.schema';
import { v4 as uuidv4 } from 'uuid';

export async function createAddress(
  db: DB,
  data: Omit<InsertShippingAddress, 'id'>
) {
  const id = uuidv4();

  if (data.isDefault) {
    await db
      .update(shippingAddresses)
      .set({ isDefault: false })
      .where(eq(shippingAddresses.userId, data.userId));
  }

  const [address] = await db
    .insert(shippingAddresses)
    .values({
      ...data,
      id,
    })
    .returning();

  return address;
}

export async function updateAddress(
  db: DB,
  id: string,
  userId: string,
  data: Partial<Omit<InsertShippingAddress, 'id' | 'userId'>>
) {
  if (data.isDefault) {
    await db
      .update(shippingAddresses)
      .set({ isDefault: false })
      .where(eq(shippingAddresses.userId, userId));
  }

  const [address] = await db
    .update(shippingAddresses)
    .set({ ...data, updatedAt: new Date() })
    .where(and(eq(shippingAddresses.id, id), eq(shippingAddresses.userId, userId)))
    .returning();

  return address || null;
}

export async function deleteAddress(db: DB, id: string, userId: string) {
  const [address] = await db
    .delete(shippingAddresses)
    .where(and(eq(shippingAddresses.id, id), eq(shippingAddresses.userId, userId)))
    .returning();

  return address || null;
}

export async function setDefaultAddress(db: DB, id: string, userId: string) {
  await db
    .update(shippingAddresses)
    .set({ isDefault: false })
    .where(eq(shippingAddresses.userId, userId));

  const [address] = await db
    .update(shippingAddresses)
    .set({ isDefault: true, updatedAt: new Date() })
    .where(and(eq(shippingAddresses.id, id), eq(shippingAddresses.userId, userId)))
    .returning();

  return address || null;
}

export async function listUserAddresses(db: DB, userId: string) {
  return await db
    .select()
    .from(shippingAddresses)
    .where(eq(shippingAddresses.userId, userId))
    .orderBy(shippingAddresses.isDefault, shippingAddresses.createdAt);
}

export async function getAddressById(db: DB, id: string, userId: string) {
  const [address] = await db
    .select()
    .from(shippingAddresses)
    .where(and(eq(shippingAddresses.id, id), eq(shippingAddresses.userId, userId)))
    .limit(1);

  return address || null;
}

export async function getDefaultAddress(db: DB, userId: string) {
  const [address] = await db
    .select()
    .from(shippingAddresses)
    .where(
      and(
        eq(shippingAddresses.userId, userId),
        eq(shippingAddresses.isDefault, true)
      )
    )
    .limit(1);

  return address || null;
}

