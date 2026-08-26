import { randomInt } from 'node:crypto';
import { db, type DbClient } from '../db/pool.js';
import type { OrderItem, OrderStatus } from '../types/index.js';
import { sendSms } from './smsService.js';

function httpError(message: string, status: number): Error & { status: number } {
  const error = new Error(message) as Error & { status: number };
  error.status = status;
  return error;
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

function generateOtp(): string {
  return String(randomInt(100000, 1_000_000));
}

/**
 * Supplier accepts a pending order.
 * Status: pending → accepted
 */
export async function acceptOrder(
  orderId: string,
  supplierId: string,
): Promise<{ order: OrderItem; message: string }> {
  const client: DbClient = await db.connect();
  try {
    await client.query('BEGIN');

    const { rows } = await client.query(
      `SELECT id, supplier_id, status, shop_owner_id, product_name
       FROM orders WHERE id = $1 FOR UPDATE`,
      [orderId],
    );

    const order = rows[0];
    if (!order) throw httpError('Order not found', 404);
    if (order.supplier_id !== supplierId) {
      throw httpError('You are not the supplier of this order', 403);
    }
    if (order.status !== 'pending') {
      throw httpError(`Order is already ${order.status}`, 409);
    }

    await client.query(
      `UPDATE orders SET status = 'accepted', updated_at = now() WHERE id = $1`,
      [orderId],
    );

    // Deduct stock on acceptance
    const { rows: orderDetail } = await client.query(
      `SELECT product_name, quantity, supplier_id, inventory_id FROM orders WHERE id = $1`,
      [orderId],
    );
    if (orderDetail[0]) {
      const od = orderDetail[0];
      // Try by inventory_id first, fall back to name match
      const invRows = await client.query<{ id: string }>(
        `SELECT COALESCE(
           (SELECT o.inventory_id FROM orders o WHERE o.id = $1),
           (SELECT si.id FROM public.stockholder_inventory si
            WHERE si.stockholder_id = $2
              AND LOWER(si.custom_product_name) = LOWER($3)
            LIMIT 1)
         ) AS id`,
        [orderId, od.supplier_id, od.product_name],
      );
      const linkedInventoryId = invRows.rows[0]?.id;
      if (linkedInventoryId) {
        await client.query(
          `UPDATE public.stockholder_inventory
           SET quantity_available = GREATEST(0, quantity_available - $1),
               is_available = CASE WHEN (quantity_available - $1) <= 0 THEN false ELSE is_available END
           WHERE id = $2`,
          [od.quantity, linkedInventoryId],
        );
        if (!od.inventory_id) {
          await client.query(`UPDATE orders SET inventory_id = $1 WHERE id = $2`, [
            linkedInventoryId, orderId,
          ]);
        }
      }
    }

    // Notify shop owner
    await client.query(
      `INSERT INTO notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'order_accepted')`,
      [
        order.shop_owner_id,
        'Order accepted',
        `Your order for ${order.product_name} has been accepted.`,
      ],
    );

    await client.query('COMMIT');

    const { rows: updated } = await client.query(
      `SELECT * FROM orders WHERE id = $1`, [orderId],
    );

    return {
      order: mapOrderRow(updated[0]),
      message: 'Order accepted',
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Supplier declines a pending order.
 * Status: pending → cancelled
 */
export async function declineOrder(
  orderId: string,
  supplierId: string,
): Promise<{ message: string }> {
  const client: DbClient = await db.connect();
  try {
    await client.query('BEGIN');

    const { rows } = await client.query(
      `SELECT id, supplier_id, status, shop_owner_id, product_name
       FROM orders WHERE id = $1 FOR UPDATE`,
      [orderId],
    );

    const order = rows[0];
    if (!order) throw httpError('Order not found', 404);
    if (order.supplier_id !== supplierId) {
      throw httpError('You are not the supplier of this order', 403);
    }
    if (order.status !== 'pending') {
      throw httpError(`Order is already ${order.status}`, 409);
    }

    await client.query(
      `UPDATE orders SET status = 'cancelled', updated_at = now() WHERE id = $1`,
      [orderId],
    );

    // Restore stock
    const { rows: orderDetail } = await client.query(
      `SELECT product_name, quantity, supplier_id FROM orders WHERE id = $1`,
      [orderId],
    );
    if (orderDetail[0]) {
      await client.query(
        `UPDATE stockholder_inventory
         SET quantity_available = quantity_available + $1
         WHERE stockholder_id = $2 AND custom_product_name ILIKE '%' || $3 || '%'
         LIMIT 1`,
        [orderDetail[0].quantity, orderDetail[0].supplier_id, orderDetail[0].product_name],
      );
    }

    // Notify shop owner
    await client.query(
      `INSERT INTO notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'order_cancelled')`,
      [
        order.shop_owner_id,
        'Order declined',
        `Your order for ${order.product_name} has been declined.`,
      ],
    );

    await client.query('COMMIT');

    return { message: 'Order declined' };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Supplier marks order as out for delivery.
 * Generates a 6-digit OTP and sends it to the shop owner.
 * Status: accepted → out_for_delivery
 */
export async function markOutOfDelivery(
  orderId: string,
  supplierId: string,
): Promise<{ order: OrderItem; message: string }> {
  const client: DbClient = await db.connect();
  try {
    await client.query('BEGIN');

    const { rows } = await client.query(
      `SELECT id, supplier_id, status, shop_owner_id, product_name
       FROM orders WHERE id = $1 FOR UPDATE`,
      [orderId],
    );

    const order = rows[0];
    if (!order) throw httpError('Order not found', 404);
    if (order.supplier_id !== supplierId) {
      throw httpError('You are not the supplier of this order', 403);
    }
    if (order.status !== 'accepted') {
      throw httpError(`Order is ${order.status}, must be accepted first`, 409);
    }

    const otp = generateOtp();

    // Store OTP directly on the order
    await client.query(
      `UPDATE orders
       SET status = 'out_for_delivery', delivery_otp = $1, updated_at = now()
       WHERE id = $2`,
      [otp, orderId],
    );

    // Also keep the otps table in sync for backward compatibility
    await client.query(
      `INSERT INTO otps (order_id, otp_code)
       VALUES ($1, $2)
       ON CONFLICT (order_id)
       DO UPDATE SET otp_code = EXCLUDED.otp_code,
                     is_verified = false,
                     expires_at = now() + interval '24 hours'`,
      [orderId, otp],
    );

    // Notify shop owner with OTP
    await client.query(
      `INSERT INTO notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'delivery_otp')`,
      [
        order.shop_owner_id,
        'Order Out for Delivery!',
        `Your delivery OTP is ${otp}. Share this 6-digit code with the delivery person upon arrival.`,
      ],
    );

    // Fetch user phone number for SMS
    const userQuery = await client.query(
      `SELECT phone_number, business_name FROM users WHERE id = $1`,
      [order.shop_owner_id],
    );

    await client.query('COMMIT');
    
    // Send SMS asynchronously after commit
    if (userQuery.rows.length > 0) {
      const phone = userQuery.rows[0].phone_number;
      sendSms(phone, `TradeLink: Your delivery OTP is ${otp} for order ${order.product_name}. Share this 6-digit code with the delivery person.`);
    }

    const { rows: updated } = await client.query(
      `SELECT * FROM orders WHERE id = $1`, [orderId],
    );

    return {
      order: mapOrderRow(updated[0]),
      message: 'Out for delivery. OTP sent to shop owner.',
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Supplier verifies OTP to confirm delivery.
 * The supplier asks the shop owner for the OTP verbally, then enters it here.
 * Status: out_for_delivery → delivered
 */
export async function confirmDeliveryWithOtp(
  orderId: string,
  supplierId: string,
  otpInput: string,
): Promise<{ order: OrderItem; message: string }> {
  const client: DbClient = await db.connect();
  try {
    await client.query('BEGIN');

    const { rows } = await client.query(
      `SELECT id, supplier_id, shop_owner_id, status, delivery_otp, product_name, quantity, inventory_id
       FROM orders WHERE id = $1 FOR UPDATE`,
      [orderId],
    );

    const order = rows[0];
    if (!order) throw httpError('Order not found', 404);
    if (order.supplier_id !== supplierId) {
      throw httpError('You are not the supplier of this order', 403);
    }
    if (order.status !== 'out_for_delivery') {
      throw httpError(`Order is ${order.status}, not ready for delivery confirmation`, 409);
    }

    if (!order.delivery_otp) {
      throw httpError('No OTP generated yet. Mark the order out for delivery first.', 400);
    }

    if (order.delivery_otp !== otpInput.trim()) {
      throw httpError('Invalid OTP. Please ask the shop owner for the correct 6-digit code.', 400);
    }

    // Mark delivered
    await client.query(
      `UPDATE orders SET status = 'delivered', updated_at = now() WHERE id = $1`,
      [orderId],
    );

    // Mark OTP as verified
    await client.query(
      `UPDATE otps SET is_verified = true WHERE order_id = $1`,
      [orderId],
    );

    // Subtract delivered quantity from the supplier's inventory.
    // Resolves the stock item by inventory_id, falling back to a
    // product_name + supplier match for legacy orders.
    const invRows = await client.query<{ id: string }>(
      `SELECT COALESCE(
         (SELECT o.inventory_id FROM orders o WHERE o.id = $1),
         (SELECT si.id FROM public.stockholder_inventory si
          WHERE si.stockholder_id = $2
            AND LOWER(si.custom_product_name) = LOWER($3)
          LIMIT 1)
       ) AS id`,
      [orderId, order.supplier_id, order.product_name],
    );
    const linkedInventoryId = invRows.rows[0]?.id;

    if (!linkedInventoryId) {
      console.warn(`[orderLifecycle] No inventory match found for order ${orderId} — stock not deducted`);
    }

    if (linkedInventoryId) {
      await client.query(
        `UPDATE public.stockholder_inventory
         SET quantity_available = GREATEST(0, quantity_available - $1),
             is_available = CASE WHEN (quantity_available - $1) <= 0 THEN false ELSE is_available END
         WHERE id = $2`,
        [order.quantity, linkedInventoryId],
      );
      // Persist the link so reviews and future deductions target this item
      if (!order.inventory_id) {
        await client.query(`UPDATE orders SET inventory_id = $1 WHERE id = $2`, [
          linkedInventoryId,
          orderId,
        ]);
      }
    }

    // Notify shop owner: delivery completed
    // Look up inventory_id for the product so Flutter can attach the review to it
    const invResult = await client.query(
      `SELECT id FROM public.stockholder_inventory
       WHERE stockholder_id = $1 AND LOWER(custom_product_name) = LOWER($2)
       LIMIT 1`,
      [order.supplier_id, order.product_name],
    );
    const inventoryId = invResult.rows.length > 0 ? invResult.rows[0].id : '';

    await client.query(
      `INSERT INTO notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'delivery_confirmed')`,
      [
        order.shop_owner_id,
        'Order Delivered!',
        `Your order for ${order.product_name} is complete. Tap to leave an optional review.\n|||${orderId}|||${order.supplier_id}|||${inventoryId}`,
      ],
    );

    await client.query('COMMIT');

    const { rows: updated } = await client.query(
      `SELECT * FROM orders WHERE id = $1`, [orderId],
    );

    return {
      order: mapOrderRow(updated[0]),
      message: 'Delivery confirmed!',
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
