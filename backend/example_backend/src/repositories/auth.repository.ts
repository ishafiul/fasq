import { eq, and } from 'drizzle-orm';
import { auths } from '../schemas/auth.schema';
import type { DB } from '../utils/db.utils';

export async function createAuthSession(
	db: DB,
	id: string,
	userId: string,
	deviceId: string,
	isTrusted: boolean = false
) {
	const [authSession] = await db.insert(auths).values({
		id,
		userId,
		deviceId,
		lastRefresh: new Date(),
		isTrusted,
		trustedAt: isTrusted ? new Date() : null,
	}).returning({ id: auths.id });

	return authSession;
}

export async function findAuthByUserId(db: DB, userId: string) {
	return db.query.auths.findFirst({
		where: (auths, { eq }) => eq(auths.userId, userId),
	});
}

export async function findAuthById(db: DB, authId: string) {
	return db.query.auths.findFirst({
		where: (auths, { eq }) => eq(auths.id, authId),
	});
}

export async function findAuthByDeviceId(db: DB, deviceId: string) {
	return db.query.auths.findFirst({
		where: (auths, { eq }) => eq(auths.deviceId, deviceId),
	});
}

export async function updateAuthLastRefresh(db: DB, authId: string) {
	await db.update(auths)
		.set({
			lastRefresh: new Date(),
		})
		.where(eq(auths.id, authId));
}

export async function deleteAuthByUserId(db: DB, userId: string) {
	await db.delete(auths).where(eq(auths.userId, userId));
}

export async function deleteAuthById(db: DB, authId: string) {
	await db.delete(auths).where(eq(auths.id, authId));
}

export async function deleteAuthByDeviceId(db: DB, deviceId: string) {
	await db.delete(auths).where(eq(auths.deviceId, deviceId));
}

export async function findAuthsByUserId(db: DB, userId: string) {
	return db.query.auths.findMany({
		where: (auths, { eq }) => eq(auths.userId, userId),
	});
}

export async function markDeviceAsTrusted(db: DB, authId: string) {
	await db.update(auths)
		.set({
			isTrusted: true,
			trustedAt: new Date(),
		})
		.where(eq(auths.id, authId));
}

export async function findTrustedDevicesByUserId(db: DB, userId: string) {
	return db.query.auths.findMany({
		where: (auths, { eq, and }) => and(
			eq(auths.userId, userId),
			eq(auths.isTrusted, true)
		),
	});
}

export async function findTrustedAuthByDeviceAndUser(db: DB, deviceId: string, userId: string) {
	return db.query.auths.findFirst({
		where: (auths, { eq, and }) => and(
			eq(auths.deviceId, deviceId),
			eq(auths.userId, userId),
			eq(auths.isTrusted, true)
		),
	});
}

