import type { PermissionString } from './permission.utils';
import { roleMap } from './permission.utils';
import type { HonoContext } from '../context';
import type { DB } from './db.utils';
import { findUserByEmail, createUser, createUserRole, isUserBanned } from '../repositories/user.repository';
import { findDeviceById } from '../repositories/device.repository';
import { findOtpByDeviceAndEmail } from '../repositories/otp.repository';

export interface AuthUser {
	id: string;
	email: string;
	name?: string | null;
}

export interface AuthSession {
	userId: string;
	email: string;
}

export function authIsAdmin(userRoles: string[]): boolean {
	return userRoles.some((role) => role.startsWith('admin') || role === 'superadmin');
}

export function authIsSuperAdmin(userRoles: string[]): boolean {
	return userRoles.includes('superadmin');
}

function hasAnyOfPermission(userRoles: string[], requiredPermissions: PermissionString[]): boolean {
	const userPermissions = userRoles.flatMap((userRole) => roleMap[userRole] || []);

	const directMatch = userRoles.some((role) => requiredPermissions.includes(role as PermissionString));

	return (
		requiredPermissions.some((permission) => userPermissions.includes(permission)) || directMatch
	);
}

function hasAllOfPermission(userRoles: string[], requiredPermissions: PermissionString[]): boolean {
	const userPermissions = userRoles.flatMap((userRole) => roleMap[userRole] || []);

	return requiredPermissions.every((permission) => userPermissions.includes(permission));
}

export function checkPermissions(
	userRoles: string[],
	permissions: { anyOf?: PermissionString[]; allOf?: PermissionString[] }
): boolean {
	if (authIsSuperAdmin(userRoles)) {
		return true;
	}

	if (permissions.anyOf) {
		return hasAnyOfPermission(userRoles, permissions.anyOf);
	}

	if (permissions.allOf) {
		return hasAllOfPermission(userRoles, permissions.allOf);
	}

	return false;
}

export function getAuthHeader(c: HonoContext): string | null {
	return c.req.header('Authorization') || null;
}

export function normalizeEmail(email: string): string {
	return email.toLowerCase().trim();
}

export async function findOrCreateUser(db: DB, email: string): Promise<{ id: string; email: string; name: string | null }> {
	const normalizedEmail = normalizeEmail(email);
	const existingUser = await findUserByEmail(db, normalizedEmail);

	if (existingUser) {
		return existingUser;
	}

	const newUserId = crypto.randomUUID();
	const newUser = await createUser(db, newUserId, normalizedEmail, null);

	await createUserRole(db, crypto.randomUUID(), newUserId, 'user');

	return newUser;
}

export async function validateDevice(db: DB, deviceId: string): Promise<boolean> {
	const device = await findDeviceById(db, deviceId);
	return !!device;
}

export async function getOtpForDevice(db: DB, deviceId: string, email: string) {
	return findOtpByDeviceAndEmail(db, deviceId, email);
}

export function isOtpExpired(otp: { expiredAt: Date | null }): boolean {
	if (!otp.expiredAt) {
		return true;
	}

	return new Date() > otp.expiredAt;
}

