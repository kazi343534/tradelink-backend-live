import { db } from '../db/pool.js';

export interface NegotiationDto {
  id: string;
  shopOwnerId: string;
  stockholderId: string;
  supplierName?: string;
  shopOwnerName?: string;
  stockId: string;
  productName: string;
  quantity: number;
  unit?: string;
  originalPrice: number;
  proposedPrice: number;
  lastOfferedBy: 'shop_owner' | 'supplier';
  status: 'PENDING' | 'COUNTERED' | 'ACCEPTED' | 'REJECTED' | 'ORDER_CREATED';
  message: string | null;
  counterMessage: string | null;
  orderId: string | null;
  createdAt: string;
  updatedAt: string;
}

function httpError(message: string, status: number): Error & { status: number } {
  const err = Object.assign(new Error(message), { status });
  return err;
}

function mapRow(row: any): NegotiationDto {
  return {
    id: row.id,
    shopOwnerId: row.shop_owner_id,
    stockholderId: row.stockholder_id,
    supplierName: row.supplier_name ?? undefined,
    shopOwnerName: row.shop_owner_name ?? undefined,
    stockId: row.stock_id,
    productName: row.product_name,
    quantity: Number(row.quantity),
    unit: row.unit ?? undefined,
    originalPrice: Number(row.original_price),
    proposedPrice: Number(row.current_proposed_price),
    lastOfferedBy: row.last_offered_by,
    status: row.status,
    message: row.message ?? null,
    counterMessage: row.counter_message ?? null,
    orderId: row.order_id ?? null,
    createdAt: row.created_at?.toISOString?.() ?? String(row.created_at),
    updatedAt: row.updated_at?.toISOString?.() ?? String(row.updated_at),
  };
}

const SELECT_BASE = `
  SELECT n.*,
         COALESCE(su.business_name, su.full_name, 'Supplier') AS supplier_name,
         COALESCE(ou.business_name, ou.full_name, 'Shop Owner') AS shop_owner_name,
         si.unit AS unit
  FROM public.negotiations n
  JOIN public.stockholder_inventory si ON si.id = n.stock_id
  LEFT JOIN public.users su ON su.id = n.stockholder_id
  LEFT JOIN public.users ou ON ou.id = n.shop_owner_id
`;

/**
 * Shop owner initiates a bargain from a marketplace product card.
 * Resolves the supplier + current listing price from the inventory item.
 */
