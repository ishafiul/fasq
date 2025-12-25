import { eq } from 'drizzle-orm';
import { devices } from '../schemas/device.schema';
import type { DB } from '../utils/db.utils';

export async function findDeviceById(db: DB, deviceId: string) {
	return db.query.devices.findFirst({
		where: (devices, { eq }) => eq(devices.id, deviceId),
	});
}

export async function findDeviceByFingerprint(db: DB, fingerprint: string) {
	return db.query.devices.findFirst({
		where: (devices, { eq }) => eq(devices.fingerprint, fingerprint),
	});
}

export async function createDevice(
	db: DB,
	data: {
		id: string;
		fingerprint: string;
		deviceType?: string | null;
		deviceModel?: string | null;
		osName?: string | null;
		osVersion?: string | null;
		isPhysicalDevice?: string | null;
		appVersion?: string | null;
		ipAddress?: string | null;
		city?: string | null;
		countryCode?: string | null;
		isp?: string | null;
		colo?: string | null;
		timezone?: string | null;
		longitude?: string | null;
		latitude?: string | null;
		fcmToken?: string | null;
	}
) {
	const [newDevice] = await db.insert(devices).values(data).returning();
	return newDevice;
}

export async function updateDevice(
	db: DB,
	deviceId: string,
	data: {
		deviceType?: string | null;
		deviceModel?: string | null;
		osName?: string | null;
		osVersion?: string | null;
		isPhysicalDevice?: string | null;
		appVersion?: string | null;
		ipAddress?: string | null;
		city?: string | null;
		countryCode?: string | null;
		isp?: string | null;
		colo?: string | null;
		timezone?: string | null;
		longitude?: string | null;
		latitude?: string | null;
		fcmToken?: string | null;
	}
) {
	await db.update(devices).set(data).where(eq(devices.id, deviceId));
}

