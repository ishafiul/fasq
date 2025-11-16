import { eq, isNull } from 'drizzle-orm';
import { DB } from '../utils/db.utils';
import { categories, InsertCategory } from '../schemas/category.schema';
import { v4 as uuidv4 } from 'uuid';

export async function createCategory(db: DB, data: Omit<InsertCategory, 'id'>) {
  const id = uuidv4();
  const [category] = await db
    .insert(categories)
    .values({
      ...data,
      id,
    })
    .returning();
  return category;
}

export async function getCategoryById(db: DB, id: string) {
  const [category] = await db
    .select()
    .from(categories)
    .where(eq(categories.id, id))
    .limit(1);
  return category || null;
}

export async function getCategoryBySlug(db: DB, slug: string) {
  const [category] = await db
    .select()
    .from(categories)
    .where(eq(categories.slug, slug))
    .limit(1);
  return category || null;
}

export async function getCategoryTree(db: DB) {
  const allCategories = await db
    .select()
    .from(categories)
    .where(eq(categories.isActive, true))
    .orderBy(categories.displayOrder, categories.name);

  const categoryMap = new Map();
  const rootCategories: any[] = [];

  for (const category of allCategories) {
    categoryMap.set(category.id, { ...category, children: [] });
  }

  for (const category of allCategories) {
    if (category.parentId) {
      const parent = categoryMap.get(category.parentId);
      if (parent) {
        parent.children.push(categoryMap.get(category.id));
      }
    } else {
      rootCategories.push(categoryMap.get(category.id));
    }
  }

  return rootCategories;
}

export async function updateCategory(
  db: DB,
  id: string,
  data: Partial<Omit<InsertCategory, 'id'>>
) {
  const [category] = await db
    .update(categories)
    .set({ ...data, updatedAt: new Date() })
    .where(eq(categories.id, id))
    .returning();
  return category || null;
}

export async function deleteCategory(db: DB, id: string) {
  const [category] = await db
    .delete(categories)
    .where(eq(categories.id, id))
    .returning();
  return category || null;
}

export async function listCategories(db: DB, parentId?: string | null) {
  const whereClause = parentId === null 
    ? isNull(categories.parentId)
    : parentId 
      ? eq(categories.parentId, parentId)
      : undefined;

  return await db
    .select()
    .from(categories)
    .where(whereClause)
    .orderBy(categories.displayOrder, categories.name);
}

