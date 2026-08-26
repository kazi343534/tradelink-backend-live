import { db } from '../db/pool.js';
// ── Intent Classification ──────────────────────────────────────────
export var ChatIntent;
(function (ChatIntent) {
    ChatIntent["GREETING"] = "GREETING";
    ChatIntent["PRODUCT_SEARCH"] = "PRODUCT_SEARCH";
    ChatIntent["FORECAST_DEMAND"] = "FORECAST_DEMAND";
    ChatIntent["UNKNOWN"] = "UNKNOWN";
})(ChatIntent || (ChatIntent = {}));
export function classifyIntent(message) {
    const lower = message.toLowerCase().trim();
    if (['hi', 'hello', 'hey', 'start', 'help', 'yo', 'sup', 'howdy'].includes(lower)) {
        return ChatIntent.GREETING;
    }
    if (/\b(demand|forecast|next week|next month|trend|popular|trending|what will sell|what should i stock|season|outlook|predict)\b/.test(lower)) {
        return ChatIntent.FORECAST_DEMAND;
    }
    return ChatIntent.PRODUCT_SEARCH;
}
// ── Keyword maps ───────────────────────────────────────────────────
const SORT_KEYWORDS = {
    cheapest: 'price',
    lowest: 'price',
    'best price': 'price',
    affordable: 'price',
    close: 'distance',
    nearest: 'distance',
    nearby: 'distance',
    closest: 'distance',
    distance: 'distance',
    rated: 'rating',
    'best rated': 'rating',
    top: 'rating',
    'top rated': 'rating',
    'highest rated': 'rating',
    'lowest rated': 'rating_asc',
    'worst rated': 'rating_asc',
    'low rating': 'rating_asc',
};
const CATEGORY_KEYWORDS = {
    rice: 'Grocery',
    wheat: 'Grocery',
    sugar: 'Grocery',
    oil: 'Grocery',
    spice: 'Grocery',
    tea: 'Grocery',
    coffee: 'Grocery',
    flour: 'Grocery',
    salt: 'Grocery',
    milk: 'Grocery',
    medicine: 'Pharmacy',
    drug: 'Pharmacy',
    pill: 'Pharmacy',
    tablet: 'Pharmacy',
    pen: 'Stationery',
    pencil: 'Stationery',
    paper: 'Stationery',
    notebook: 'Stationery',
    hammer: 'Hardware',
    nail: 'Hardware',
    screw: 'Hardware',
    tool: 'Hardware',
    paint: 'Hardware',
};
const FILLER_WORDS = /\b(find|get|show|search|where|can|i|me|need|want|buy|look|looking for|sort|by|only|within|less than|under|max|and|up|the|a|an|some|any|please|plz|instead|results|filter|sorted)\b/gi;
/**
 * Detects bulk order syntax like "oil=10, rice=22".
 * Returns null when the message doesn't use (valid) multi-item syntax.
 */
