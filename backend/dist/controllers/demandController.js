import { asyncHandler } from '../middleware/asyncHandler.js';
import { parseId } from '../middleware/validation.js';
import { acceptDemand, confirmDelivery, declineDemand, cancelDemand } from '../services/demandService.js';
import { db } from '../db/pool.js';
async function getSupplierBusinessName(userId) {
    const { rows } = await db.query(`SELECT business_name FROM users WHERE id = $1`, [userId]);
    return rows[0]?.business_name ?? 'Your supplier';
}
export const acceptDemandHandler = asyncHandler(async (req, res) => {
    const demandId = parseId(String(req.params.id), 'demand id');
    const supplierId = req.userId;
    const businessName = await getSupplierBusinessName(supplierId);
    const result = await acceptDemand(demandId, supplierId, businessName);
    res.json({ success: true, data: result });
});
export const declineDemandHandler = asyncHandler(async (req, res) => {
    const demandId = parseId(String(req.params.id), 'demand id');
    const result = await declineDemand(demandId);
    res.json({ success: true, data: result });
});
export const confirmDeliveryHandler = asyncHandler(async (req, res) => {
    const orderId = parseId(String(req.params.id), 'order id');
    const supplierId = req.userId;
    const result = await confirmDelivery(orderId, supplierId);
    res.json({ success: true, data: result });
});
export const cancelDemandHandler = asyncHandler(async (req, res) => {
    const demandId = parseId(String(req.params.id), 'demand id');
    const shopOwnerId = req.userId;
    const result = await cancelDemand(demandId, shopOwnerId);
    res.json({ success: true, data: result });
});
//# sourceMappingURL=demandController.js.map