import { createHmac, timingSafeEqual } from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';
import { env } from '../config/env.js';
import { db } from '../db/pool.js';
import type { UserRole } from '../types/index.js';

export interface AuthRequest extends Request {
  userId?: string;
  role?: UserRole;
}

/**
 * Authenticates the caller and attaches `userId` + `role` to the request.
 *
 * - Supabase mode: expects `Authorization: Bearer <JWT>`, verifies the
 *   signature with the Supabase JWT secret, then resolves the public
 *   `users.id` from the token's `sub` (auth.users.id) via the `auth_id`
 *   column and derives the role from the `users.role` column.
 * - Dev mode: accepts a plain `X-User-Id` header (no DB / auth required).
 */
export function requireAuth(
  req: AuthRequest,
  res: Response,
  next: NextFunction,
): void {
  if (env.demoMode) {
    const headerId = req.header('X-User-Id');
    if (!headerId) {
      res.status(401).json({ error: 'X-User-Id header required in demo mode' });
      return;
    }
    const [userId, role] = headerId.split('::');
    req.userId = userId;
    req.role = role === 'shop_owner' ? 'shop_owner' : 'supplier';
    next();
    return;
  }

  const token = req.header('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) {
    res.status(401).json({ error: 'Missing bearer token' });
    return;
  }

  let sub: string;
  try {
    const payload = verifyJwt(token);
    sub = payload.sub as string;
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
    return;
  }

  void resolveUserIdAndRole(sub)
    .then((resolved) => {
      if (!resolved) {
        res.status(401).json({ error: 'No profile found for this account' });
        return;
      }
      req.userId = resolved.userId;
      req.role = resolved.role;
      next();
    })
    .catch(() => {
      res.status(500).json({ error: 'Failed to load profile' });
    });
}

async function resolveUserIdAndRole(
  authId: string,
): Promise<{ userId: string; role: UserRole } | null> {
  const { rows } = await db.query<{ id: string; role: UserRole }>(
    `SELECT id, role FROM users WHERE auth_id = $1 LIMIT 1`,
    [authId],
  );
  const row = rows[0];
  if (!row) return null;
  return {
    userId: row.id,
    role: row.role === 'shop_owner' ? 'shop_owner' : 'supplier',
  };
}

/** Require the authenticated user to be a supplier. */
export function requireSupplier(
  req: AuthRequest,
  res: Response,
  next: NextFunction,
): void {
  if (req.role !== 'supplier') {
    res.status(403).json({ error: 'Supplier role required' });
    return;
  }
  next();
}

interface JwtPayload {
  sub?: string;
}

function verifyJwt(token: string): JwtPayload {
  if (!env.jwtSecret) {
    throw new Error('JWT_SECRET not configured');
  }
  const [header, payload, signature] = token.split('.');
  if (!header || !payload || !signature) {
    throw new Error('Malformed token');
  }

  const expected = createHmac('sha256', env.jwtSecret)
    .update(`${header}.${payload}`)
    .digest();
  const provided = base64UrlToBytes(signature);

  if (!timingSafeEqual(expected, provided)) {
    throw new Error('Signature mismatch');
  }

  return JSON.parse(base64UrlToString(payload)) as JwtPayload;
}

function base64UrlToString(value: string): string {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=');
  return Buffer.from(padded, 'base64').toString('utf8');
}

function base64UrlToBytes(value: string): Buffer {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=');
  return Buffer.from(padded, 'base64');
}