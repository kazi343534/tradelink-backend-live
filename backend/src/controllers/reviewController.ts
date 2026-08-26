import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import {
  submitReview,
  getSupplierRating,
  getInventoryRating,
  listInventoryReviews,
  resolveOrderForReview,
} from '../services/reviewService.js';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const submitReviewHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const shopOwnerId = req.userId!;
    const { orderId, supplierId, inventoryId, rating, comment } = req.body;

    if (!rating) {
      res.status(400).json({ success: false, error: 'Rating is required' });
      return;
    }

    const numRating = Number(rating);
    if (isNaN(numRating) || numRating < 1 || numRating > 5) {
      res.status(400).json({ success: false, error: 'Rating must be between 1 and 5' });
      return;
    }

    const validOrderId = orderId && UUID_RE.test(String(orderId)) ? String(orderId) : null;
    const validSupplierId = supplierId && UUID_RE.test(String(supplierId)) ? String(supplierId) : null;
    const validInventoryId = inventoryId && UUID_RE.test(String(inventoryId)) ? String(inventoryId) : null;

    // supplierId may be omitted when orderId is provided — the service
    // resolves supplier + inventory from the order as a fallback.
    if (!validSupplierId && !validOrderId) {
      res.status(400).json({
        success: false,
        error: 'A valid supplier ID or order ID is required to submit a review',
      });
      return;
    }

    try {
      const review = await submitReview(shopOwnerId, {
        orderId: validOrderId,
        supplierId: validSupplierId,
        inventoryId: validInventoryId,
        rating: numRating,
        comment: comment || null,
      });

      res.json({ success: true, data: review });
    } catch (err: any) {
      const status = err.status || 500;
      res.status(status).json({
        success: false,
        error: err.message || 'Failed to submit review',
      });
    }
  },
);

export const getSupplierRatingHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const supplierId = String(req.params.supplierId);
    if (!supplierId || !UUID_RE.test(supplierId)) {
      res.status(400).json({ success: false, error: 'Valid supplierId is required' });
      return;
    }
    const rating = await getSupplierRating(supplierId);
    res.json({ success: true, data: rating });
  },
);

export const getInventoryRatingHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const inventoryId = String(req.params.inventoryId);
    if (!inventoryId || !UUID_RE.test(inventoryId)) {
      res.status(400).json({ success: false, error: 'Valid inventoryId is required' });
      return;
    }
    const rating = await getInventoryRating(inventoryId);
    res.json({ success: true, data: rating });
  },
);

export const listInventoryReviewsHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const inventoryId = String(req.params.inventoryId);
    if (!inventoryId || !UUID_RE.test(inventoryId)) {
      res.status(400).json({ success: false, error: 'Valid inventoryId is required' });
      return;
    }
    const reviews = await listInventoryReviews(inventoryId);
    res.json({ success: true, data: reviews });
  },
);

export const resolveOrderHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const shopOwnerId = req.userId!;
    const productName = String(req.query.productName || '');
    if (!productName.trim()) {
      res.status(400).json({ success: false, error: 'productName is required' });
      return;
    }
    const result = await resolveOrderForReview(shopOwnerId, productName.trim());
    if (!result) {
      res.json({ success: true, data: null });
      return;
    }
    res.json({ success: true, data: result });
  },
);
