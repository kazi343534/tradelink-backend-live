import { db } from '../db/pool.js';
function mapRow(row) {
    return {
        orderId: row.order_id,
        supplierName: row.supplier_name,
        productName: row.product_name,
        quantity: Number(row.quantity),
        unit: row.unit,
        totalAmount: Number(row.total_amount),
        status: row.status,
        deliveryOtp: row.delivery_otp,
        deliveryAddress: row.delivery_address,
        orderTime: row.created_at.toISOString(),
    };
}
/**
 * Fetch all orders for a shop owner with supplier info.
 */
export async function getShopOwnerOrders(shopOwnerId) {
    const { rows } = await db.query(`SELECT
       o.id AS order_id,
       COALESCE(u.full_name, 'Unknown Supplier') AS supplier_name,
       o.product_name,
       o.quantity,
       o.unit,
       o.total_amount,
       o.status,
       o.delivery_otp,
       o.delivery_address,
       o.created_at
     FROM public.orders o
     JOIN public.users u ON o.supplier_id = u.id
     WHERE o.shop_owner_id = $1
     ORDER BY o.created_at DESC
     LIMIT 50`, [shopOwnerId]);
    return rows.map(mapRow);
}
//# sourceMappingURL=shopOwnerOrderService.js.map