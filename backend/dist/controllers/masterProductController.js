import { asyncHandler } from '../middleware/asyncHandler.js';
import { listMasterProducts, searchInventory, getCheapestSuppliers, } from '../services/masterProductService.js';
export const listMasterProductsHandler = asyncHandler(async (req, res) => {
    const category = req.query.category;
    const products = await listMasterProducts(category);
    res.json({ success: true, data: products });
});
export const searchInventoryHandler = asyncHandler(async (req, res) => {
    const query = req.query.q;
    const category = req.query.category;
    if (!query) {
        res.status(400).json({ success: false, error: 'Query parameter "q" is required' });
        return;
    }
    const results = await searchInventory(query, category);
    res.json({ success: true, data: results });
});
export const getCheapestSuppliersHandler = asyncHandler(async (req, res) => {
    const product = req.query.product;
    if (!product) {
        res.status(400).json({ success: false, error: 'Query parameter "product" is required' });
        return;
    }
    const results = await getCheapestSuppliers(product);
    res.json({ success: true, data: results });
});
//# sourceMappingURL=masterProductController.js.map