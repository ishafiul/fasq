import z from "zod/v3";
import { ORPCError } from "@orpc/server";
import { publicProcedure } from "../procedures";
import { protectedProcedure } from "../procedures/protected.procedure";
import type { TRPCContext } from "../context";
import { devices } from "../schemas/device.schema";
import {
  validateDevice,
  findOrCreateUser,
  getOtpForDevice,
  isOtpExpired,
  normalizeEmail,
  getAuthHeader,
} from "../utils/auth.utils";
import { generateOtp } from "../utils/otp.utils";
import { sendOtpEmail } from "../services/email.service";
import { generateAccessToken } from "../services/jwt.service";
import { verify } from "hono/jwt";

function extractTokenFromHeader(
  authHeader: string | null | undefined
): string | null {
  if (!authHeader) {
    return null;
  }

  if (authHeader.startsWith("Bearer ")) {
    return authHeader.substring(7);
  }

  return authHeader;
}
import {
  deleteAuthByUserId,
  createAuthSession,
  updateAuthLastRefresh,
  deleteAuthByDeviceId,
  findAuthsByUserId,
  findTrustedAuthByDeviceAndUser,
  findAuthByDeviceId,
} from "../repositories/auth.repository";
import { checkUserBanStatus } from "../repositories/user.repository";
import {
  createOtp,
  updateOtp,
  deleteOtpByDeviceAndEmail,
} from "../repositories/otp.repository";
import { findUserByEmail, findUserById } from "../repositories/user.repository";
import {
  findDeviceByFingerprint,
  updateDevice,
  createDevice,
} from "../repositories/device.repository";

const MAX_ACTIVE_DEVICES = 1;
const OPENAPI_TAG = "Auth";

const createDeviceUuidApiSchema = z.object({
  deviceType: z.string().optional(),
  deviceModel: z.string().optional(),
  osName: z.string().optional(),
  osVersion: z.string().optional(),
  isPhysicalDevice: z.boolean().optional(),
  appVersion: z.string().optional(),
  fcmToken: z.string().optional(),
});

const createDeviceUuidFullSchema = z.object({
  deviceType: z.string().optional(),
  deviceModel: z.string().optional(),
  osName: z.string().optional(),
  osVersion: z.string().optional(),
  isPhysicalDevice: z.boolean().optional(),
  appVersion: z.string().optional(),
  ipAddress: z.string().optional(),
  city: z.string().optional(),
  countryCode: z.string().optional(),
  isp: z.string().optional(),
  colo: z.string().optional(),
  timezone: z.string().optional(),
  longitude: z.string().optional(),
  latitude: z.string().optional(),
  fcmToken: z.string().optional(),
});

