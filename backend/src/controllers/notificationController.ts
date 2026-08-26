import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import {
  listNotifications,
  countUnread,
  markOneRead,
  markAllRead,
} from '../services/notificationService.js';

export const getNotificationsHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const userId = req.userId!;
    const notifications = await listNotifications(userId);
    res.json({ success: true, data: notifications });
  },
);

export const getUnreadCountHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const userId = req.userId!;
    const count = await countUnread(userId);
    res.json({ success: true, data: { count } });
  },
);

export const markOneReadHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const userId = req.userId!;
    const id = String(req.params.id);
    const updated = await markOneRead(id, userId);
    res.json({ success: true, data: { updated } });
  },
);

export const markReadHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const userId = req.userId!;
    const result = await markAllRead(userId);
    res.json({ success: true, data: result });
  },
);