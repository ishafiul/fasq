import { os, ORPCError } from '@orpc/server';
import { verify } from 'hono/jwt';
import type { TRPCContext } from '../context';
import type { PermissionString } from '../utils/permission.utils';
import { checkPermissions, getAuthHeader, authIsAdmin, authIsSuperAdmin } from '../utils/auth.utils';
import { userRole } from '../schemas/user.schema';
import { users } from '../schemas/user.schema';
import { eq } from 'drizzle-orm';
import { findAuthByUserId } from '../repositories/auth.repository';
import { isUserBanned } from '../repositories/user.repository';

export type ProcedurePermissions =
  | {
      anyOf: PermissionString[];
      allOf?: never;
    }
  | {
      anyOf?: never;
      allOf: PermissionString[];
    };

function extractTokenFromHeader(authHeader: string | null | undefined): string | null {
  if (!authHeader) {
    return null;
  }

  if (authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }

  return null;
}

export function protectedProcedure(permissions: ProcedurePermissions) {
  return os.use(async ({ context, next }) => {
    const ctx = context as TRPCContext;
    const { c } = ctx;
    const db = c.get('db');

    const authHeader = getAuthHeader(c);
    const token = extractTokenFromHeader(authHeader);

    if (!token) {
      throw new ORPCError('UNAUTHORIZED', {
        message: 'No token provided',
      });
    }

    const jwtSecret = ctx.env.JWT_SECRET;

    let payload: { userId: string; email: string };
    try {
      const verified = await verify(token, jwtSecret, 'HS256');
      payload = verified as { userId: string; email: string };
    } catch (error) {
      throw new ORPCError('UNAUTHORIZED', {
        message: 'Invalid or expired token',
      });
    }

    const [foundUser] = await db.select().from(users).where(eq(users.id, payload.userId)).limit(1);

    if (!foundUser) {
      throw new ORPCError('UNAUTHORIZED', {
        message: 'User not found',
      });
    }

    const banned = await isUserBanned(db, payload.userId);
    if (banned) {
      throw new ORPCError('FORBIDDEN', {
        message: 'User account is banned',
      });
    }

    const authSession = await findAuthByUserId(db, payload.userId);

    if (!authSession) {
      throw new ORPCError('UNAUTHORIZED', {
        message: 'Session not found or expired',
      });
    }

    const foundUserRoles = await db
      .select()
      .from(userRole)
      .where(eq(userRole.userId, payload.userId));

    if (!foundUserRoles.length) {
      throw new ORPCError('UNAUTHORIZED', {
        message: 'No roles assigned',
      });
    }

    const userRolesList = foundUserRoles.map((userRole) => userRole.role);

    const hasPermission = checkPermissions(userRolesList, permissions);

    if (!hasPermission) {
      throw new ORPCError('FORBIDDEN', {
        message: 'Insufficient permissions',
      });
    }

    c.set('authUser', {
      id: foundUser.id,
      email: foundUser.email,
      name: foundUser.name,
    });

    c.set('authSession', {
      userId: payload.userId,
      email: payload.email,
    });

    c.set('authUserRoles', userRolesList);
    c.set('authIsAdmin', authIsAdmin(userRolesList));
    c.set('authIsSuperAdmin', authIsSuperAdmin(userRolesList));

    return next();
  });
}

