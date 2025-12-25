import { eq, and } from 'drizzle-orm';
import { otps } from '../schemas/otp.schema';
import type { DB } from '../utils/db.utils';

export async function findOtpByDeviceAndEmail(db: DB, deviceId: string, email: string) {
	return db.query.otps.findFirst({
		where: (otps, { eq, and }) => and(eq(otps.deviceUuId, deviceId), eq(otps.email, email)),
	});
}

export async function createOtp(db: DB, id: string, otp: number, email: string, deviceUuId: string, expiredAt: Date) {
	await db.insert(otps).values({
		id,
		otp,
		email,
		deviceUuId,
		expiredAt,
	});
}

export async function updateOtp(db: DB, id: string, otp: number, expiredAt: Date) {
	await db.update(otps)
		.set({
			otp,
			expiredAt,
		})
		.where(eq(otps.id, id));
}

export async function deleteOtpByDeviceAndEmail(db: DB, deviceId: string, email: string) {
	await db.delete(otps).where(
		and(eq(otps.deviceUuId, deviceId), eq(otps.email, email))
	);
}

