import { drizzle } from 'drizzle-orm/neon-http';
import { Env } from '../context';
import * as schema from '../schemas';

export type DB = ReturnType<typeof getDb>;

export function getDb(env: Env) {
  return drizzle(env.POSTGRES_CONNECTION_STRING, {
    schema,
  });
}