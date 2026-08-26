import { db } from '../db/pool.js';
import type { CreateStockPayload, StockItem } from '../types/index.js';

export interface StockRow {
  id: string;
  stockholder_id: string;
  master_product_id: string | null;
  custom_product_name: string;
  category: string;
  price_per_unit: number;
  quantity_available: number;
  unit: string;
  is_available: boolean;
  image_url: string | null;
  delivery_radius_km: number;
  created_at: Date;
  updated_at: Date;
}

export function mapStockRow(row: StockRow): StockItem {
  return {
    id: row.id,
    stockholderId: row.stockholder_id,
    masterProductId: row.master_product_id,
    customProductName: row.custom_product_name,
    category: row.category,
    pricePerUnit: row.price_per_unit,
    quantityAvailable: row.quantity_available,
    unit: row.unit,
    isAvailable: row.is_available,
    imageUrl: row.image_url,
    deliveryRadiusKm: row.delivery_radius_km,
    createdAt: row.created_at.toISOString(),
    updatedAt: row.updated_at.toISOString(),
  };
}

export async function createStock(
  userId: string,
  payload: CreateStockPayload,
): Promise<StockItem> {
  const { rows } = await db.query<StockRow>(
    `INSERT INTO stockholder_inventory
       (stockholder_id, master_product_id, custom_product_name, category,
        price_per_unit, quantity_available, unit, is_available, image_url, delivery_radius_km)
     VALUES ($1, $2, $3, $4, $5, $6, $7, true, $8, $9)
     RETURNING *`,
    [
      userId,
      payload.masterProductId ?? null,
      payload.customProductName,
      payload.category,
      payload.pricePerUnit,
      payload.quantity,
      payload.unit,
      payload.imageUrl ?? null,
      payload.deliveryRadiusKm ?? 10,
    ],
  );
  return mapStockRow(rows[0]);
}

export async function countActiveStock(userId: string): Promise<number> {
  const { rows } = await db.query<{ count: string }>(
    `SELECT count(*)::text AS count
     FROM stockholder_inventory
     WHERE stockholder_id = $1 AND is_available = true`,
    [userId],
  );
  return Number(rows[0]?.count ?? 0);
}

export async function listStock(userId: string): Promise<StockItem[]> {
  const { rows } = await db.query<StockRow>(
    `SELECT id, stockholder_id, master_product_id, custom_product_name,
            category, price_per_unit, quantity_available, unit,
            is_available, image_url, delivery_radius_km, created_at, updated_at
     FROM stockholder_inventory
     WHERE stockholder_id = $1 AND is_available = true
     ORDER BY updated_at DESC`,
    [userId],
  );
  return rows.map(mapStockRow);
}

export interface UpdateStockPayload {
  customProductName?: string;
  category?: string;
  pricePerUnit?: number;
  quantity?: number;
  unit?: string;
  imageUrl?: string;
  deliveryRadiusKm?: number;
}

export async function updateStock(
  userId: string,
  stockId: string,
  payload: UpdateStockPayload,
): Promise<StockItem | null> {
  const fields: string[] = [];
  const values: unknown[] = [];
  let idx = 1;

  if (payload.customProductName !== undefined) {
    fields.push(`custom_product_name = $${idx++}`);
    values.push(payload.customProductName);
  }
  if (payload.category !== undefined) {
    fields.push(`category = $${idx++}`);
    values.push(payload.category);
  }
  if (payload.pricePerUnit !== undefined) {
    fields.push(`price_per_unit = $${idx++}`);
    values.push(payload.pricePerUnit);
  }
  if (payload.quantity !== undefined) {
    fields.push(`quantity_available = $${idx++}`);
    values.push(payload.quantity);
  }
  if (payload.unit !== undefined) {
    fields.push(`unit = $${idx++}`);
    values.push(payload.unit);
  }
  if (payload.imageUrl !== undefined) {
    fields.push(`image_url = $${idx++}`);
    values.push(payload.imageUrl);
  }
  if (payload.deliveryRadiusKm !== undefined) {
    fields.push(`delivery_radius_km = $${idx++}`);
    values.push(payload.deliveryRadiusKm);
  }

  if (fields.length === 0) return null;

  fields.push(`updated_at = now()`);

  const { rows } = await db.query<StockRow>(
    `UPDATE stockholder_inventory SET ${fields.join(', ')}
     WHERE id = $${idx} AND stockholder_id = $${idx + 1} AND is_available = true
     RETURNING *`,
    [...values, stockId, userId],
  );

  if (rows.length === 0) return null;
  return mapStockRow(rows[0]);
}

export async function deleteStock(
  userId: string,
  stockId: string,
): Promise<boolean> {
  const { rowCount } = await db.query(
    `DELETE FROM stockholder_inventory
     WHERE id = $1 AND stockholder_id = $2`,
    [stockId, userId],
  );
  return (rowCount ?? 0) > 0;
}
// ── Persistent image storage (DB-backed, survives Render restarts) ──

export async function saveStockImage(
  stockId: string,
  mimeType: string,
  data: Buffer,
): Promise<void> {
  await db.query(
    `INSERT INTO stock_images (stock_id, mime_type, data, updated_at)
     VALUES ($1, $2, $3, now())
     ON CONFLICT (stock_id)
     DO UPDATE SET mime_type = EXCLUDED.mime_type,
                   data = EXCLUDED.data,
                   updated_at = now()`,
    [stockId, mimeType, data],
  );
}

export async function getStockImage(
  stockId: string,
): Promise<{ mimeType: string; data: Buffer } | null> {
  const { rows } = await db.query<{
    mime_type: string;
    data: Buffer;
  }>(`SELECT mime_type, data FROM stock_images WHERE stock_id = $1`, [stockId]);
  const row = rows[0];
  if (!row) return null;
  return { mimeType: row.mime_type, data: row.data };
}
