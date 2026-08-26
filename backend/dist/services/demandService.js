import { randomInt } from 'node:crypto';
import { db } from '../db/pool.js';
import { sendSms } from './smsService.js';
export function mapOrderRow(row) {
    return {
        id: row.id,
        demandId: row.demand_id,
        shopOwnerId: row.shop_owner_id,
        supplierId: row.supplier_id,
        inventoryId: row.inventory_id ?? null,
        productName: row.product_name,
        quantity: row.quantity,
        unit: row.unit,
        totalAmount: row.total_amount,
        unitPrice: row.unit_price != null ? Number(row.unit_price) : null,
        paymentStatus: row.payment_status ?? undefined,
        status: row.status,
        deliveryAddress: row.delivery_address,
        deliveryOtp: row.delivery_otp ?? null,
        createdAt: row.created_at.toISOString(),
    };
}
export function mapNotificationRow(row) {
    return {
        id: row.id,
        userId: row.user_id,
        title: row.title,
        subtitle: row.subtitle,
        type: row.type,
        isRead: row.is_read,
        createdAt: row.created_at.toISOString(),
    };
}
export function generateDeliveryOtp() {
    return String(randomInt(100000, 1_000_000));
}
function httpError(message, status) {
    const error = new Error(message);
    error.status = status;
    return error;
}
/**
 * Accept a demand inside a DB transaction:
 *   1. update demand.status -> 'accepted' + accepted_supplier_id
 *   2. create orders row (status 'accepted')
 *   3. insert a notification for the shop owner
 *
 * No OTP is issued here — the delivery OTP is generated later, when the
 * supplier confirms the order for delivery (see confirmDelivery).
 */
export async function acceptDemand(demandId, supplierId, businessName) {
    const client = await db.connect();
    try {
        await client.query('BEGIN');
        const demand = await client.query(`SELECT id, shop_owner_id, product_name, quantity, unit, status,
              target_supplier_id
       FROM demands WHERE id = $1 FOR UPDATE`, [demandId]);
        const demandRow = demand.rows[0];
        if (!demandRow)
            throw httpError('Demand not found', 404);
        // 'open' is the canonical open status; 'pending' kept for legacy rows
        if (demandRow.status !== 'open' && demandRow.status !== 'pending') {
            throw httpError(`Demand already ${demandRow.status}`, 409);
        }
        // Targeted requests (chatbot / marketplace) are exclusive to their target
        if (demandRow.target_supplier_id &&
            demandRow.target_supplier_id !== supplierId) {
            throw httpError('This request was sent to another supplier', 403);
        }
        await client.query(`UPDATE demands
       SET status = 'accepted', accepted_supplier_id = $1, accepted_at = now()
       WHERE id = $2`, [supplierId, demandId]);
        const { rows: stockRows } = await client.query(`SELECT id, price_per_unit
       FROM stockholder_inventory
       WHERE stockholder_id = $1 AND is_available = true
         AND custom_product_name ILIKE '%' || $2 || '%'
       ORDER BY created_at DESC
       LIMIT 1`, [supplierId, demandRow.product_name]);
        const matchedStockId = stockRows[0]?.id ?? null;
        const pricePerUnit = stockRows[0]?.price_per_unit ?? 0;
        const totalAmount = demandRow.quantity * pricePerUnit;
        const order = await client.query(`INSERT INTO orders
         (demand_id, shop_owner_id, supplier_id, inventory_id, product_name, quantity, unit, unit_price, total_amount, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'accepted')
       RETURNING *`, [
            demandId,
            demandRow.shop_owner_id,
            supplierId,
            matchedStockId,
            demandRow.product_name,
            demandRow.quantity,
            demandRow.unit,
            pricePerUnit,
            totalAmount,
        ]);
        await client.query(`INSERT INTO notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'order_accepted')`, [
            demandRow.shop_owner_id,
            'Order accepted by ' + businessName,
            `Your demand for ${demandRow.product_name} is now pending delivery.`,
        ]);
        await client.query('COMMIT');
        return {
            order: mapOrderRow(order.rows[0]),
            demandId,
            message: 'Demand accepted',
        };
    }
    catch (err) {
        await client.query('ROLLBACK');
        throw err;
    }
    finally {
        client.release();
    }
}
/** Decline a demand and remove it from the supplier's feed. */
export async function declineDemand(demandId) {
    const demand = await db.query(`SELECT id, status FROM demands WHERE id = $1`, [demandId]);
    const row = demand.rows[0];
    if (!row)
        throw httpError('Demand not found', 404);
    if (row.status !== 'open' && row.status !== 'pending') {
        throw httpError(`Demand already ${row.status}`, 409);
    }
    await db.query(`UPDATE demands SET status = 'cancelled' WHERE id = $1`, [
        demandId,
    ]);
    return { demandId, message: 'Demand declined' };
}
/** Shop owner cancels their own demand. */
export async function cancelDemand(demandId, shopOwnerId) {
    const demand = await db.query(`SELECT id, status, shop_owner_id FROM demands WHERE id = $1`, [demandId]);
    const row = demand.rows[0];
    if (!row)
        throw httpError('Demand not found', 404);
    if (row.shop_owner_id !== shopOwnerId) {
        throw httpError('You can only cancel your own demands', 403);
    }
    if (row.status !== 'open' && row.status !== 'pending') {
        throw httpError(`Demand already ${row.status}`, 409);
    }
    await db.query(`UPDATE demands SET status = 'cancelled' WHERE id = $1`, [
        demandId,
    ]);
    return { demandId, message: 'Demand cancelled successfully' };
}
/**
 * Supplier (deliveryman) confirms the order for delivery:
 *   1. lock + validate the order belongs to this supplier and is 'accepted'
 *   2. generate a fresh 6-digit OTP and store it on the order
 *      (replaces any previous OTP via ON CONFLICT)
 *   3. move the order to 'in_transit'
 *   4. notify the SHOP OWNER with the OTP — they read it out to the
 *      deliveryman at handover to verify receipt
 *
 * The OTP is never returned to the supplier.
 */
