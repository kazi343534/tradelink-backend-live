import { db } from '../db/pool.js';

export interface UserProfile {
  id: string;
  role: string;
  fullName: string;
  phoneNumber: string;
  businessName: string;
  category: string;
  tradeLicense: string | null;
  minOrderValue: number;
  supplyRadius: string | null;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  rating: number;
  activeOrders: number;
  totalDemands: number;
  totalFulfilled: number;
  createdAt: string;
  updatedAt: string;
}

interface UserRow {
  id: string;
  role: string;
  full_name: string;
  phone_number: string;
  business_name: string;
  category: string;
  trade_license: string | null;
  min_order_value: number;
  supply_radius: string | null;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  rating: number | string | null;
  active_orders: number;
  total_demands: number;
  total_fulfilled: number;
  created_at: Date;
  updated_at: Date;
}

function mapProfileRow(row: UserRow): UserProfile {
  return {
    id: row.id,
    role: row.role,
    fullName: row.full_name,
    phoneNumber: row.phone_number,
    businessName: row.business_name,
    category: row.category,
    tradeLicense: row.trade_license,
    minOrderValue: row.min_order_value,
    supplyRadius: row.supply_radius,
    latitude: row.latitude,
    longitude: row.longitude,
    address: row.address,
    rating: Number(row.rating ?? 5),
    activeOrders: Number(row.active_orders ?? 0),
    totalDemands: Number(row.total_demands ?? 0),
    totalFulfilled: Number(row.total_fulfilled ?? 0),
    createdAt: row.created_at.toISOString(),
    updatedAt: row.updated_at.toISOString(),
  };
}

export async function getProfile(userId: string): Promise<UserProfile | null> {
  const { rows } = await db.query<UserRow>(
    `SELECT id, role, full_name, phone_number, business_name, category,
            trade_license, min_order_value, supply_radius,
            latitude, longitude, address,
            rating,
            (SELECT COUNT(*)::int FROM orders o
              WHERE o.shop_owner_id = users.id
                AND o.status IN ('accepted','out_for_delivery','in_transit')
            ) AS active_orders,
            (SELECT COUNT(*)::int FROM demands d
              WHERE d.shop_owner_id = users.id
            ) AS total_demands,
            (SELECT COUNT(*)::int FROM orders o2
              WHERE o2.supplier_id = users.id AND o2.status = 'delivered'
            ) AS total_fulfilled,
            created_at, updated_at
     FROM users
     WHERE id = $1`,
    [userId],
  );
  if (rows.length === 0) return null;
  return mapProfileRow(rows[0]);
}

export interface UpdateProfilePayload {
  fullName?: string;
  phoneNumber?: string;
  businessName?: string;
  category?: string;
  tradeLicense?: string;
  minOrderValue?: number;
  supplyRadius?: string;
  address?: string;
  latitude?: number;
  longitude?: number;
}

export async function updateProfile(
  userId: string,
  payload: UpdateProfilePayload,
): Promise<UserProfile | null> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let idx = 1;

  if (payload.fullName !== undefined) {
    fields.push(`full_name = $${idx++}`);
    values.push(payload.fullName);
  }
  if (payload.phoneNumber !== undefined) {
    fields.push(`phone_number = $${idx++}`);
    values.push(payload.phoneNumber);
  }
  if (payload.businessName !== undefined) {
    fields.push(`business_name = $${idx++}`);
    values.push(payload.businessName);
  }
  if (payload.category !== undefined) {
    fields.push(`category = $${idx++}`);
    values.push(payload.category);
  }
  if (payload.tradeLicense !== undefined) {
    fields.push(`trade_license = $${idx++}`);
    values.push(payload.tradeLicense);
  }
  if (payload.minOrderValue !== undefined) {
    fields.push(`min_order_value = $${idx++}`);
    values.push(payload.minOrderValue);
  }
  if (payload.supplyRadius !== undefined) {
    // Store NULL for empty/non-numeric input — never the string "null"
    const raw = (payload.supplyRadius ?? '').toString().trim();
    const parsed = parseFloat(raw);
    fields.push(`supply_radius = $${idx++}`);
    values.push(raw !== '' && Number.isFinite(parsed) ? raw : null);
  }
  if (payload.address !== undefined) {
    fields.push(`address = $${idx++}`);
    values.push(payload.address);
  }
  if (payload.latitude !== undefined) {
    fields.push(`latitude = $${idx++}`);
    values.push(payload.latitude);
  }
  if (payload.longitude !== undefined) {
    fields.push(`longitude = $${idx++}`);
    values.push(payload.longitude);
  }

  if (fields.length === 0) return getProfile(userId);

  fields.push(`updated_at = now()`);

  await db.query(
    `UPDATE users SET ${fields.join(', ')}
     WHERE id = $${idx}`,
    [...values, userId],
  );

  return getProfile(userId);
}
