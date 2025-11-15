import { Context } from 'hono';

import { DB } from './utils/db.utils';
import type { AuthUser, AuthSession } from './utils/auth.utils';

export type Env = {
  ENVIRONMENT: string;
  POSTGRES_CONNECTION_STRING: string;
  JWT_SECRET: string;
  RESEND_API_KEY: string;
  TEST_EMAIL: string;
  TEST_OTP: string;
};

export type HonoTypes = {
  Bindings: Env;
  Variables: {
    db: DB;
    language: string;
    authUser?: AuthUser;
    authSession?: AuthSession;
    authUserRoles?: string[];
    authIsAdmin?: boolean;
    authIsSuperAdmin?: boolean;
  };
};

export type HonoContext = Context<HonoTypes>;

export type TRPCContext = {
  env: Env;
  get: HonoContext['get'];
  set: HonoContext['set'];
  executionCtx: HonoContext['executionCtx'];
  c: HonoContext;
};

export function createTRPCContext(c: HonoContext): TRPCContext {
  return { env: c.env, get: c.get, set: c.set, executionCtx: c.executionCtx, c };
}