export function parseMultiItemOrder(message) {
    if (!message.includes('='))
        return null;
    const entries = [];
    for (const part of message.split(',')) {
        const [rawName, rawQty] = part.split('=');
        // Strip action verbs so "order oil=10" resolves to product "oil"
        const name = (rawName ?? '')
            .trim()
            .toLowerCase()
            .replace(/\b(order|buy|purchase|get|need|want|kino|kinbo|dorkar|lagbe|chaile|dao|deu)\b/g, '')
            .replace(/\s+/g, ' ')
            .trim();
        const quantity = parseFloat((rawQty ?? '').trim());
        if (!name || !Number.isFinite(quantity) || quantity <= 0)
            return null;
        entries.push({ name, quantity });
    }
    return entries.length > 0 ? entries : null;
}
// ── Natural / Banglish order parsing ──────────────────────────────
// Supports flexible word orders:
//   "kino 5 kg oil"      (verb -> qty -> unit -> product)
//   "buy 5kg rice"       (verb -> qtyunit -> product)
//   "5 kg chawl dorkar"  (qty -> unit -> product -> verb)
//   "oil 10 ltr lagbe"   (product -> qty -> unit -> verb)
//   "order 10l oil"      (verb -> qtyunit -> product)
// Units: litre/liter/ltr/l/litter, kg/kgs/kilogram, gram/gm, pcs/pieces,
//        ta, dostha/dosta.
const ORDER_TRIGGERS = '(?:kino|kinbo|krbo|kine\\s+labo|dorkar|lagbe|chai|chaile|aamake\\s+dao|amar\\s+dao|dao|deu|diyo|order|buy|need|want)';
const UNIT_WORDS = 'dostha|dosta|litres|litre|liter|litter|ltrs|ltr|kilograms|kilogram|kgs|kg|grams|gram|gm|pieces|piece|pcs|ta|l';
/** Residual intent words stripped out of captured product names. */
const RESIDUAL_WORDS = /\b(aamake|amar|please|plz|kino|kinbo|krbo|dorkar|lagbe|chai|chaile|dao|deu|diyo|order|buy|need|want)\b/gi;
function cleanupItemName(raw) {
    const cleaned = raw
        .replace(RESIDUAL_WORDS, ' ')
        .replace(new RegExp(`\\b(?:${UNIT_WORDS})\\b`, 'gi'), ' ')
        .replace(/[^a-zA-Z\s]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
    return cleaned.length >= 2 ? cleaned : null;
}
/**
 * Parse ONE text segment as a natural-language order item.
 * Returns null when the segment isn't an order phrase.
 */
export function parseNaturalOrderItem(segment) {
    let input = segment.trim().toLowerCase();
    if (!input || !/[0-9]/.test(input) || /\bkm\b|\bkilometer/.test(input)) {
        return null;
    }
    // Banglish possessive wrappers: "aamake ... dao", "amar ... lagbe"
    input = input.replace(/^(?:aamake|amar)\s+/, '');
    // Pattern A: [verb] -> qty -> [unit] -> product
    // e.g. "kino 5 kg oil", "buy 5kg rice", "5 kg chawl dorkar", "order 10l oil"
    const patternA = new RegExp(`^(?:${ORDER_TRIGGERS})?\\s*(\\d+(?:\\.\\d+)?)\\s*(?:${UNIT_WORDS})?\\s+([a-z\\s]+)$`, 'i');
    // Pattern B: product -> qty -> [unit] -> [verb]
    // e.g. "oil 10 ltr lagbe", "rice 10kg order", "napa 3 ta dao"
    const patternB = new RegExp(`^([a-z\\s]+?)\\s+(\\d+(?:\\.\\d+)?)\\s*(?:${UNIT_WORDS})?\\s*(?:${ORDER_TRIGGERS})?$`, 'i');
    let productName = null;
    let quantity = null;
    const matchA = input.match(patternA);
    if (matchA) {
        quantity = parseFloat(matchA[1]);
        productName = cleanupItemName(matchA[2]);
    }
    else {
        const matchB = input.match(patternB);
        if (matchB) {
            productName = cleanupItemName(matchB[1]);
            quantity = parseFloat(matchB[2]);
        }
    }
    if (!productName || quantity == null || !Number.isFinite(quantity) || quantity <= 0) {
        return null;
    }
    return { name: productName, quantity };
}
/**
 * Parse any supported bulk-order syntax into structured items:
 * key-value pairs ("oil=10, rice=22") or natural/Banglish phrases
 * ("kino 5 kg oil", "oil 10 ltr lagbe"), including comma-separated mixes.
 */
export function parseBulkOrderItems(message) {
    if (message.includes('='))
        return parseMultiItemOrder(message);
    const entries = [];
    for (const segment of message.split(',')) {
        const parsed = parseNaturalOrderItem(segment);
        if (parsed)
            entries.push(parsed);
    }
    return entries.length > 0 ? entries : null;
}
/**
 * Find a supplier (user with role='supplier') whose business or full name
 * matches the given free-text query.
 */
export async function findSupplierByName(query) {
    const { rows } = await db.query(`SELECT id AS stockholder_id,
            COALESCE(business_name, full_name, 'Supplier') AS business_name,
            COALESCE(phone_number, '') AS phone,
            COALESCE(address, '') AS address
     FROM public.users
     WHERE role = 'supplier'
       AND (
         LOWER(COALESCE(business_name, '')) LIKE LOWER($1)
         OR LOWER(full_name) LIKE LOWER($1)
       )
     LIMIT 1`, [`%${query}%`]);
    if (rows.length === 0)
        return null;
    return {
        stockholderId: rows[0].stockholder_id,
        businessName: rows[0].business_name,
        phone: rows[0].phone,
        address: rows[0].address,
    };
}
/**
 * Fetch all available inventory items for a supplier, formatted exactly
 * like PRODUCT_SEARCH results so the Flutter client can reuse its cards.
 */
export async function getSupplierCatalog(stockholderId, shopLat, shopLng) {
    const sql = `
    SELECT
      si.id AS stock_id,
      si.stockholder_id,
      COALESCE(u.full_name, 'Unknown Supplier') AS supplier_name,
      COALESCE(u.address, '') AS warehouse_address,
      COALESCE(NULLIF(si.custom_product_name, ''), 'Unnamed Product') AS product_name,
      si.category,
      si.price_per_unit,
      si.quantity_available,
      si.unit,
      si.image_url,
      COALESCE(si.rating, 5.0) AS rating,
      COALESCE(si.review_count, 0) AS rating_count,
      ${haversineSql()} AS distance_km
    FROM public.stockholder_inventory si
    JOIN public.users u ON si.stockholder_id = u.id
    WHERE si.stockholder_id = $3
      AND si.is_available = true
      AND si.quantity_available > 0
    ORDER BY si.price_per_unit ASC
    LIMIT 20
  `;
    let rows = [];
    try {
        const result = await db.query(sql, [shopLat, shopLng, stockholderId]);
        rows = result.rows;
    }
    catch (dbErr) {
        console.error('[assistant] getSupplierCatalog error:', dbErr?.message ?? dbErr);
        return [];
    }
    const bestPrice = rows.length > 0 ? rows[0].price_per_unit : 0;
    return rows.map((row) => ({
        stockId: row.stock_id,
        stockholderId: row.stockholder_id,
        supplierName: row.supplier_name,
        warehouseAddress: row.warehouse_address,
        productName: row.product_name,
        category: row.category,
        pricePerUnit: row.price_per_unit,
        quantityAvailable: row.quantity_available,
        unit: row.unit,
        imageUrl: row.image_url,
        distanceKm: row.distance_km,
        rating: Number(row.rating) || 5.0,
        ratingCount: Number(row.rating_count) || 0,
        isBestPrice: row.price_per_unit === bestPrice,
    }));
}
const FILTER_PHRASES = /\b(cheapest|nearest|closest|best price|low price|nearby|near|close|top rated|best rated|4\.5|4 star|★|sort by|sorted by|order by|ordered by|within|less than|under|max|maximum|distance)\b/gi;
// ── Parse product search intent from free text ─────────────────────
export function parseProductIntent(text) {
    const lower = text.toLowerCase().trim();
    // Sort
    let sortBy = 'price';
    for (const [keyword, sort] of Object.entries(SORT_KEYWORDS)) {
        if (lower.includes(keyword)) {
            sortBy = sort;
            break;
        }
    }
    // Max distance
    let maxDistance = 50;
    const distMatch = lower.match(/(\d+)\s*(?:km|kilometer)/);
    if (distMatch)
        maxDistance = parseInt(distMatch[1], 10);
    if (/\b(near|close|nearby)\b/.test(lower))
        maxDistance = Math.min(maxDistance, 10);
    // Min rating
    let minRating = 0;
    const ratingMatch = lower.match(/(\d+(?:\.\d+)?)\s*(?:★|star|rating)/);
    if (ratingMatch)
        minRating = parseFloat(ratingMatch[1]);
    if (/4\.5/.test(lower))
        minRating = Math.max(minRating, 4.5);
    // Quantity
    let quantity = null;
    const qtyMatch = lower.match(/(\d+(?:\.\d+)?)\s*(?:kg|ltr|litre|liter|pcs|piece)/);
    if (qtyMatch)
        quantity = parseFloat(qtyMatch[1]);
    // Category
    let category = null;
    for (const [kw, cat] of Object.entries(CATEGORY_KEYWORDS)) {
        if (lower.includes(kw)) {
            category = cat;
            break;
        }
    }
    // Product name — strip filler words, filter phrases, numbers, and units
    let raw = lower
        .replace(FILLER_WORDS, '')
        .replace(FILTER_PHRASES, '')
        .replace(/\b\d+\s*(?:km|kilometer|kg|ltr|pcs|star|★)?\b/gi, '')
        .replace(/\s+/g, ' ')
        .trim();
    const productName = raw.length >= 2 ? raw : null;
    return { productName, sortBy, maxDistance, minRating, category, quantity };
}
// ── Haversine distance SQL fragment ────────────────────────────────
// Clamps the ACOS input to [-1, 1] to prevent numeric domain errors
// caused by floating-point imprecision.
function haversineSql() {
    return `
    CASE
      WHEN u.latitude IS NOT NULL AND u.longitude IS NOT NULL THEN
        ROUND(CAST(
          6371 * ACOS(
            GREATEST(-1, LEAST(1,
              COS(RADIANS($1)) * COS(RADIANS(u.latitude))
              * COS(RADIANS(u.longitude) - RADIANS($2))
              + SIN(RADIANS($1)) * SIN(RADIANS(u.latitude))
            ))
          ) AS numeric
        ), 1)
      ELSE 999
    END
  `;
}
// ── Search suppliers in PostgreSQL ─────────────────────────────────
export async function searchSuppliers(intent, shopLat, shopLng) {
    const haversine = haversineSql();
    let sql = `
    SELECT
      si.id AS stock_id,
      si.stockholder_id,
      COALESCE(u.full_name, 'Unknown Supplier') AS supplier_name,
      COALESCE(u.address, '') AS warehouse_address,
      COALESCE(NULLIF(si.custom_product_name, ''), 'Unnamed Product') AS product_name,
      si.category,
      si.price_per_unit,
      si.quantity_available,
      si.unit,
      si.image_url,
      COALESCE(si.rating, 5.0) AS rating,
      COALESCE(si.review_count, 0) AS rating_count,
      ${haversine} AS distance_km
    FROM public.stockholder_inventory si
    JOIN public.users u ON si.stockholder_id = u.id
    WHERE si.is_available = true
      AND si.quantity_available > 0
  `;
    const params = [shopLat, shopLng];
    let idx = 3;
    // Product name filter
    if (intent.productName) {
        sql += ` AND (
      LOWER(si.custom_product_name) ILIKE $${idx}
      OR LOWER(si.category) ILIKE $${idx}
    )`;
        params.push(`%${intent.productName}%`);
        idx++;
    }
    // Category filter
    if (intent.category) {
        sql += ` AND LOWER(si.category) = LOWER($${idx})`;
        params.push(intent.category);
        idx++;
    }
    // Distance filter — reuse the same Haversine expression
    sql += ` AND ${haversine} <= $${idx}`;
    params.push(intent.maxDistance);
    idx++;
    // Sort
    switch (intent.sortBy) {
        case 'price':
            sql += ` ORDER BY si.price_per_unit ASC, distance_km ASC`;
            break;
        case 'distance':
            sql += ` ORDER BY distance_km ASC, si.price_per_unit ASC`;
            break;
        case 'rating':
            sql += ` ORDER BY rating DESC, distance_km ASC`;
            break;
        case 'rating_asc':
            sql += ` ORDER BY (COALESCE(si.review_count, 0) > 0) DESC, rating ASC, distance_km ASC`;
            break;
    }
    sql += ` LIMIT 10`;
    let rows;
    try {
        const result = await db.query(sql, params);
        rows = result.rows;
    }
    catch (dbErr) {
        console.error('[assistant] searchSuppliers query error:', dbErr?.message ?? dbErr);
        // Return empty rather than crash — the controller handles empty results gracefully
        return [];
    }
    const bestPrice = rows.length > 0 ? rows[0].price_per_unit : 0;
    return rows.map((row) => ({
        stockId: row.stock_id,
        stockholderId: row.stockholder_id,
        supplierName: row.supplier_name,
        warehouseAddress: row.warehouse_address,
        productName: row.product_name,
        category: row.category,
        pricePerUnit: row.price_per_unit,
        quantityAvailable: row.quantity_available,
        unit: row.unit,
        imageUrl: row.image_url,
        distanceKm: row.distance_km,
        rating: Number(row.rating) || 5.0,
        ratingCount: Number(row.rating_count) || 0,
        isBestPrice: row.price_per_unit === bestPrice,
    }));
}
// ── Broad search fallback (no product filter) ─────────────────────
export async function searchAllSuppliers(shopLat, shopLng, limit = 5) {
    const haversine = haversineSql();
    const sql = `
    SELECT
      si.id AS stock_id,
      si.stockholder_id,
      COALESCE(u.full_name, 'Unknown Supplier') AS supplier_name,
      COALESCE(u.address, '') AS warehouse_address,
      COALESCE(NULLIF(si.custom_product_name, ''), 'Unnamed Product') AS product_name,
      si.category,
      si.price_per_unit,
      si.quantity_available,
      si.unit,
      si.image_url,
      COALESCE(si.rating, 5.0) AS rating,
      COALESCE(si.review_count, 0) AS rating_count,
      ${haversine} AS distance_km
    FROM public.stockholder_inventory si
    JOIN public.users u ON si.stockholder_id = u.id
    WHERE si.is_available = true
      AND si.quantity_available > 0
    ORDER BY distance_km ASC, si.price_per_unit ASC
    LIMIT $3
  `;
    let rows;
    try {
        const result = await db.query(sql, [shopLat, shopLng, limit]);
        rows = result.rows;
    }
    catch (dbErr) {
        console.error('[assistant] searchAllSuppliers query error:', dbErr?.message ?? dbErr);
        return [];
    }
    const bestPrice = rows.length > 0 ? rows[0].price_per_unit : 0;
    return rows.map((row) => ({
        stockId: row.stock_id,
        stockholderId: row.stockholder_id,
        supplierName: row.supplier_name,
        warehouseAddress: row.warehouse_address,
        productName: row.product_name,
        category: row.category,
        pricePerUnit: row.price_per_unit,
        quantityAvailable: row.quantity_available,
        unit: row.unit,
        imageUrl: row.image_url,
        distanceKm: row.distance_km,
        rating: Number(row.rating) || 5.0,
        ratingCount: Number(row.rating_count) || 0,
        isBestPrice: row.price_per_unit === bestPrice,
    }));
}
// ── Response generation ────────────────────────────────────────────
export function generateGreetingResponse() {
    return "Hi there! I'm TradeLink Assistant. Tell me what product you're looking for and I'll find the best suppliers near you.\n\nTry something like:\n• \"Rice\"\n• \"Cheapest oil near me\"\n• \"Medicine within 5 km\"";
}
export function generateSearchResponse(intent, results) {
    if (results.length === 0) {
        if (intent.productName) {
            return `I couldn't find any suppliers for "${intent.productName}" within ${intent.maxDistance} km. Try broadening your search or check back later.`;
        }
        return "I couldn't find matching suppliers. Try specifying a product name like \"Rice\", \"Oil\", or \"Medicine\".";
    }
    const product = intent.productName || 'your product';
    const best = results[0];
    switch (intent.sortBy) {
        case 'distance':
            return `Found ${results.length} supplier${results.length > 1 ? 's' : ''} for "${product}" nearby. Closest is ${best.supplierName} at ${best.distanceKm} km, priced at ৳${best.pricePerUnit}/${best.unit}.`;
        case 'rating':
            return `Found ${results.length} supplier${results.length > 1 ? 's' : ''} for "${product}". Top rated is ${best.supplierName} (${best.rating}★), ৳${best.pricePerUnit}/${best.unit}.`;
        case 'rating_asc':
            return `Found ${results.length} supplier${results.length > 1 ? 's' : ''} for "${product}". Lowest rated match is ${best.supplierName} (${best.rating}★), ৳${best.pricePerUnit}/${best.unit}.`;
        default:
            return `Found ${results.length} supplier${results.length > 1 ? 's' : ''} for "${product}". Best price is ৳${best.pricePerUnit}/${best.unit} at ${best.supplierName}, ${best.distanceKm} km away.`;
    }
}
export function generateUnknownResponse() {
    return "I'm not sure what you're looking for. Try asking about a product like \"Rice\" or \"Oil\", or say \"forecast\" to see demand trends.";
}
//# sourceMappingURL=assistantService.js.map