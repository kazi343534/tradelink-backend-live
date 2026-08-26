import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import { createStockSchema } from '../middleware/validation.js';
import { createStock, listStock, updateStock, deleteStock, saveStockImage } from '../services/stockService.js';

/** Persist uploaded bytes in Postgres and return a stable public URL. */
async function storeImageAndBuildUrl(
  req: AuthRequest,
  stockId: string,
  file: Express.Multer.File,
): Promise<string> {
  await saveStockImage(stockId, file.mimetype, file.buffer);
  const host = req.get('host') || 'tradelink-2.onrender.com';
  const baseUrl = `https://${host}`;
  return `${baseUrl}/stock-images/${stockId}?v=${Date.now()}`;
}

export const publishStock = asyncHandler(async (req: AuthRequest, res: Response) => {
  const stockholderId = req.userId!;

  // Handle multipart form data with optional image
  const body = req.body as Record<string, unknown>;
  const file = req.file;

  // Build payload from form fields
  const payload: {
    masterProductId?: string;
    customProductName: string;
    category: string;
    quantity: number;
    unit: string;
    pricePerUnit: number;
    imageUrl?: string;
    deliveryRadiusKm?: number;
  } = {
    customProductName: String(body.customProductName || ''),
    category: String(body.category || ''),
    quantity: Number(body.quantity || 0),
    unit: String(body.unit || 'kg'),
    pricePerUnit: Number(body.pricePerUnit || 0),
  };

  if (body.masterProductId) {
    payload.masterProductId = String(body.masterProductId);
  }

  if (body.deliveryRadiusKm) {
    payload.deliveryRadiusKm = Number(body.deliveryRadiusKm);
  }

  // If image was uploaded, we'll store bytes and set URL after stock creation
  // (need the stock id). Don't set a temporary URL here.
  if (!file && body.imageUrl) {
    payload.imageUrl = String(body.imageUrl);
  }

  // Validate with zod
  const validatedPayload = createStockSchema.parse(payload);

  const stock = await createStock(stockholderId, validatedPayload);

  // Store the image bytes in Postgres after we have the stock id
  if (file) {
    const imageUrl = await storeImageAndBuildUrl(req, stock.id, file);
    await updateStock(stockholderId, stock.id, { imageUrl });
    stock.imageUrl = imageUrl;
  }

  res.status(201).json({ success: true, data: stock });
});

export const listStockHandler = asyncHandler(async (req: AuthRequest, res: Response) => {
  const stockholderId = req.userId!;
  const stock = await listStock(stockholderId);
  res.json({ success: true, data: stock });
});

export const updateStockHandler = asyncHandler(async (req: AuthRequest, res: Response) => {
  const stockholderId = req.userId!;
  const stockId = String(req.params.id);
  const body = req.body as Record<string, unknown>;
  const file = req.file;

  const payload: {
    customProductName?: string;
    category?: string;
    pricePerUnit?: number;
    quantity?: number;
    unit?: string;
    imageUrl?: string;
    deliveryRadiusKm?: number;
  } = {};

  if (body.customProductName !== undefined) payload.customProductName = String(body.customProductName);
  if (body.category !== undefined) payload.category = String(body.category);
  if (body.pricePerUnit !== undefined) payload.pricePerUnit = Number(body.pricePerUnit);
  if (body.quantity !== undefined) payload.quantity = Number(body.quantity);
  if (body.unit !== undefined) payload.unit = String(body.unit);
  if (body.deliveryRadiusKm !== undefined) payload.deliveryRadiusKm = Number(body.deliveryRadiusKm);

  // Handle image upload — bytes go to Postgres, not the ephemeral disk
  if (file) {
    payload.imageUrl = await storeImageAndBuildUrl(req, stockId, file);
  } else if (body.imageUrl !== undefined) {
    payload.imageUrl = String(body.imageUrl);
  }

  const stock = await updateStock(stockholderId, stockId, payload);
  if (!stock) {
    res.status(404).json({ success: false, error: 'Stock item not found' });
    return;
  }
  res.json({ success: true, data: stock });
});

export const deleteStockHandler = asyncHandler(async (req: AuthRequest, res: Response) => {
  const stockholderId = req.userId!;
  const stockId = String(req.params.id);

  const deleted = await deleteStock(stockholderId, stockId);
  if (!deleted) {
    res.status(404).json({ success: false, error: 'Stock item not found' });
    return;
  }
  res.json({ success: true, data: { message: 'Stock item deleted successfully' } });
});
