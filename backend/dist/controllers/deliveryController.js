import { sendSms } from '../services/smsService.js';
import { db } from '../db/pool.js';
import crypto from 'crypto';
function hashPassword(password) {
    return crypto.createHash('sha256').update(password).digest('hex');
}
/**
 * Public endpoint for Delivery Men to self-register
 */
export async function registerDeliveryManHandler(req, res) {
    try {
        const { fullName, phoneNumber, password } = req.body;
        if (!fullName || !phoneNumber || !password) {
            return res.status(400).json({ success: false, error: 'Full name, phone number, and password are required' });
        }
        const hashedPassword = hashPassword(password);
        const businessName = `${fullName} Delivery`;
        const category = 'Delivery';
        const result = await db.query(`INSERT INTO public.users (
         role, full_name, phone_number, business_name, category, password_hash
       )
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, full_name, phone_number, created_at`, ['delivery_man', fullName, phoneNumber, businessName, category, hashedPassword]);
        res.status(201).json({ success: true, data: result.rows[0] });
    }
    catch (error) {
        console.error('Error registering delivery man:', error);
        if (error.code === '23505') { // Unique violation
            return res.status(409).json({ success: false, error: 'Phone number is already registered' });
        }
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
}
/**
 * Supplier requests a rider for an order
 */
export async function requestRiderHandler(req, res) {
    try {
        const supplierId = req.userId;
        const { id: orderId } = req.params;
        const orderCheck = await db.query(`SELECT id, status FROM public.orders WHERE id = $1 AND supplier_id = $2`, [orderId, supplierId]);
        if (orderCheck.rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Order not found' });
        }
        await db.query(`UPDATE public.orders 
       SET status = 'searching_for_rider', updated_at = now()
       WHERE id = $1`, [orderId]);
        res.status(200).json({ success: true, message: 'Broadcasted delivery request to nearby riders' });
    }
    catch (error) {
        console.error('Error requesting rider:', error);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
}
/**
 * Supplier cancels a rider request — reverts searching_for_rider -> accepted
 */
export async function cancelRiderRequestHandler(req, res) {
    try {
        const supplierId = req.userId;
        const { id: orderId } = req.params;
        const orderCheck = await db.query(`SELECT id, status FROM public.orders WHERE id = $1 AND supplier_id = $2`, [orderId, supplierId]);
        if (orderCheck.rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Order not found' });
        }
        if (orderCheck.rows[0].status !== 'searching_for_rider') {
            return res.status(400).json({ success: false, error: 'Order is not in searching_for_rider status' });
        }
        await db.query(`UPDATE public.orders
       SET status = 'accepted', delivery_man_id = NULL, updated_at = now()
       WHERE id = $1`, [orderId]);
        res.status(200).json({ success: true, message: 'Rider request cancelled' });
    }
    catch (error) {
        console.error('Error cancelling rider request:', error);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
}
/**
 * Delivery Man lists available broadcasted requests (searching_for_rider)
 * Filtered by 10 km Haversine radius from the rider's saved location.
 */
export async function getNearbyRequestsHandler(req, res) {
    try {
        const riderId = req.userId;
        // Fetch rider's saved base location
        const riderRes = await db.query(`SELECT latitude, longitude FROM public.users WHERE id = $1`, [riderId]);
        const rider = riderRes.rows[0];
        const rLat = rider?.latitude;
        const rLng = rider?.longitude;
        let result;
        if (rLat != null && rLng != null) {
            result = await db.query(`SELECT o.id, o.quantity, o.unit, o.total_amount, o.status, o.created_at,
                o.delivery_address, o.delivery_lat, o.delivery_lng, o.product_name,
                u.full_name AS shop_owner_name, u.phone_number AS shop_owner_phone,
                s.full_name AS supplier_name, s.phone_number AS supplier_phone,
                s.latitude AS supplier_lat, s.longitude AS supplier_lng,
                ROUND(CAST(
                  6371 * ACOS(GREATEST(-1, LEAST(1,
                    COS(RADIANS($1)) * COS(RADIANS(s.latitude))
                    * COS(RADIANS(s.longitude) - RADIANS($2))
                    + SIN(RADIANS($1)) * SIN(RADIANS(s.latitude))
                  ))
                ) AS numeric), 2) AS distance_km
         FROM public.orders o
         JOIN public.users u ON o.shop_owner_id = u.id
         JOIN public.users s ON o.supplier_id = s.id
         WHERE o.status = 'searching_for_rider'
           AND s.latitude IS NOT NULL AND s.longitude IS NOT NULL
           AND (
             6371 * ACOS(GREATEST(-1, LEAST(1,
               COS(RADIANS($1)) * COS(RADIANS(s.latitude))
               * COS(RADIANS(s.longitude) - RADIANS($2))
               + SIN(RADIANS($1)) * SIN(RADIANS(s.latitude))
             )))
           ) <= 10
         ORDER BY distance_km ASC, o.created_at DESC`, [rLat, rLng]);
        }
        else {
            // Rider has no saved location — return all (fallback)
            result = await db.query(`SELECT o.id, o.quantity, o.unit, o.total_amount, o.status, o.created_at,
                o.delivery_address, o.delivery_lat, o.delivery_lng, o.product_name,
                u.full_name AS shop_owner_name, u.phone_number AS shop_owner_phone,
                s.full_name AS supplier_name, s.phone_number AS supplier_phone,
                s.latitude AS supplier_lat, s.longitude AS supplier_lng,
                NULL AS distance_km
         FROM public.orders o
         JOIN public.users u ON o.shop_owner_id = u.id
         JOIN public.users s ON o.supplier_id = s.id
         WHERE o.status = 'searching_for_rider'
         ORDER BY o.created_at DESC`);
        }
        res.status(200).json({ success: true, data: result.rows });
    }
    catch (error) {
        console.error('Error fetching nearby requests:', error);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
}
/**
 * Delivery Man accepts a broadcasted delivery request
 */
export async function acceptRequestHandler(req, res) {
    try {
        const deliveryManId = req.userId;
        const { id: orderId } = req.params;
        const orderCheck = await db.query(`SELECT id, status, supplier_id, shop_owner_id FROM public.orders WHERE id = $1`, [orderId]);
        if (orderCheck.rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Order not found' });
        }
        if (orderCheck.rows[0].status !== 'searching_for_rider') {
            return res.status(400).json({ success: false, error: 'Order is no longer available' });
        }
        // Try to claim it
        await db.query(`UPDATE public.orders 
       SET delivery_man_id = $1, status = 'accepted', updated_at = now()
       WHERE id = $2 AND status = 'searching_for_rider'`, [deliveryManId, orderId]);
        // Notify supplier
        await db.query(`INSERT INTO public.notifications (user_id, title, subtitle, type)
       VALUES ($1, 'Rider Assigned', 'A delivery man has accepted your request and is coming to pick up the order.', 'order_update')`, [orderCheck.rows[0].supplier_id]);
        res.status(200).json({ success: true, message: 'Successfully assigned to you', data: {} });
    }
    catch (error) {
        console.error('Error accepting request:', error);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
}
/**
 * Delivery Man views their accepted/active orders
 */
export async function getDeliveryManOrdersHandler(req, res) {
    try {
        const deliveryManId = req.userId;
        const result = await db.query(`SELECT o.id, o.quantity, o.unit, o.total_amount, o.status, o.created_at,
              o.product_name, o.delivery_address, o.delivery_lat, o.delivery_lng,
              u.full_name AS shop_owner_name, u.phone_number AS shop_owner_phone,
              s.full_name AS supplier_name, s.phone_number AS supplier_phone,
              s.latitude AS supplier_lat, s.longitude AS supplier_lng
       FROM public.orders o
       JOIN public.users u ON o.shop_owner_id = u.id
       JOIN public.users s ON o.supplier_id = s.id
       WHERE o.delivery_man_id = $1
       ORDER BY o.created_at DESC`, [deliveryManId]);
        res.status(200).json({ success: true, data: result.rows });
    }
    catch (error) {
        console.error('Error fetching delivery man orders:', error);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
}
/**
 * Delivery Man marks an order as picked up (accepted → out_for_delivery).
 * Generates an OTP and notifies the shop owner.
 */
export async function pickupOrderHandler(req, res) {
    try {
        const deliveryManId = req.userId;
        const { id: orderId } = req.params;
        const orderCheck = await db.query(`SELECT id, status, supplier_id, shop_owner_id, product_name
       FROM public.orders WHERE id = $1 AND delivery_man_id = $2`, [orderId, deliveryManId]);
        if (orderCheck.rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Order not found or not assigned to you' });
        }
        const order = orderCheck.rows[0];
        if (order.status !== 'accepted') {
            return res.status(400).json({ success: false, error: `Order is already ${order.status}` });
        }
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        await db.query(`UPDATE public.orders
       SET status = 'out_for_delivery', delivery_otp = $1, updated_at = now()
       WHERE id = $2`, [otp, orderId]);
        await db.query(`INSERT INTO otps (order_id, otp_code)
       VALUES ($1, $2)
       ON CONFLICT (order_id)
       DO UPDATE SET otp_code = EXCLUDED.otp_code,
                     is_verified = false,
                     expires_at = now() + interval '24 hours'`, [orderId, otp]);
        // Notify supplier
        await db.query(`INSERT INTO public.notifications (user_id, title, subtitle, type)
       VALUES ($1, 'Order Picked Up', 'The delivery man has picked up the order and is on the way.', 'order_update')`, [order.supplier_id]);
        // Notify shop owner with OTP
        const userRes = await db.query(`SELECT phone_number FROM public.users WHERE id = $1`, [order.shop_owner_id]);
        const phone = userRes.rows[0]?.phone_number;
        if (phone) {
            const { sendSms } = await import('../services/smsService.js');
            sendSms(phone, `TradeLink: Your delivery OTP is ${otp} for ${order.product_name}. Share this 6-digit code with the delivery person.`);
        }
        await db.query(`INSERT INTO public.notifications (user_id, title, subtitle, type)
       VALUES ($1, 'Out for Delivery', $2, 'delivery_otp')`, [order.shop_owner_id, `Your delivery OTP is ${otp}. Share this code with the delivery person upon arrival.`]);
        res.status(200).json({ success: true, message: 'Order picked up. OTP sent to shop owner.', data: { otp } });
    }
    catch (error) {
        console.error('Error picking up order:', error);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
}
/**
 * Delivery Man marks an order as delivered
 */
export async function markOrderDeliveredHandler(req, res) {
    try {
        const deliveryManId = req.userId;
        const { id: orderId } = req.params;
        const { otp, isQrScan } = req.body;
        const orderCheck = await db.query(`SELECT id, shop_owner_id, supplier_id, delivery_otp FROM public.orders WHERE id = $1 AND delivery_man_id = $2`, [orderId, deliveryManId]);
        if (orderCheck.rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Order not found or not assigned to you' });
        }
        const order = orderCheck.rows[0];
        // Verify OTP if not a QR scan
        if (!isQrScan) {
            if (!otp) {
                return res.status(400).json({ success: false, error: 'OTP is required' });
            }
            if (!order.delivery_otp) {
                return res.status(400).json({ success: false, error: 'No OTP generated for this order' });
            }
            if (order.delivery_otp !== otp.toString()) {
                return res.status(400).json({ success: false, error: 'Invalid OTP' });
            }
        }
        await db.query(`UPDATE public.orders SET status = 'delivered', updated_at = now() WHERE id = $1`, [orderId]);
        // Look up inventory_id for review metadata
        const invResult = await db.query(`SELECT id FROM public.stockholder_inventory
       WHERE stockholder_id = $1 AND LOWER(custom_product_name) = (
         SELECT LOWER(product_name) FROM public.orders WHERE id = $2
       ) LIMIT 1`, [order.supplier_id, orderId]);
        const inventoryId = invResult.rows.length > 0 ? invResult.rows[0].id : '';
        // Get product name for notification
        const orderDetails = await db.query(`SELECT product_name FROM public.orders WHERE id = $1`, [orderId]);
        const productName = orderDetails.rows[0]?.product_name ?? 'your item';
        await db.query(`INSERT INTO public.notifications (user_id, title, subtitle, type)
       VALUES ($1, 'Order Delivered', 'Your delivery man has successfully delivered the order.', 'order_update')`, [order.supplier_id]);
        // Notification for shop owner with review metadata
        await db.query(`INSERT INTO public.notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'delivery_confirmed')`, [
            order.shop_owner_id,
            'Order Delivered!',
            `Your order for ${productName} is complete. Tap to leave an optional review.\n|||${orderId}|||${order.supplier_id}|||${inventoryId}`,
        ]);
        res.status(200).json({ success: true, message: 'Order marked as delivered' });
    }
    catch (error) {
        console.error('Error marking order delivered:', error);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
}
/**
 * Shop Owner confirms delivery (e.g. by scanning the Delivery Man's QR code)
 */
export async function shopOwnerConfirmDeliveryHandler(req, res) {
    try {
        const shopOwnerId = req.userId;
        const { id: orderId } = req.params;
        const orderCheck = await db.query(`SELECT id, supplier_id, delivery_man_id, status, product_name FROM public.orders WHERE id = $1 AND shop_owner_id = $2`, [orderId, shopOwnerId]);
        if (orderCheck.rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Order not found or you are not the owner' });
        }
        const order = orderCheck.rows[0];
        if (order.status === 'delivered') {
            return res.status(400).json({ success: false, error: 'Order is already delivered' });
        }
        await db.query(`UPDATE public.orders SET status = 'delivered', updated_at = now() WHERE id = $1`, [orderId]);
        // Look up inventory_id for review metadata
        const invResult = await db.query(`SELECT id FROM public.stockholder_inventory
       WHERE stockholder_id = $1 AND LOWER(custom_product_name) = LOWER($2)
       LIMIT 1`, [order.supplier_id, order.product_name]);
        const inventoryId = invResult.rows.length > 0 ? invResult.rows[0].id : '';
        // Notify Supplier
        await db.query(`INSERT INTO public.notifications (user_id, title, subtitle, type)
       VALUES ($1, 'Order Delivered', 'Your delivery man has successfully delivered the order (confirmed by shop owner).', 'order_update')`, [order.supplier_id]);
        // Notify Delivery Man
        if (order.delivery_man_id) {
            await db.query(`INSERT INTO public.notifications (user_id, title, subtitle, type)
         VALUES ($1, 'Delivery Confirmed', 'The shop owner has confirmed the delivery.', 'order_update')`, [order.delivery_man_id]);
        }
        // Notification for shop owner with review metadata
        await db.query(`INSERT INTO public.notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'delivery_confirmed')`, [
            shopOwnerId,
            'Order Delivered!',
            `Your order for ${order.product_name} is complete. Tap to leave an optional review.\n|||${orderId}|||${order.supplier_id}|||${inventoryId}`,
        ]);
        res.status(200).json({ success: true, message: 'Delivery confirmed successfully' });
    }
    catch (error) {
        console.error('Error confirming delivery by shop owner:', error);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
}
/**
 * Delivery Man sends OTP to the customer upon arrival
 */
export async function sendDeliveryOtpHandler(req, res) {
    try {
        const deliveryManId = req.userId;
        const { id: orderId } = req.params;
        const orderCheck = await db.query(`SELECT o.id, o.shop_owner_id, u.phone_number 
       FROM public.orders o
       JOIN public.users u ON o.shop_owner_id = u.id
       WHERE o.id = $1 AND o.delivery_man_id = $2`, [orderId, deliveryManId]);
        if (orderCheck.rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Order not found or not assigned to you' });
        }
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        await db.query(`UPDATE public.orders SET delivery_otp = $1 WHERE id = $2`, [otp, orderId]);
        await db.query(`INSERT INTO otps (order_id, otp_code)
       VALUES ($1, $2)
       ON CONFLICT (order_id)
       DO UPDATE SET otp_code = EXCLUDED.otp_code,
                     is_verified = false,
                     expires_at = now() + interval '24 hours'`, [orderId, otp]);
        const phone = orderCheck.rows[0].phone_number;
        if (phone) {
            sendSms(phone, `TradeLink: Your delivery OTP is ${otp}. Share this 6-digit code with the delivery person.`);
        }
        res.status(200).json({ success: true, message: 'OTP sent to customer', data: {} });
    }
    catch (error) {
        console.error('Error sending delivery OTP:', error);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
}
/**
 * Delivery Man notifies customer they are arriving soon
 */
export async function notifyArrivalHandler(req, res) {
    try {
        const deliveryManId = req.userId;
        const { id: orderId } = req.params;
        const orderCheck = await db.query(`SELECT id, shop_owner_id FROM public.orders WHERE id = $1 AND delivery_man_id = $2`, [orderId, deliveryManId]);
        if (orderCheck.rows.length === 0) {
            return res.status(404).json({ success: false, error: 'Order not found' });
        }
        await db.query(`INSERT INTO public.notifications (user_id, title, subtitle, type)
       VALUES ($1, 'Delivery Arriving', 'The delivery man is almost here!', 'order_update')`, [orderCheck.rows[0].shop_owner_id]);
        res.status(200).json({ success: true, message: 'Notified customer', data: {} });
    }
    catch (error) {
        console.error('Error notifying arrival:', error);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
}
//# sourceMappingURL=deliveryController.js.map