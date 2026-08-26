import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import { getProfile, updateProfile, type UpdateProfilePayload } from '../services/profileService.js';

export const getProfileHandler = asyncHandler(async (req: AuthRequest, res: Response) => {
  const userId = req.userId!;
  const profile = await getProfile(userId);
  if (!profile) {
    res.status(404).json({ success: false, error: 'User not found' });
    return;
  }
  res.json({ success: true, data: profile });
});

export const updateProfileHandler = asyncHandler(async (req: AuthRequest, res: Response) => {
  const userId = req.userId!;
  const body = req.body as Record<string, unknown>;

  const payload: UpdateProfilePayload = {};
  if (body.fullName !== undefined) payload.fullName = String(body.fullName);
  if (body.phoneNumber !== undefined) payload.phoneNumber = String(body.phoneNumber);
  if (body.businessName !== undefined) payload.businessName = String(body.businessName);
  if (body.category !== undefined) payload.category = String(body.category);
  if (body.tradeLicense !== undefined) payload.tradeLicense = String(body.tradeLicense);
  if (body.minOrderValue !== undefined) payload.minOrderValue = Number(body.minOrderValue);
  if (body.supplyRadius !== undefined) payload.supplyRadius = String(body.supplyRadius);
  if (body.address !== undefined) payload.address = String(body.address);
  if (body.latitude !== undefined) payload.latitude = Number(body.latitude);
  if (body.longitude !== undefined) payload.longitude = Number(body.longitude);

  const profile = await updateProfile(userId, payload);
  if (!profile) {
    res.status(404).json({ success: false, error: 'User not found' });
    return;
  }
  res.json({ success: true, data: profile });
});