export async function confirmDelivery(orderId, supplierId) {
    const client = await db.connect();
    try {
        await client.query('BEGIN');
        const order = await client.query(`SELECT id, demand_id, shop_owner_id, supplier_id, product_name,
              quantity, unit, total_amount, status, delivery_address, created_at
       FROM orders WHERE id = $1 FOR UPDATE`, [orderId]);
        const orderRow = order.rows[0];
        if (!orderRow)
            throw httpError('Order not found', 404);
        if (orderRow.supplier_id !== supplierId) {
            throw httpError('You are not the supplier of this order', 403);
        }
        if (orderRow.status === 'in_transit') {
            throw httpError('Delivery already confirmed for this order', 409);
        }
        if (orderRow.status !== 'accepted') {
            throw httpError(`Order is ${orderRow.status}, cannot confirm delivery`, 409);
        }
        const otp = generateDeliveryOtp();
        await client.query(`INSERT INTO otps (order_id, otp_code)
       VALUES ($1, $2)
       ON CONFLICT (order_id)
       DO UPDATE SET otp_code = EXCLUDED.otp_code,
                     is_verified = false,
                     expires_at = now() + interval '24 hours'`, [orderId, otp]);
        await client.query(`UPDATE orders SET status = 'in_transit' WHERE id = $1`, [orderId]);
        // Notify shop owner with OTP
        await client.query(`INSERT INTO notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'delivery_otp')`, [
            orderRow.shop_owner_id,
            'Your delivery OTP',
            `Share this OTP with the deliveryman to receive ${orderRow.product_name}: ${otp}`,
        ]);
        // Fetch user phone number for SMS
        const userQuery = await client.query(`SELECT phone_number, business_name FROM users WHERE id = $1`, [orderRow.shop_owner_id]);
        await client.query('COMMIT');
        // Send SMS asynchronously after commit
        if (userQuery.rows.length > 0) {
            const phone = userQuery.rows[0].phone_number;
            sendSms(phone, `TradeLink: Your delivery OTP is ${otp} for order ${orderRow.product_name}. Share this 6-digit code with the delivery person.`);
        }
        return {
            orderId,
            status: 'in_transit',
            message: 'Delivery confirmed. OTP sent to the shop owner.',
        };
    }
    catch (err) {
        await client.query('ROLLBACK');
        throw err;
    }
    finally {
        client.release();
    }
}
//# sourceMappingURL=demandService.js.map