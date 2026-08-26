import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import {
  ChatIntent,
  classifyIntent,
  parseProductIntent,
  parseBulkOrderItems,
  findSupplierByName,
  getSupplierCatalog,
  searchSuppliers,
  searchAllSuppliers,
  generateGreetingResponse,
  generateSearchResponse,
  generateUnknownResponse,
} from '../services/assistantService.js';
import { db } from '../db/pool.js';

/**
 * POST /assistant/order
 *
 * Chatbot bulk-order pipeline: inserts each parsed item into the demands
 * table with status 'open', targeted at the chosen supplier so it appears
 * as an Accept/Decline card on that supplier's Nearby Demands feed.
 * Body: { stockholderId: string, items: [{ name, quantity }] }
 */
export const placeChatbotOrderHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const shopOwnerId = req.userId!;
    const { stockholderId, items } = req.body as {
      stockholderId?: string;
      items?: { name?: string; quantity?: number }[];
    };

    if (!stockholderId || !Array.isArray(items) || items.length === 0) {
      res.status(400).json({
        success: false,
        error: 'Missing supplier ID or order items.',
      });
      return;
    }

    const client = await db.connect();
    try {
      await client.query('BEGIN');

      // Stamp the buyer's coordinates so nearby suppliers discover
      // this demand via proximity filtering.
      const ownerRes = await client.query<{
        latitude: number | null;
        longitude: number | null;
      }>(`SELECT latitude, longitude FROM public.users WHERE id = $1`, [
        shopOwnerId,
      ]);
      const ownerLat = ownerRes.rows[0]?.latitude ?? null;
      const ownerLng = ownerRes.rows[0]?.longitude ?? null;

      const createdDemands: string[] = [];

      for (const item of items) {
        const rawName = (item.name ?? '').trim();
        const quantity = Number(item.quantity);
        if (!rawName || !Number.isFinite(quantity) || quantity <= 0) continue;

        // Resolve product specs from the target supplier's inventory
        const productRes = await client.query<{
          custom_product_name: string;
          category: string;
          price_per_unit: string | number;
          unit: string;
        }>(
          `SELECT custom_product_name, category, price_per_unit, unit
           FROM public.stockholder_inventory
           WHERE stockholder_id = $1
             AND LOWER(custom_product_name) = LOWER($2)
           LIMIT 1`,
          [stockholderId, rawName],
        );

        const match = productRes.rows[0];
        const productName = match?.custom_product_name ?? rawName;
        const category = match?.category ?? 'Grocery';
        const unit = match?.unit ?? 'pcs';
        const targetPrice =
          match?.price_per_unit != null ? Number(match.price_per_unit) : null;

        const demandRes = await client.query<{ id: string }>(
          `INSERT INTO public.demands
             (shop_owner_id, target_supplier_id, product_name, category,
              quantity, unit, target_price, notes, status,
              latitude, longitude)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'open', $9, $10)
           RETURNING id`,
          [
            shopOwnerId,
            stockholderId,
            productName,
            category,
            quantity,
            unit,
            targetPrice,
            'Placed via TradeLink Assistant',
            ownerLat,
            ownerLng,
          ],
        );
        createdDemands.push(demandRes.rows[0].id);
      }

      if (createdDemands.length === 0) {
        await client.query('ROLLBACK');
        res.status(400).json({
          success: false,
          error: 'No valid items to order.',
        });
        return;
      }

      // Notify the target supplier about the incoming request(s)
      await client.query(
        `INSERT INTO notifications (user_id, title, subtitle, type)
         VALUES ($1, $2, $3, 'new_demand')`,
        [
          stockholderId,
          'New order request via Assistant',
          `${createdDemands.length} item request${createdDemands.length > 1 ? 's' : ''} from a nearby shop — review in Nearby Demands.`,
        ],
      );

      await client.query('COMMIT');

      res.status(201).json({
        success: true,
        data: {
          message: `${createdDemands.length} order request${createdDemands.length > 1 ? 's' : ''} sent to the supplier.`,
          demandIds: createdDemands,
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
import { getDemandTrends, getSupplyTrends, generateForecastAnalysis } from '../services/forecastService.js';

/**
 * POST /assistant/chat
 *
 * Central intent router. Classifies the user's message, then dispatches
 * to the appropriate handler (greeting / product search / forecast / unknown).
 *
 * Body: { message: string, shopLat?: number, shopLng?: number }
 */
export const assistantChatHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const { message, shopLat, shopLng } = req.body as {
      message?: string;
      shopLat?: number;
      shopLng?: number;
    };

    // ── Validate input ───────────────────────────────────────────
    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      res.status(400).json({ success: false, error: 'message is required' });
      return;
    }

    const lat = typeof shopLat === 'number' ? shopLat : 23.777176;
    const lng = typeof shopLng === 'number' ? shopLng : 90.399451;
    const trimmed = message.trim();

    // ── Classify intent ──────────────────────────────────────────
    const intent = classifyIntent(trimmed);

    console.log(`[assistant] intent=${intent} query="${trimmed}"`);

    // ── Route to handler ─────────────────────────────────────────
    try {
      // ── 1. Multi-item bulk order syntax ("oil=10", "kino 5 kg oil",
      //       "oil 10 ltr lagbe", "5 kg chawl dorkar", ...) ─────────
      const multiItems = parseBulkOrderItems(trimmed);
      if (multiItems) {
        const resolved = await Promise.all(
          multiItems.map(async (entry) => {
            const intent = parseProductIntent(entry.name);
            intent.productName = entry.name;
            const matches = await searchSuppliers(intent, lat, lng);
            return { name: entry.name, quantity: entry.quantity, match: matches[0] ?? null };
          }),
        );

        const estimatedTotal = resolved.reduce(
          (sum, r) => sum + (r.match ? r.match.pricePerUnit * r.quantity : 0),
          0,
        );
        const foundCount = resolved.filter((r) => r.match).length;

        res.json({
          success: true,
          data: {
            reply:
              foundCount === 0
                ? 'None of those items are available nearby right now. Try different product names.'
                : `Please confirm your ${foundCount}-item order details below. Estimated total: ৳${estimatedTotal.toFixed(2)}.`,
            intentType: 'MULTI_ITEM_ORDER',
            items: resolved.map((r) => ({
              name: r.name,
              quantity: r.quantity,
              match: r.match
                ? {
                  stockId: r.match.stockId,
                  stockholderId: r.match.stockholderId,
                  productName: r.match.productName,
                  storeName: r.match.supplierName,
                  price: r.match.pricePerUnit,
                  unit: r.match.unit,
                  quantityAvailable: r.match.quantityAvailable,
                  distanceKm: r.match.distanceKm,
                  rating: r.match.rating,
                  ratingCount: r.match.ratingCount,
                }
                : null,
            })),
            estimatedTotal,
          },
        });
        return;
      }

      switch (intent) {
        case ChatIntent.GREETING: {
          res.json({
            success: true,
            data: {
              reply: generateGreetingResponse(),
              suppliers: [],
              intentType: ChatIntent.GREETING,
            },
          });
          return;
        }

        case ChatIntent.PRODUCT_SEARCH: {
          // ── Supplier name lookup (e.g. "md firoz") ──────────────
          const supplier = await findSupplierByName(trimmed);
          if (supplier) {
            const catalog = await getSupplierCatalog(
              supplier.stockholderId,
              lat,
              lng,
            );
            if (catalog.length > 0) {
              const formattedCatalog = catalog.map((s, idx) => ({
                rank: idx + 1,
                storeName: s.supplierName,
                location: s.warehouseAddress || 'Unknown',
                distance: `${s.distanceKm} km`,
                distanceKm: s.distanceKm,
                price: s.pricePerUnit,
                unit: s.unit,
                rating: s.rating,
                ratingCount: s.ratingCount,
                stockBadge: 'In stock',
                inStock: true,
                isBestPrice: s.isBestPrice,
                imageUrl: s.imageUrl,
                stockId: s.stockId,
                stockholderId: s.stockholderId,
                productName: s.productName,
                quantityAvailable: s.quantityAvailable,
              }));
              res.json({
                success: true,
                data: {
                  reply: `Found supplier "${supplier.businessName}". Here are their ${catalog.length} available products — tap Order Now on any item.`,
                  suppliers: formattedCatalog,
                  intentType: 'SUPPLIER_CATALOG',
                  supplier: {
                    supplierId: supplier.stockholderId,
                    businessName: supplier.businessName,
                    phone: supplier.phone,
                    address: supplier.address,
                  },
                },
              });
              return;
            }
          }

          const productIntent = parseProductIntent(trimmed);
          const suppliers = await searchSuppliers(productIntent, lat, lng);

          const reply = generateSearchResponse(productIntent, suppliers);

          const formatted = suppliers.map((s, idx) => ({
            rank: idx + 1,
            storeName: s.supplierName,
            location: s.warehouseAddress || 'Unknown',
            distance: `${s.distanceKm} km`,
            distanceKm: s.distanceKm,
            price: s.pricePerUnit,
            unit: s.unit,
            rating: s.rating,
            ratingCount: s.ratingCount,
            stockBadge: s.quantityAvailable > 0 ? 'In stock' : 'Out of stock',
            inStock: s.quantityAvailable > 0,
            isBestPrice: s.isBestPrice,
            imageUrl: s.imageUrl,
            stockId: s.stockId,
            stockholderId: s.stockholderId,
            productName: s.productName,
            quantityAvailable: s.quantityAvailable,
          }));

          res.json({
            success: true,
            data: {
              reply,
              suppliers: formatted,
              intentType: ChatIntent.PRODUCT_SEARCH,
              intent: {
                productName: productIntent.productName,
                sortBy: productIntent.sortBy,
                maxDistance: productIntent.maxDistance,
              },
            },
          });
          return;
        }

        case ChatIntent.FORECAST_DEMAND: {
          const [demandTrends, supplyTrends] = await Promise.all([
            getDemandTrends(30).catch(() => []),
            getSupplyTrends().catch(() => []),
          ]);

          const analysis = generateForecastAnalysis(demandTrends, supplyTrends, null);

          res.json({
            success: true,
            data: {
              reply: analysis,
              suppliers: [],
              intentType: ChatIntent.FORECAST_DEMAND,
              forecast: {
                demandTrends: demandTrends.map((d) => ({
                  productName: d.product_name,
                  category: d.category,
                  totalDemand: d.total_demand,
                  avgQuantity: d.avg_quantity,
                  uniqueBuyers: d.unique_buyers,
                  status: d.status,
                })),
                supplyTrends: supplyTrends.map((s) => ({
                  productName: s.product_name,
                  category: s.category,
                  totalStock: s.total_stock,
                  avgPrice: s.avg_price,
                  supplierCount: s.supplier_count,
                  totalQuantity: s.total_quantity,
                })),
              },
            },
          });
          return;
        }

        default: {
          // Unknown intent — try a broad product search as fallback
          const suppliers = await searchAllSuppliers(lat, lng, 3);
          let reply = generateUnknownResponse();

          if (suppliers.length > 0) {
            const names = suppliers.map((s) => s.productName).slice(0, 3).join(', ');
            reply += `\n\nHere are some products available near you: ${names}`;
          }

          res.json({
            success: true,
            data: {
              reply,
              suppliers: [],
              intentType: ChatIntent.UNKNOWN,
            },
          });
          return;
        }
      }
    } catch (err) {
      console.error('[assistant] error:', err);

      // Graceful fallback — don't crash the chat
      let fallbackReply = 'Something went wrong while searching. ';

      if (err instanceof Error) {
        if (err.message.includes('ECONNREFUSED') || err.message.includes('connect')) {
          fallbackReply += 'The database seems to be offline. Please try again in a moment.';
        } else if (err.message.includes('does not exist') || err.message.includes('relation')) {
          fallbackReply += 'Some data tables are still being set up. Basic search is available.';
        } else {
          fallbackReply += 'Please try rephrasing your query or try again shortly.';
        }
      } else {
        fallbackReply += 'Please try again.';
      }

      // Try a graceful greeting-level fallback
      res.json({
        success: true,
        data: {
          reply: fallbackReply,
          suppliers: [],
          intentType: 'ERROR',
        },
      });
    }
  },
);
