import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import {
  listMasterProducts,
  searchInventory,
  getCheapestSuppliers,
} from '../services/masterProductService.js';

export const listMasterProductsHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const category = req.query.category as string | undefined;
    const products = await listMasterProducts(category);
    res.json({ success: true, data: products });
  },
);

export const searchInventoryHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const query = req.query.q as string;
    const category = req.query.category as string | undefined;
    if (!query) {
      res.status(400).json({ success: false, error: 'Query parameter "q" is required' });
      return;
    }
    const results = await searchInventory(query, category);
    res.json({ success: true, data: results });
  },
);

export const getCheapestSuppliersHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const product = req.query.product as string;
    if (!product) {
      res.status(400).json({ success: false, error: 'Query parameter "product" is required' });
      return;
    }
    const results = await getCheapestSuppliers(product);
    res.json({ success: true, data: results });
  },
);