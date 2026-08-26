import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import { db } from '../db/pool.js';

interface ChatDto {
  id: string;
  shopOwnerId: string;
  stockholderId: string;
  productId: string | null;
  productName: string | null;
  productUnit: string | null;
  counterpartName: string;
  lastMessage: string;
  updatedAt: string;
}

function httpError(message: string, status: number): Error & { status: number } {
  return Object.assign(new Error(message), { status });
}

const CHAT_SELECT = `
  SELECT c.id,
         c.shop_owner_id,
         c.stockholder_id,
         c.product_id,
         si.custom_product_name AS product_name,
         si.unit AS product_unit,
         c.last_message,
         c.updated_at,
         COALESCE(ou.business_name, ou.full_name, 'Shop Owner') AS shop_owner_name,
         COALESCE(su.business_name, su.full_name, 'Supplier') AS supplier_name
  FROM public.chats c
  LEFT JOIN public.stockholder_inventory si ON si.id = c.product_id
  LEFT JOIN public.users ou ON ou.id = c.shop_owner_id
  LEFT JOIN public.users su ON su.id = c.stockholder_id
`;

function mapChat(row: any, viewerRole: 'shop_owner' | 'supplier'): ChatDto {
  return {
    id: row.id,
    shopOwnerId: row.shop_owner_id,
    stockholderId: row.stockholder_id,
    productId: row.product_id ?? null,
    productName: row.product_name ?? null,
    productUnit: row.product_unit ?? null,
    counterpartName:
      (viewerRole === 'shop_owner' ? row.supplier_name : row.shop_owner_name) ??
      'User',
    lastMessage: row.last_message ?? '',
    updatedAt: row.updated_at?.toISOString?.() ?? String(row.updated_at),
  };
}

/**
 * POST /chats/start
 * Initializes or returns an existing thread between the authed shop
 * owner and a supplier, optionally scoped to a product.
 * Body: { stockholderId?, productId? }
 */
export const startChatHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const shopOwnerId = req.userId!;
    const { stockholderId, productId } = req.body as {
      stockholderId?: string;
      productId?: string;
    };

    let resolvedSupplier = stockholderId ? String(stockholderId) : null;
    let resolvedProduct = productId ? String(productId) : null;

    if (!resolvedSupplier && resolvedProduct) {
      const { rows } = await db.query(
        `SELECT stockholder_id FROM public.stockholder_inventory WHERE id = $1`,
        [resolvedProduct],
      );
      resolvedSupplier = rows[0]?.stockholder_id ?? null;
    }
    if (!resolvedSupplier) {
      res.status(400).json({
        success: false,
        error: 'stockholderId or productId is required',
      });
      return;
    }
    if (resolvedSupplier === shopOwnerId) {
      res.status(400).json({
        success: false,
        error: 'You cannot start a chat with yourself',
      });
      return;
    }

    const client = await db.connect();
    try {
      await client.query('BEGIN');
      // Lock matching threads to avoid duplicate creation under races
      const existing = await client.query(
        `SELECT id FROM public.chats
         WHERE shop_owner_id = $1 AND stockholder_id = $2
           AND COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::uuid)
               = COALESCE($3, '00000000-0000-0000-0000-000000000000'::uuid)
         FOR UPDATE`,
        [shopOwnerId, resolvedSupplier, resolvedProduct],
      );

      let chatId: string;
      if (existing.rows.length > 0) {
        chatId = existing.rows[0].id;
      } else {
        const inserted = await client.query<{ id: string }>(
          `INSERT INTO public.chats (shop_owner_id, stockholder_id, product_id)
           VALUES ($1, $2, $3)
           RETURNING id`,
          [shopOwnerId, resolvedSupplier, resolvedProduct],
        );
        chatId = inserted.rows[0].id;

        await client.query(
          `INSERT INTO notifications (user_id, title, subtitle, type)
           VALUES ($1, $2, $3, 'chat')`,
          [
            resolvedSupplier,
            'New message request',
            'A shop owner started a conversation with you.',
          ],
        );
      }
      await client.query('COMMIT');

      const { rows } = await db.query(`${CHAT_SELECT} WHERE c.id = $1`, [chatId]);
      res.json({ success: true, data: mapChat(rows[0], 'shop_owner') });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  },
);

