import { db } from '../db/pool.js';

export interface ShopOwnerOrderRow {
  order_id: string;
  supplier_name: string;
  product_name: string;
  quantity: number;
  unit: string;
  total_amount: number;
  status: string;
  delivery_otp: string | null;
  delivery_address: string | null;
  created_at: Date;
}

export interface ShopOwnerOrderDto {
  orderId: string;
  supplierName: string;
  productName: string;
  quantity: number;
  unit: string;
  totalAmount: number;
  status: string;
  deliveryOtp: string | null;
  deliveryAddress: string | null;
  orderTime: string;
}

function mapRow(row: ShopOwnerOrderRow): ShopOwnerOrderDto {
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
export async function getShopOwnerOrders(
  shopOwnerId: string,
): Promise<ShopOwnerOrderDto[]> {
  const { rows } = await db.query<ShopOwnerOrderRow>(
    `SELECT
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
     LIMIT 50`,
    [shopOwnerId],
  );

  return rows.map(mapRow);
}
