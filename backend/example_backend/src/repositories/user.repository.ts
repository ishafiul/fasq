import { eq } from 'drizzle-orm';
import { users, userRole } from '../schemas/user.schema';
import type { DB } from '../utils/db.utils';

export async function findUserByEmail(db: DB, email: string) {
	return db.query.users.findFirst({
		where: (users, { eq }) => eq(users.email, email),
	});
}

export async function findUserById(db: DB, userId: string) {
	return db.query.users.findFirst({
		where: (users, { eq }) => eq(users.id, userId),
	});
}

export async function createUser(db: DB, id: string, email: string, name: string | null = null) {
	const [newUser] = await db.insert(users).values({
		id,
		email,
		name,
	}).returning();

	return newUser;
}

export async function createUserRole(db: DB, id: string, userId: string, role: string) {
	await db.insert(userRole).values({
		id,
		userId,
		role,
	});
}

export async function findUserRoles(db: DB, userId: string) {
	return db.query.userRole.findMany({
		where: (userRole, { eq }) => eq(userRole.userId, userId),
	});
}

export async function banUser(
	db: DB,
	userId: string,
	reason?: string | null,
	bannedUntil?: Date | null
) {
	await db.update(users)
		.set({
			isBanned: true,
			bannedAt: new Date(),
			bannedUntil: bannedUntil || null,
			banReason: reason || null,
		})
		.where(eq(users.id, userId));
}

export async function unbanUser(db: DB, userId: string) {
	await db.update(users)
		.set({
			isBanned: false,
			bannedAt: null,
			bannedUntil: null,
			banReason: null,
		})
		.where(eq(users.id, userId));
}

export async function isUserBanned(db: DB, userId: string): Promise<boolean> {
	const user = await db.query.users.findFirst({
		where: (users, { eq }) => eq(users.id, userId),
	});

	return checkUserBanStatus(db, user);
}

export async function checkUserBanStatus(
	db: DB,
	user: { isBanned: boolean; bannedUntil: Date | null; id: string } | null | undefined
): Promise<boolean> {
	if (!user || !user.isBanned) {
		return false;
	}

	if (user.bannedUntil) {
		const now = new Date();
		if (now > user.bannedUntil) {
			await unbanUser(db, user.id);
			return false;
		}
	}

	return true;
}

