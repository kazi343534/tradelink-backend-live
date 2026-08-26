import { db } from '../db/pool.js';
import type { OrderItem } from '../types/index.js';

function httpError(message: string, status: number): Error & { status: number } {
  const err = Object.assign(new Error(message), { status });
  return err;
}

export interface DirectOrderPayload {
  stockId: string;
  quantity: number;
  deliveryAddress?: string;
}

export interface DirectOrderResponse {
  order: OrderItem;
  message: string;
}

function mapOrderRow(row: any): OrderItem {
  return {
    id: row.id,
    demandId: row.demand_id ?? null,
    shopOwnerId: row.shop_owner_id,
    supplierId: row.supplier_id,
    inventoryId: row.inventory_id ?? null,
    productName: row.product_name,
    quantity: Number(row.quantity),
    unit: row.unit,
    totalAmount: Number(row.total_amount),
    unitPrice: row.unit_price != null ? Number(row.unit_price) : null,
    paymentStatus: row.payment_status ?? undefined,
    status: row.status,
    deliveryAddress: row.delivery_address ?? null,
    deliveryOtp: row.delivery_otp ?? null,
    createdAt: row.created_at,
  };
}

/**
 * Create a direct order from a shop owner to a supplier's inventory item.
 * No demand is involved — the shop owner picks a product and orders it directly.
 */
export async function createDirectOrder(
  shopOwnerId: string,
  payload: DirectOrderPayload,
): Promise<DirectOrderResponse> {
  const client = await db.connect();
  try {
    await client.query('BEGIN');

    // 1. Lock and validate the stock item
    const { rows: stockRows } = await client.query<{
      id: string;
      stockholder_id: string;
      custom_product_name: string;
      price_per_unit: number;
      quantity_available: number;
      unit: string;
    }>(
      `SELECT id, stockholder_id, custom_product_name, price_per_unit, quantity_available, unit
       FROM stockholder_inventory
       WHERE id = $1 AND is_available = true
       FOR UPDATE`,
      [payload.stockId],
    );

    const stock = stockRows[0];
    if (!stock) throw httpError('Product not found or unavailable', 404);

    if (stock.quantity_available < payload.quantity) {
      throw httpError(
        `Insufficient stock. Only ${stock.quantity_available} ${stock.unit} available.`,
        409,
      );
    }

    if (shopOwnerId === stock.stockholder_id) {
      throw httpError('You cannot order your own product', 400);
    }

    // 2. Calculate total
    const totalAmount = stock.price_per_unit * payload.quantity;

    // NOTE: Stock is NOT deducted here. Quantity is subtracted from
    // inventory only when delivery OTP is verified (orderLifecycleService)
    // so failed/cancelled orders never lose stock.

    // 3. Create the order as PENDING (supplier must accept)
    const { rows: orderRows } = await client.query(
      `INSERT INTO orders
         (shop_owner_id, supplier_id, inventory_id, product_name, quantity, unit, unit_price, total_amount, status, delivery_address)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending', $9)
       RETURNING *`,
      [
        shopOwnerId,
        stock.stockholder_id,
        stock.id,
        stock.custom_product_name,
        payload.quantity,
        stock.unit,
        stock.price_per_unit,
        totalAmount,
        payload.deliveryAddress ?? null,
      ],
    );

    // 4. Notify the supplier
    await client.query(
      `INSERT INTO notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'new_order')`,
      [
        stock.stockholder_id,
        'New order received',
        `Order for ${stock.custom_product_name} (${payload.quantity} ${stock.unit}) — ৳${totalAmount}`,
      ],
    );

    await client.query('COMMIT');

    return {
      order: mapOrderRow(orderRows[0]),
      message: `Order placed! ${stock.custom_product_name} × ${payload.quantity} ${stock.unit} — ৳${totalAmount}`,
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
