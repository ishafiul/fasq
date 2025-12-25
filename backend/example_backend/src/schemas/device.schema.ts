import { pgTable, text } from 'drizzle-orm/pg-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';
import { timestamps } from './common.schema';

export const devices = pgTable('devices', {
	id: text('id').primaryKey(),
	fingerprint: text('fingerprint').unique(),
	deviceType: text('device_type'),
	osName: text('os_name'),
	osVersion: text('os_version'),
	deviceModel: text('device_model'),
	isPhysicalDevice: text('is_physical_device'),
	appVersion: text('app_version'),
	ipAddress: text('ip_address'),
	city: text('city'),
	countryCode: text('country_code'),
	isp: text('isp'),
	colo: text('colo'),
	longitude: text('longitude'),
	latitude: text('latitude'),
	timezone: text('timezone'),
	fcmToken: text('fcmToken').unique(),
    ...timestamps,
});

export const InsertDevicesSchema = createInsertSchema(devices);
export const selectDevicesSchema = createSelectSchema(devices);