export const authRoutes = {
  createDeviceUuid: publicProcedure
    .route({
      method: "POST",
      path: "/auth/create-device-uuid",
      tags: [OPENAPI_TAG],
    })
    .input(createDeviceUuidApiSchema)
    .output(
      z.object({
        deviceId: z.string(),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get("db");
      const c = ctx.c;

      const cfData = (c.req.raw as any)["cf"] || {};

      const fullInput = createDeviceUuidFullSchema.parse({
        ...input,
        ipAddress: c.req.header("cf-connecting-ip") || undefined,
        isp: cfData["asOrganization"] || undefined,
        colo: cfData["colo"] || undefined,
        longitude: cfData["longitude"]?.toString() || undefined,
        latitude: cfData["latitude"]?.toString() || undefined,
        timezone: cfData["timezone"] || undefined,
        countryCode: cfData["country"] || undefined,
        city: cfData["city"] || undefined,
      });

      const fingerprintComponents = [
        fullInput.ipAddress || "",
        fullInput.deviceType || "",
        fullInput.deviceModel || "",
        fullInput.osName || "",
        fullInput.countryCode || "",
        fullInput.timezone || "",
      ].join("|");

      const fingerprintBuffer = await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(fingerprintComponents)
      );
      const fingerprint = Array.from(new Uint8Array(fingerprintBuffer))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");

      const existingDevice = await findDeviceByFingerprint(db, fingerprint);

      if (existingDevice) {
        await updateDevice(db, existingDevice.id, {
          deviceType: fullInput.deviceType,
          deviceModel: fullInput.deviceModel,
          osName: fullInput.osName,
          osVersion: fullInput.osVersion,
          isPhysicalDevice: fullInput.isPhysicalDevice ? "true" : "false",
          appVersion: fullInput.appVersion,
          ipAddress: fullInput.ipAddress,
          city: fullInput.city,
          countryCode: fullInput.countryCode,
          isp: fullInput.isp,
          colo: fullInput.colo,
          timezone: fullInput.timezone,
          longitude: fullInput.longitude,
          latitude: fullInput.latitude,
          fcmToken: fullInput.fcmToken,
        });

        return {
          deviceId: existingDevice.id,
        };
      }

      const deviceId = crypto.randomUUID();

      await createDevice(db, {
        id: deviceId,
        fingerprint,
        deviceType: fullInput.deviceType,
        deviceModel: fullInput.deviceModel,
        osName: fullInput.osName,
        osVersion: fullInput.osVersion,
        isPhysicalDevice: fullInput.isPhysicalDevice ? "true" : "false",
        appVersion: fullInput.appVersion,
        ipAddress: fullInput.ipAddress,
        city: fullInput.city,
        countryCode: fullInput.countryCode,
        isp: fullInput.isp,
        colo: fullInput.colo,
        timezone: fullInput.timezone,
        longitude: fullInput.longitude,
        latitude: fullInput.latitude,
        fcmToken: fullInput.fcmToken,
      });

      return {
        deviceId,
      };
    }),
  requestOtp: publicProcedure
    .route({
      method: "POST",
      path: "/auth/otp/request-otp",
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        email: z.string().email(),
        deviceUuId: z.string().uuid(),
      })
    )
    .output(
      z.object({
        success: z.boolean(),
        message: z.string(),
        accessToken: z.string().optional(),
        deviceId: z.string().optional(),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get("db");
      const env = ctx.env;

      const normalizedEmail = normalizeEmail(input.email);

      const [deviceExists, userResult] = await Promise.all([
        validateDevice(db, input.deviceUuId),
        findOrCreateUser(db, normalizedEmail),
      ]);

      if (!deviceExists) {
        throw new ORPCError("NOT_FOUND", {
          message: "Device not found",
        });
      }

      const [user, trustedAuth] = await Promise.all([
        findUserById(db, userResult.id),
        findTrustedAuthByDeviceAndUser(db, input.deviceUuId, userResult.id),
      ]);

      if (!user) {
        throw new ORPCError("NOT_FOUND", {
          message: "User not found",
        });
      }

      const banned = await checkUserBanStatus(db, user);

      if (banned) {
        throw new ORPCError("FORBIDDEN", {
          message: "User account is banned",
        });
      }

      if (trustedAuth) {
        await deleteAuthByDeviceId(db, input.deviceUuId);

        const activeSessions = await findAuthsByUserId(db, user.id);

        if (activeSessions.length >= MAX_ACTIVE_DEVICES) {
          await deleteAuthByUserId(db, user.id);
        }

        await createAuthSession(
          db,
          crypto.randomUUID(),
          user.id,
          input.deviceUuId,
          true
        );

        const accessToken = await generateAccessToken(
          user.id,
          user.email,
          env.JWT_SECRET
        );

        return {
          success: true,
          message: "Logged in with trusted device",
          accessToken,
          deviceId: input.deviceUuId,
        };
      }

      await deleteAuthByDeviceId(db, input.deviceUuId);

      const existingOtp = await getOtpForDevice(
        db,
        input.deviceUuId,
        normalizedEmail
      );

      let otpValue: number;

      if (normalizedEmail === env.TEST_EMAIL) {
        otpValue = parseInt(env.TEST_OTP);
      } else if (existingOtp && !isOtpExpired(existingOtp)) {
        otpValue = existingOtp.otp;
      } else {
        otpValue = parseInt(generateOtp(5));
      }

      const expiredAt = new Date(Date.now() + 5 * 60 * 1000);

      if (existingOtp) {
        await updateOtp(db, existingOtp.id, otpValue, expiredAt);
      } else {
        await createOtp(
          db,
          crypto.randomUUID(),
          otpValue,
          normalizedEmail,
          input.deviceUuId,
          expiredAt
        );
      }

      if (normalizedEmail !== env.TEST_EMAIL) {
        await sendOtpEmail(env.RESEND_API_KEY, normalizedEmail, otpValue);
      }

      return {
        success: true,
        message: "OTP sent successfully",
      };
    }),

  verifyOtp: publicProcedure
    .route({
      method: "POST",
      path: "/auth/otp/verify-otp",
      tags: [OPENAPI_TAG],
    })
    .input(
      z.object({
        email: z.string().email(),
        otp: z.number(),
        deviceUuId: z.string().uuid(),
        isTrusted: z.boolean().optional(),
      })
    )
    .output(
      z.object({
        success: z.boolean(),
        accessToken: z.string().optional(),
        deviceId: z.string().optional(),
        message: z.string(),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get("db");
      const env = ctx.env;

      const normalizedEmail = normalizeEmail(input.email);

      const [user, otp] = await Promise.all([
        findUserByEmail(db, normalizedEmail),
        getOtpForDevice(db, input.deviceUuId, normalizedEmail),
      ]);

      if (!user) {
        throw new ORPCError("NOT_FOUND", {
          message: "User not found",
        });
      }

      const banned = await checkUserBanStatus(db, user);
      if (banned) {
        throw new ORPCError("FORBIDDEN", {
          message: "User account is banned",
        });
      }

      if (!otp) {
        throw new ORPCError("NOT_FOUND", {
          message: "OTP not found",
        });
      }

      if (isOtpExpired(otp)) {
        throw new ORPCError("BAD_REQUEST", {
          message: "OTP expired",
        });
      }

      if (otp.otp !== input.otp) {
        throw new ORPCError("UNAUTHORIZED", {
          message: "Invalid OTP",
        });
      }

      await deleteOtpByDeviceAndEmail(db, input.deviceUuId, normalizedEmail);

      const activeSessions = await findAuthsByUserId(db, user.id);

      if (activeSessions.length >= MAX_ACTIVE_DEVICES) {
        await deleteAuthByUserId(db, user.id);
      }

      const isTrusted = input.isTrusted ?? false;

      await createAuthSession(
        db,
        crypto.randomUUID(),
        user.id,
        input.deviceUuId,
        isTrusted
      );

      const accessToken = await generateAccessToken(
        user.id,
        user.email,
        env.JWT_SECRET
      );

      return {
        success: true,
        accessToken,
        deviceId: input.deviceUuId,
        message: "OTP verified successfully",
      };
    }),
  logout: protectedProcedure({ anyOf: ["user", "admin:auth:rw"] })
    .route({ method: "POST", path: "/auth/logout", tags: [OPENAPI_TAG] })
    .input(
      z.object({
        deviceId: z.string().uuid(),
      })
    )
    .output(
      z.object({
        success: z.boolean(),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get("db");
      const authUser = ctx.get("authUser");

      if (!authUser) {
        throw new ORPCError("UNAUTHORIZED", {
          message: "User not authenticated",
        });
      }

      const auth = await findAuthByDeviceId(db, input.deviceId);

      if (!auth) {
        throw new ORPCError("NOT_FOUND", {
          message: "Auth session not found",
        });
      }

      if (auth.userId !== authUser.id) {
        throw new ORPCError("FORBIDDEN", {
          message: "Unauthorized to logout this device",
        });
      }

      await deleteAuthByDeviceId(db, input.deviceId);

      return {
        success: true,
      };
    }),

  refreshToken: publicProcedure
    .route({ method: "POST", path: "/auth/refresh-token", tags: [OPENAPI_TAG] })
    .input(
      z.object({
        deviceId: z.string().uuid(),
      })
    )
    .output(
      z.object({
        accessToken: z.string(),
      })
    )
    .handler(async ({ input, context }) => {
      const ctx = context as TRPCContext;
      const db = ctx.get("db");
      const env = ctx.env;
      const { c } = ctx;

      const auth = await findAuthByDeviceId(db, input.deviceId);

      if (!auth) {
        throw new ORPCError("UNAUTHORIZED", {
          message: "Auth session not found",
        });
      }

      const authHeader = getAuthHeader(c);
      const token = extractTokenFromHeader(authHeader);

      const foundUser = await findUserById(db, auth.userId);

      if (!foundUser) {
        throw new ORPCError("UNAUTHORIZED", {
          message: "User not found",
        });
      }

      const banned = await checkUserBanStatus(db, foundUser);
      if (banned) {
        throw new ORPCError("FORBIDDEN", {
          message: "User account is banned",
        });
      }
      if (!token) {
        throw new ORPCError("UNAUTHORIZED", {
          message: "No token provided",
        });
      }
      try {
        const verified = await verify(token, env.JWT_SECRET, "HS256");
        const payload = verified as {
          userId: string;
          email: string;
          exp?: number;
        };

        if (payload.exp) {
          const currentTime = Math.floor(Date.now() / 1000);
          if (currentTime >= payload.exp) {
            throw new ORPCError("UNAUTHORIZED", {
              message: "Token expired",
            });
          }
        }

        if (payload.userId !== auth.userId) {
          throw new ORPCError("FORBIDDEN", {
            message: "Device does not belong to authenticated user",
          });
        }
      } catch (error) {
        if (error instanceof ORPCError) {
          throw error;
        }
        throw new ORPCError("UNAUTHORIZED", {
          message: "Invalid or expired token",
        });
      }

      const lastRefreshDate = auth.lastRefresh ?? new Date(0);
      const currentDateTime = new Date();
      const maxValidTime = new Date(
        lastRefreshDate.getTime() + 7 * 24 * 60 * 60 * 1000
      );

      if (currentDateTime >= maxValidTime) {
        throw new ORPCError("UNAUTHORIZED", {
          message: "Session expired",
        });
      }

      await updateAuthLastRefresh(db, auth.id);

      const accessToken = await generateAccessToken(
        auth.userId,
        foundUser.email,
        env.JWT_SECRET
      );

      return {
        accessToken,
      };
    }),
};