/**
 * GET /chats/user — conversations for the authed user, latest first.
 */
export const getUserChatsHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const userId = req.userId!;
    const role = (req.role ?? '').toLowerCase() === 'supplier'
      ? 'supplier'
      : 'shop_owner';

    const column = role === 'supplier' ? 'stockholder_id' : 'shop_owner_id';
    const { rows } = await db.query(
      `${CHAT_SELECT} WHERE c.${column} = $1 ORDER BY c.updated_at DESC LIMIT 100`,
      [userId],
    );

    res.json({
      success: true,
      data: rows.map((r) => mapChat(r, role as 'shop_owner' | 'supplier')),
    });
  },
);

/**
 * GET /chats/:chatId/messages — full history. Participant-only.
 */
export const getChatMessagesHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const userId = req.userId!;
    const role = (req.role ?? '').toLowerCase() === 'supplier'
      ? 'supplier'
      : 'shop_owner';
    const chatId = String(req.params.chatId);

    const { rows: chatRows } = await db.query(
      `${CHAT_SELECT} WHERE c.id = $1`,
      [chatId],
    );
    const chat = chatRows[0];
    if (!chat) throw httpError('Chat not found', 404);
    if (chat.shop_owner_id !== userId && chat.stockholder_id !== userId) {
      throw httpError('You are not a participant of this chat', 403);
    }

    const { rows } = await db.query(
      `SELECT m.*, COALESCE(u.business_name, u.full_name, 'User') AS sender_name
       FROM public.messages m
       LEFT JOIN public.users u ON u.id = m.sender_id
       WHERE m.chat_id = $1
       ORDER BY m.created_at ASC`,
      [chatId],
    );

    res.json({
      success: true,
      data: {
        chat: mapChat(chat, role as 'shop_owner' | 'supplier'),
        messages: rows.map((m) => ({
          id: m.id,
          senderType: m.sender_type,
          senderId: m.sender_id,
          senderName: m.sender_name,
          textContent: m.text_content,
          createdAt: m.created_at.toISOString(),
        })),
      },
    });
  },
);

/**
 * POST /chats/:chatId/messages
 * Appends a message and bumps the thread's updated_at.
 * Body: { textContent }
 */
export const sendChatMessageHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const senderId = req.userId!;
    const role = (req.role ?? '').toLowerCase() === 'supplier'
      ? 'supplier'
      : 'shop_owner';
    const senderType = role === 'shop_owner' ? 'SHOP_OWNER' : 'SUPPLIER';
    const chatId = String(req.params.chatId);
    const { textContent } = req.body as { textContent?: string };
    const text = textContent?.trim();

    if (!text) {
      res.status(400).json({ success: false, error: 'textContent is required' });
      return;
    }

    const client = await db.connect();
    try {
      await client.query('BEGIN');
      const { rows } = await client.query(
        `SELECT * FROM public.chats WHERE id = $1 FOR UPDATE`,
        [chatId],
      );
      const chat = rows[0];
      if (!chat) throw httpError('Chat not found', 404);
      if (
        chat.shop_owner_id !== senderId &&
        chat.stockholder_id !== senderId
      ) {
        throw httpError('You are not a participant of this chat', 403);
      }

      const inserted = await client.query(
        `INSERT INTO public.messages
           (chat_id, sender_type, sender_id, text_content)
         VALUES ($1, $2, $3, $4)
         RETURNING id, created_at`,
        [chatId, senderType, senderId, text],
      );

      await client.query(
        `UPDATE public.chats SET last_message = $1, updated_at = now()
         WHERE id = $2`,
        [text.slice(0, 200), chatId],
      );

      // Notify counterparty
      const counterpartyId =
        senderType === 'SHOP_OWNER' ? chat.stockholder_id : chat.shop_owner_id;
      await client.query(
        `INSERT INTO notifications (user_id, title, subtitle, type)
         VALUES ($1, $2, $3, 'chat')`,
        [counterpartyId, 'New message', text.slice(0, 80)],
      );

      await client.query('COMMIT');

      res.status(201).json({
        success: true,
        data: {
          id: inserted.rows[0].id,
          createdAt: inserted.rows[0].created_at.toISOString(),
        },
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  },
);
