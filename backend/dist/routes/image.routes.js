import { Router } from 'express';
import { getStockImage } from '../services/stockService.js';
/**
 * Public product-image endpoint. Mounted WITHOUT auth (Flutter's
 * Image.network cannot send the X-User-Id header).
 * Serves bytes from Postgres so images survive Render restarts.
 */
const router = Router();
router.get('/:stockId', async (req, res) => {
    const stockId = String(req.params.stockId);
    if (!/^[0-9a-f-]{36}$/i.test(stockId)) {
        res.status(400).json({ success: false, error: 'Invalid stock id' });
        return;
    }
    try {
        const image = await getStockImage(stockId);
        if (!image) {
            res.status(404).json({ success: false, error: 'Image not found' });
            return;
        }
        res.setHeader('Content-Type', image.mimeType);
        res.setHeader('Cache-Control', 'public, max-age=60');
        res.send(image.data);
    }
    catch (err) {
        console.error('[stock-images] serve failed:', err);
        res.status(500).json({ success: false, error: 'Failed to load image' });
    }
});
export default router;
//# sourceMappingURL=image.routes.js.map