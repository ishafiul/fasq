import { sign } from 'hono/jwt';

const ACCESS_TOKEN_EXPIRY = 2 * 24 * 60 * 60;

export async function generateAccessToken(
  userId: string,
  email: string,
  jwtSecret: string
): Promise<string> {
  const payload = {
    userId,
    email,
    exp: Math.floor(Date.now() / 1000) + ACCESS_TOKEN_EXPIRY,
    iat: Math.floor(Date.now() / 1000),
    type: 'access',
  };

  return await sign(payload, jwtSecret, 'HS256');
}

