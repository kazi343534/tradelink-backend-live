import { z } from 'zod';

const CATEGORIES = ['Grocery', 'Pharmacy', 'Stationery', 'Hardware'] as const;
const UNITS = ['kg', 'litre', 'pcs'] as const;

export const createStockSchema = z.object({
  masterProductId: z.string().uuid().optional(),
  customProductName: z.string().trim().min(1).max(255),
  category: z.enum(CATEGORIES),
  quantity: z.number().positive().max(1_000_000),
  unit: z.enum(UNITS),
  pricePerUnit: z.number().nonnegative().max(1_000_000),
  imageUrl: z.string().url().optional(),
  deliveryRadiusKm: z.number().int().min(1).max(100).optional().default(10),
});

export type CreateStockInput = z.infer<typeof createStockSchema>;

export function parseId(id: string | undefined, name = 'id'): string {
  const uuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!id || !uuid.test(id)) {
    const error = new Error(`Invalid ${name}`) as Error & { status?: number };
    error.status = 400;
    throw error;
  }
  return id;
}