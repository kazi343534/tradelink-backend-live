import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import { db } from '../db/pool.js';

export interface OrderRow {
  id: string;
  demand_id: string | null;
  shop_owner_id: string;
  supplier_id: string;
  product_name: string;
  quantity: number;
  unit: string;
  total_amount: number;
  status: string;
  delivery_address: string | null;
  created_at: Date;
}

function mapOrderRow(row: OrderRow) {
  return {
    id: row.id,
    demandId: row.demand_id,
    shopOwnerId: row.shop_owner_id,
    supplierId: row.supplier_id,
    productName: row.product_name,
    quantity: row.quantity,
    unit: row.unit,
    totalAmount: row.total_amount,
    status: row.status,
    deliveryAddress: row.delivery_address,
    createdAt: row.created_at.toISOString(),
  };
}

export const listOrdersHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const userId = req.userId!;
    const { rows } = await db.query<OrderRow>(
      `SELECT id, demand_id, shop_owner_id, supplier_id, product_name,
              quantity, unit, total_amount, status, delivery_address, created_at
       FROM orders
       WHERE supplier_id = $1
       ORDER BY created_at DESC
       LIMIT 50`,
      [userId],
    );
    res.json({ success: true, data: rows.map(mapOrderRow) });
  },
);
