import { asyncHandler } from '../middleware/asyncHandler.js';
import { searchMarketplace, getProductDetail, getProductsByCategory, } from '../services/marketplaceService.js';
/**
 * Search products in the marketplace with spatial filtering.
 * Query params: query, category, maxDistance, sortBy, limit, offset
 * Body: { shopLat, shopLng } - optional, falls back to Dhaka defaults
 */
export const searchMarketplaceHandler = asyncHandler(async (req, res) => {
    const { query = '', category, maxDistance = '50', sortBy = 'distance', limit = '20', offset = '0', } = req.query;
    const { shopLat, shopLng } = req.body;
    const products = await searchMarketplace({
        query: String(query),
        shopLat: shopLat ?? null,
        shopLng: shopLng ?? null,
        category: category ? String(category) : undefined,
        maxDistance: Number(maxDistance),
        sortBy: String(sortBy),
        limit: Number(limit),
        offset: Number(offset),
    });
    res.json({
        success: true,
        data: {
            products,
            total: products.length,
            hasMore: products.length === Number(limit),
        },
    });
});
/**
 * Get a single product detail with supplier info.
 * Body: { shopLat, shopLng } - optional, falls back to Dhaka defaults
 */
export const getProductDetailHandler = asyncHandler(async (req, res) => {
    const stockId = String(req.params.id);
    const { shopLat, shopLng } = req.body;
    if (!stockId) {
        res.status(400).json({
            success: false,
            error: 'Product ID is required',
        });
        return;
    }
    const product = await getProductDetail(stockId, shopLat ?? null, shopLng ?? null);
    if (!product) {
        res.status(404).json({
            success: false,
            error: 'Product not found or unavailable',
        });
        return;
    }
    res.json({ success: true, data: product });
});
/**
 * Get products by category with spatial filtering.
 * Body: { shopLat, shopLng } - optional, falls back to Dhaka defaults
 */
export const getProductsByCategoryHandler = asyncHandler(async (req, res) => {
    const category = String(req.params.category);
    const { limit = '20', offset = '0' } = req.query;
    const { shopLat, shopLng } = req.body;
    if (!category) {
        res.status(400).json({
            success: false,
            error: 'Category is required',
        });
        return;
    }
    const products = await getProductsByCategory(category, shopLat ?? null, shopLng ?? null, Number(limit), Number(offset));
    res.json({
        success: true,
        data: {
            products,
            total: products.length,
            hasMore: products.length === Number(limit),
        },
    });
});
//# sourceMappingURL=marketplaceController.js.map