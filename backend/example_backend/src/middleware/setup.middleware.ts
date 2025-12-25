import type { Context, Next } from "hono";
import type { HonoTypes } from "../context";
import { createTRPCContext } from "../context";
import { getDb } from "../utils/db.utils";

export async function setupContext(c: Context<HonoTypes>, next: Next) {
  const db = getDb(c.env);
  c.set("db", db);
  c.set("language", "en");

  await next();
}

export function getContextForHandler(c: Context<HonoTypes>) {
  return createTRPCContext(c);
}

