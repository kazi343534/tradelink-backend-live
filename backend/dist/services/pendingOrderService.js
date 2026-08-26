import { db } from '../db/pool.js';
function mapPendingOrderRow(row) {
    return {
        orderId: row.order_id,
        deliveryOtp: row.delivery_otp,
        orderStatus: row.order_status,
        orderTime: row.order_time.toISOString(),
        productName: row.product_name,
        quantity: Number(row.quantity),
        unit: row.unit,
        totalAmount: Number(row.total_amount),
        deliveryLocation: row.delivery_location,
        shopOwnerName: row.shop_owner_name,
        shopOwnerPhone: row.shop_owner_phone,
        deliveryManId: row.delivery_man_id ?? null,
    };
}
/**
 * Fetch orders for the logged-in supplier.
 * Handles both direct orders (no demand_id) and demand-based orders.
 * Returns orders in: pending, accepted, out_for_delivery, in_transit statuses.
 */
export async function getPendingOrders(stockholderId) {
    const { rows } = await db.query(`SELECT
       o.id                                       AS order_id,
       o.delivery_otp                             AS delivery_otp,
       o.status                                   AS order_status,
       o.created_at                               AS order_time,
       o.product_name,
       o.quantity,
       o.unit,
       o.total_amount,
       COALESCE(o.delivery_address, '')           AS delivery_location,
       COALESCE(u.full_name, 'Unknown')           AS shop_owner_name,
       COALESCE(u.phone_number, '')               AS shop_owner_phone,
       o.delivery_man_id                          AS delivery_man_id
     FROM public.orders o
     JOIN public.users u ON o.shop_owner_id = u.id
     WHERE o.supplier_id = $1
       AND o.status IN ('pending', 'accepted', 'searching_for_rider', 'out_for_delivery', 'in_transit')
     ORDER BY
       CASE o.status
         WHEN 'pending' THEN 0
         WHEN 'accepted' THEN 1
         WHEN 'searching_for_rider' THEN 2
         WHEN 'out_for_delivery' THEN 3
         WHEN 'in_transit' THEN 4
       END,
       o.created_at DESC`, [stockholderId]);
    return rows.map(mapPendingOrderRow);
}
function mapCompletedOrderRow(row) {
    return {
        orderId: row.order_id,
        productName: row.product_name,
        quantity: Number(row.quantity),
        unit: row.unit,
        totalAmount: Number(row.total_amount),
        deliveredAt: row.delivered_at?.toISOString?.() ?? String(row.delivered_at),
        shopOwnerName: row.shop_owner_name,
        shopOwnerPhone: row.shop_owner_phone,
        givenRating: row.given_rating != null ? Number(row.given_rating) : null,
        givenComment: row.given_comment ?? null,
    };
}
/**
 * Fetch all finalized (delivered) orders for the logged-in supplier,
 * including any rating/review left by the shop owner.
 */
export async function getCompletedOrders(stockholderId) {
    const { rows } = await db.query(`SELECT
       o.id                             AS order_id,
       o.product_name,
       o.quantity,
       o.unit,
       o.total_amount,
       COALESCE(o.updated_at, o.created_at) AS delivered_at,
       COALESCE(u.full_name, 'Unknown') AS shop_owner_name,
       COALESCE(u.phone_number, '')     AS shop_owner_phone,
       r.rating                         AS given_rating,
       r.review                         AS given_comment
     FROM public.orders o
     JOIN public.users u ON o.shop_owner_id = u.id
     LEFT JOIN public.ratings r ON r.order_id = o.id
     WHERE o.supplier_id = $1
       AND o.status = 'delivered'
     ORDER BY COALESCE(o.updated_at, o.created_at) DESC`, [stockholderId]);
    return rows.map(mapCompletedOrderRow);
}
//# sourceMappingURL=pendingOrderService.js.map