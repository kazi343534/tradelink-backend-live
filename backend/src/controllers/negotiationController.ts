import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import {
  initiateNegotiation,
  listShopOwnerNegotiations,
  listSupplierNegotiations,
  counterNegotiation,
  respondToNegotiation,
  sendNegotiationMessage,
  getNegotiationThread,
  finalizeNegotiation,
} from '../services/negotiationService.js';

/**
 * POST /negotiations/initiate
 * Shop owner sends a bargain offer from a marketplace product card.
 * Body: { stockId, quantity, proposedPrice, message? }
 */
export const initiateNegotiationHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const shopOwnerId = req.userId!;
    const { stockId, quantity, proposedPrice, message } = req.body as {
      stockId?: string;
      quantity?: number;
      proposedPrice?: number;
      message?: string;
    };

    if (!stockId || !quantity || !proposedPrice) {
      res.status(400).json({
        success: false,
        error: 'stockId, quantity and proposedPrice are required',
      });
      return;
    }

    const negotiation = await initiateNegotiation({
      shopOwnerId,
      stockId: String(stockId),
      quantity: Number(quantity),
      proposedPrice: Number(proposedPrice),
      message: message?.trim() || null,
    });

    res.status(201).json({ success: true, data: negotiation });
  },
);

/**
 * GET /negotiations/shop-owner
 * All bargains for the authenticated shop owner.
 */
export const getShopOwnerNegotiationsHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const shopOwnerId = req.userId!;
    const negotiations = await listShopOwnerNegotiations(shopOwnerId);
    res.json({ success: true, data: negotiations });
  },
);

/**
 * GET /negotiations/supplier
 * All bargains addressed to the authenticated supplier.
 */
export const getSupplierNegotiationsHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const stockholderId = req.userId!;
    const negotiations = await listSupplierNegotiations(stockholderId);
    res.json({ success: true, data: negotiations });
  },
);

/**
 * POST /negotiations/counter
 * Supplier counters an offer. Body: { negotiationId, proposedPrice, counterMessage? }
 */
export const counterNegotiationHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const stockholderId = req.userId!;
    const { negotiationId, proposedPrice, counterMessage } = req.body as {
      negotiationId?: string;
      proposedPrice?: number;
      counterMessage?: string;
    };

    if (!negotiationId || !proposedPrice) {
      res.status(400).json({
        success: false,
        error: 'negotiationId and proposedPrice are required',
      });
      return;
    }

    const negotiation = await counterNegotiation({
      negotiationId: String(negotiationId),
      stockholderId,
      proposedPrice: Number(proposedPrice),
      counterMessage: counterMessage?.trim() || null,
    });

    res.json({ success: true, data: negotiation });
  },
);

/**
 * POST /negotiations/respond
 * Shop owner accepts a supplier counter-offer (creates a confirmed order)
 * or declines the bargain. Body: { negotiationId, action: 'accept' | 'decline' }
 */
export const respondToNegotiationHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const shopOwnerId = req.userId!;
    const { negotiationId, action } = req.body as {
      negotiationId?: string;
      action?: 'accept' | 'decline';
    };

    if (!negotiationId || !action || !['accept', 'decline'].includes(action)) {
      res.status(400).json({
        success: false,
        error: "negotiationId and action ('accept'|'decline') are required",
      });
      return;
    }

    const result = await respondToNegotiation({
      negotiationId: String(negotiationId),
      shopOwnerId,
      action,
    });

    res.json({ success: true, data: result });
  },
);

/**
 * POST /negotiations/message
 * Either party sends a chat message and/or a price counter-offer.
 * Body: { negotiationId, message?, offeredPrice? }
 */
export const sendNegotiationMessageHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const senderId = req.userId!;
    const role = (req.role ?? '').toLowerCase();
    if (role !== 'shop_owner' && role !== 'supplier') {
      res.status(403).json({ success: false, error: 'Unknown sender role' });
      return;
    }
    const { negotiationId, message, offeredPrice } = req.body as {
      negotiationId?: string;
      message?: string;
      offeredPrice?: number;
    };

    if (!negotiationId) {
      res.status(400).json({ success: false, error: 'negotiationId is required' });
      return;
    }

    const negotiation = await sendNegotiationMessage({
      negotiationId: String(negotiationId),
      senderId,
      senderType: role === 'shop_owner' ? 'SHOP_OWNER' : 'SUPPLIER',
      message: message ?? null,
      offeredPrice:
        offeredPrice != null && Number(offeredPrice) > 0
          ? Number(offeredPrice)
          : null,
    });

    res.json({ success: true, data: negotiation });
  },
);

/**
 * GET /negotiations/:id/messages
 * Full chat thread + live deal state. Participant-only.
 */
export const getNegotiationMessagesHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const requesterId = req.userId!;
    const thread = await getNegotiationThread(String(req.params.id), requesterId);
    res.json({ success: true, data: thread });
  },
);

/**
 * GET /negotiations/supplier/:stockholderId
 * Supplier's bargain inbox (param variant; auth still enforced).
 */
export const getSupplierNegotiationsByIdHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    if (req.userId! !== String(req.params.stockholderId)) {
      res.status(403).json({
        success: false,
        error: 'You can only view your own negotiations',
      });
      return;
    }
    const negotiations = await listSupplierNegotiations(
      String(req.params.stockholderId),
    );
    res.json({ success: true, data: negotiations });
  },
);

/**
 * POST /negotiations/:id/finalize
 * EITHER party accepts the current offer → confirmed order in one
 * transaction. Sets status to ACCEPTED.
 */
export const finalizeNegotiationHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const requesterId = req.userId!;
    const result = await finalizeNegotiation({
      negotiationId: String(req.params.id),
      requesterId,
    });
    res.json({ success: true, data: result });
  },
);