export async function initiateNegotiation(input: {
  shopOwnerId: string;
  stockId: string;
  quantity: number;
  proposedPrice: number;
  message?: string | null;
}): Promise<NegotiationDto> {
  if (!(input.quantity > 0)) throw httpError('Quantity must be greater than zero', 400);
  if (!(input.proposedPrice > 0)) throw httpError('Proposed price must be greater than zero', 400);

  const client = await db.connect();
  try {
    await client.query('BEGIN');

    const stockRes = await client.query<{
      id: string;
      stockholder_id: string;
      custom_product_name: string;
      price_per_unit: string | number;
    }>(
      `SELECT id, stockholder_id, custom_product_name, price_per_unit
       FROM public.stockholder_inventory
       WHERE id = $1 AND is_available = true`,
      [input.stockId],
    );
    const stock = stockRes.rows[0];
    if (!stock) throw httpError('Product not found or unavailable', 404);
    if (stock.stockholder_id === input.shopOwnerId) {
      throw httpError('You cannot negotiate on your own product', 400);
    }

    // Replace any previous open bargain for the same item by this owner
    await client.query(
      `UPDATE public.negotiations
       SET status = 'REJECTED', updated_at = now()
       WHERE shop_owner_id = $1 AND stock_id = $2 AND status IN ('PENDING', 'COUNTERED')`,
      [input.shopOwnerId, input.stockId],
    );

    const result = await client.query(
      `INSERT INTO public.negotiations
         (shop_owner_id, stockholder_id, stock_id, product_name,
          quantity, original_price, current_proposed_price, last_offered_by, status, message)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'shop_owner', 'PENDING', $8)
       RETURNING id`,
      [
        input.shopOwnerId,
        stock.stockholder_id,
        stock.id,
        stock.custom_product_name,
        input.quantity,
        Number(stock.price_per_unit),
        input.proposedPrice,
        input.message ?? null,
      ],
    );

    await client.query(
      `INSERT INTO notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'negotiation')`,
      [
        stock.stockholder_id,
        'Bargain request received',
        `${stock.custom_product_name} — offer ৳${input.proposedPrice}/unit × ${input.quantity}. Review it in your negotiations.`,
      ],
    );

    await client.query('COMMIT');

    const created = await db.query(`${SELECT_BASE} WHERE n.id = $1`, [
      result.rows[0].id,
    ]);
    return mapRow(created.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/** All bargains belonging to a shop owner. */
export async function listShopOwnerNegotiations(
  shopOwnerId: string,
): Promise<NegotiationDto[]> {
  const { rows } = await db.query(
    `${SELECT_BASE} WHERE n.shop_owner_id = $1 ORDER BY n.updated_at DESC LIMIT 100`,
    [shopOwnerId],
  );
  return rows.map(mapRow);
}

/** All bargains addressed to a supplier. */
export async function listSupplierNegotiations(
  stockholderId: string,
): Promise<NegotiationDto[]> {
  const { rows } = await db.query(
    `${SELECT_BASE} WHERE n.stockholder_id = $1 ORDER BY n.updated_at DESC LIMIT 100`,
    [stockholderId],
  );
  return rows.map(mapRow);
}

/**
 * Supplier sends a counter-offer (or rejects the bargain outright).
 */
export async function counterNegotiation(input: {
  negotiationId: string;
  stockholderId: string;
  proposedPrice: number;
  counterMessage?: string | null;
}): Promise<NegotiationDto> {
  if (!(input.proposedPrice > 0)) throw httpError('Counter price must be greater than zero', 400);

  const client = await db.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `SELECT * FROM public.negotiations WHERE id = $1 FOR UPDATE`,
      [input.negotiationId],
    );
    const neg = rows[0];
    if (!neg) throw httpError('Negotiation not found', 404);
    if (neg.stockholder_id !== input.stockholderId) {
      throw httpError('You are not the supplier of this negotiation', 403);
    }
    if (!['PENDING', 'COUNTERED'].includes(neg.status)) {
      throw httpError(`Negotiation already ${neg.status}`, 409);
    }

    await client.query(
      `UPDATE public.negotiations
       SET current_proposed_price = $1, counter_message = $2,
           last_offered_by = 'supplier', status = 'COUNTERED', updated_at = now()
       WHERE id = $3`,
      [input.proposedPrice, input.counterMessage ?? null, input.negotiationId],
    );

    await client.query(
      `INSERT INTO notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'negotiation')`,
      [
        neg.shop_owner_id,
        'Counter-offer received',
        `Supplier offered ৳${input.proposedPrice}/unit for ${neg.product_name}. Accept to place the order.`,
      ],
    );

    await client.query('COMMIT');

    const updated = await db.query(`${SELECT_BASE} WHERE n.id = $1`, [
      input.negotiationId,
    ]);
    return mapRow(updated.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Shop owner accepts a COUNTERED offer (creating a confirmed pending
 * order) or declines the negotiation. Runs atomically.
 */
export async function respondToNegotiation(input: {
  negotiationId: string;
  shopOwnerId: string;
  action: 'accept' | 'decline';
}): Promise<NegotiationDto & { orderCreated?: boolean }> {
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `SELECT n.*, si.unit, si.price_per_unit
       FROM public.negotiations n
       JOIN public.stockholder_inventory si ON si.id = n.stock_id
       WHERE n.id = $1 FOR UPDATE`,
      [input.negotiationId],
    );
    const neg = rows[0];
    if (!neg) throw httpError('Negotiation not found', 404);
    if (neg.shop_owner_id !== input.shopOwnerId) {
      throw httpError('You are not the owner of this negotiation', 403);
    }

    if (input.action === 'decline') {
      if (!['PENDING', 'COUNTERED'].includes(neg.status)) {
        throw httpError(`Negotiation already ${neg.status}`, 409);
      }
      await client.query(
        `UPDATE public.negotiations
         SET status = 'REJECTED', last_offered_by = 'shop_owner', updated_at = now()
         WHERE id = $1`,
        [input.negotiationId],
      );
      await client.query(
        `INSERT INTO notifications (user_id, title, subtitle, type)
         VALUES ($1, $2, $3, 'negotiation')`,
        [
          neg.stockholder_id,
          'Bargain declined',
          `The shop owner declined the negotiation for ${neg.product_name}.`,
        ],
      );
      await client.query('COMMIT');
      const updated = await db.query(`${SELECT_BASE} WHERE n.id = $1`, [
        input.negotiationId,
      ]);
      return mapRow(updated.rows[0]);
    }

    // ── accept ──
    if (neg.last_offered_by !== 'supplier') {
      throw httpError(
        'Waiting for the supplier to respond before you can accept',
        409,
      );
    }
    if (!['PENDING', 'COUNTERED'].includes(neg.status)) {
      throw httpError(`Negotiation already ${neg.status}`, 409);
    }

    const orderId = await createOrderFromNegotiation(
      client,
      neg,
      input.shopOwnerId,
    );

    await client.query('COMMIT');

    const updated = await db.query(`${SELECT_BASE} WHERE n.id = $1`, [
      input.negotiationId,
    ]);
    return { ...mapRow(updated.rows[0]), orderCreated: true };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

// ── Real-time negotiation chat ────────────────────────────────────

export interface NegotiationMessageDto {
  id: string;
  senderType: 'SHOP_OWNER' | 'SUPPLIER';
  senderId: string;
  senderName: string;
  message: string;
  offeredPrice: number | null;
  createdAt: string;
}

/**
 * Shared order-creation core used by /respond (accept) and /finalize.
 * Caller owns the surrounding transaction. Sets status = 'ACCEPTED'.
 */
async function createOrderFromNegotiation(
  client: any,
  neg: any,
  acceptedByUserId: string,
): Promise<string> {
  // Re-validate live stock availability at the negotiated price
  const stockRes = await client.query(
    `SELECT quantity_available, is_available, unit
     FROM public.stockholder_inventory WHERE id = $1`,
    [neg.stock_id],
  );
  const stock = stockRes.rows[0];
  if (!stock || !stock.is_available || Number(stock.quantity_available) < Number(neg.quantity)) {
    throw httpError('Insufficient stock for this negotiation', 409);
  }
  const unit = stock.unit ?? 'pcs';

  const ownerRes = await client.query(
    `SELECT address FROM public.users WHERE id = $1`,
    [neg.shop_owner_id],
  );

  const totalAmount =
    Number(neg.current_proposed_price) * Number(neg.quantity);
  const orderRes = await client.query(
    `INSERT INTO public.orders
       (shop_owner_id, supplier_id, inventory_id, product_name,
        quantity, unit, unit_price, total_amount, status,
        payment_status, delivery_address)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending', 'unpaid', $9)
     RETURNING id`,
    [
      neg.shop_owner_id,
      neg.stockholder_id,
      neg.stock_id,
      neg.product_name,
      neg.quantity,
      unit,
      Number(neg.current_proposed_price),
      totalAmount,
      ownerRes.rows[0]?.address?.trim() || 'Selected Location',
    ],
  );

  await client.query(
    `UPDATE public.negotiations
     SET status = 'ACCEPTED', order_id = $1, accepted_by = $2, updated_at = now()
     WHERE id = $3`,
    [orderRes.rows[0].id, acceptedByUserId, neg.id],
  );

  const counterpartyId =
    acceptedByUserId === neg.stockholder_id ? neg.shop_owner_id : neg.stockholder_id;

  await client.query(
    `INSERT INTO notifications (user_id, title, subtitle, type)
     VALUES ($1, $2, $3, 'new_order')`,
    [
      counterpartyId,
      'Deal confirmed',
      `${neg.product_name} × ${neg.quantity} ${unit} at ৳${Number(neg.current_proposed_price).toFixed(2)}/unit (৳${totalAmount.toFixed(2)}) — order placed.`,
    ],
  );

  await client.query(
    `INSERT INTO notifications (user_id, title, subtitle, type)
     VALUES ($1, $2, $3, 'new_order')`,
    [
      neg.stockholder_id,
      'New order received',
      `Bargain accepted — ${neg.product_name} × ${neg.quantity} ${unit} at ৳${Number(neg.current_proposed_price).toFixed(2)}/unit (৳${totalAmount.toFixed(2)}).`,
    ],
  );

  return orderRes.rows[0].id;
}

/**
 * Either party sends a chat message and/or a price counter-offer.
 * An offeredPrice bumps the live negotiated price on the thread.
 */
export async function sendNegotiationMessage(input: {
  negotiationId: string;
  senderId: string;
  senderType: 'SHOP_OWNER' | 'SUPPLIER';
  message?: string | null;
  offeredPrice?: number | null;
}): Promise<NegotiationDto> {
  const text = input.message?.trim() ?? '';
  const hasOffer = input.offeredPrice != null && Number(input.offeredPrice) > 0;
  if (!text && !hasOffer) {
    throw httpError('Message or offered price is required', 400);
  }
  if (hasOffer && !(Number(input.offeredPrice) > 0)) {
    throw httpError('Offered price must be greater than zero', 400);
  }

  const client = await db.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `SELECT * FROM public.negotiations WHERE id = $1 FOR UPDATE`,
      [input.negotiationId],
    );
    const neg = rows[0];
    if (!neg) throw httpError('Negotiation not found', 404);

    const expectedSender =
      input.senderType === 'SHOP_OWNER' ? neg.shop_owner_id : neg.stockholder_id;
    if (expectedSender !== input.senderId) {
      throw httpError('You are not a participant of this negotiation', 403);
    }
    if (!['PENDING', 'COUNTERED'].includes(neg.status)) {
      throw httpError(`Negotiation already ${neg.status}`, 409);
    }

    const finalText =
      text ||
      `Countered with ৳${Number(input.offeredPrice).toFixed(2)}/unit`;

    await client.query(
      `INSERT INTO public.negotiation_messages
         (negotiation_id, sender_type, sender_id, message, offered_price)
       VALUES ($1, $2, $3, $4, $5)`,
      [input.negotiationId, input.senderType, input.senderId, finalText, hasOffer ? Number(input.offeredPrice) : null],
    );

    if (hasOffer) {
      await client.query(
        `UPDATE public.negotiations
         SET current_proposed_price = $1, last_offered_by = $2,
             status = CASE WHEN status = 'PENDING' THEN 'COUNTERED' ELSE status END,
             counter_message = NULL, updated_at = now()
         WHERE id = $3`,
        [Number(input.offeredPrice), input.senderType === 'SHOP_OWNER' ? 'shop_owner' : 'supplier', input.negotiationId],
      );
    }

    // Notify counterparty
    const counterpartyId =
      input.senderType === 'SHOP_OWNER' ? neg.stockholder_id : neg.shop_owner_id;
    const preview = hasOffer && !text
      ? `৳${Number(input.offeredPrice).toFixed(2)} offer`
      : finalText.slice(0, 80);
    await client.query(
      `INSERT INTO notifications (user_id, title, subtitle, type)
       VALUES ($1, $2, $3, 'negotiation')`,
      [counterpartyId, 'Negotiation message', preview],
    );

    await client.query('COMMIT');

    const updated = await db.query(`${SELECT_BASE} WHERE n.id = $1`, [
      input.negotiationId,
    ]);
    return mapRow(updated.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Full chat thread + negotiation summary. Participant-only.
 */
export async function getNegotiationThread(
  negotiationId: string,
  requesterId: string,
): Promise<{
  negotiation: NegotiationDto;
  messages: NegotiationMessageDto[];
}> {
  const { rows } = await db.query(
    `${SELECT_BASE} WHERE n.id = $1`,
    [negotiationId],
  );
  const neg = rows[0];
  if (!neg) throw httpError('Negotiation not found', 404);
  if (neg.shop_owner_id !== requesterId && neg.stockholder_id !== requesterId) {
    throw httpError('You are not a participant of this negotiation', 403);
  }

  const { rows: msgRows } = await db.query(
    `SELECT m.*, COALESCE(u.business_name, u.full_name, 'User') AS sender_name
     FROM public.negotiation_messages m
     LEFT JOIN public.users u ON u.id = m.sender_id
     WHERE m.negotiation_id = $1
     ORDER BY m.created_at ASC`,
    [negotiationId],
  );

  const messages: NegotiationMessageDto[] = msgRows.map((m) => ({
    id: m.id,
    senderType: m.sender_type,
    senderId: m.sender_id,
    senderName: m.sender_name,
    message: m.message,
    offeredPrice:
      m.offered_price != null ? Number(m.offered_price) : null,
    createdAt: m.created_at.toISOString(),
  }));

  return { negotiation: mapRow(neg), messages };
}

/**
 * Either party accepts the current offer → confirmed order in one txn.
 */
export async function finalizeNegotiation(input: {
  negotiationId: string;
  requesterId: string;
}): Promise<NegotiationDto & { orderId: string }> {
  const client = await db.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `SELECT * FROM public.negotiations WHERE id = $1 FOR UPDATE`,
      [input.negotiationId],
    );
    const neg = rows[0];
    if (!neg) throw httpError('Negotiation not found', 404);
    if (
      neg.shop_owner_id !== input.requesterId &&
      neg.stockholder_id !== input.requesterId
    ) {
      throw httpError('You are not a participant of this negotiation', 403);
    }
    if (!['PENDING', 'COUNTERED'].includes(neg.status)) {
      throw httpError(`Negotiation already ${neg.status}`, 409);
    }

    // Bidirectional offers: you can only accept an offer you RECEIVED.
    // The party that made the current offer must wait for a response.
    const requesterType =
      neg.shop_owner_id === input.requesterId ? 'shop_owner' : 'supplier';
    if (neg.last_offered_by === requesterType) {
      throw httpError(
        'You cannot accept your own offer — wait for a counter-offer',
        409,
      );
    }

    const orderId = await createOrderFromNegotiation(
      client,
      neg,
      input.requesterId,
    );

    await client.query('COMMIT');

    const updated = await db.query(`${SELECT_BASE} WHERE n.id = $1`, [
      input.negotiationId,
    ]);
    return { ...mapRow(updated.rows[0]), orderId };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
