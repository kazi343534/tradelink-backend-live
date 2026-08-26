# TradeLink

A B2B marketplace platform connecting shop owners, suppliers, and delivery riders in Bangladesh. Built with Flutter (mobile) + Node.js/Express (backend) + PostgreSQL/Supabase (database).

## Architecture

```
Flutter App (iOS/Android)
    |
    v
Node.js/Express API  (Render: tradelink-backend-live.onrender.com)
    |
    v
PostgreSQL (Supabase) + PostGIS
```

---

## Features by Role

### Shop Owner
- Post procurement demands with target price and delivery location
- Browse nearby supplier products (marketplace search with distance, price, rating sort)
- Place direct orders from marketplace with stock deduction
- Negotiate prices with suppliers via real-time chat
- View order history with status tracking (pending → accepted → out for delivery → delivered)
- Display OTP as QR code for rider delivery verification
- Leave star ratings and reviews after delivery
- AI assistant for natural language product search and bulk ordering
- 1:1 chat with suppliers

### Supplier / Stockholder
- Publish inventory with images, pricing, and warehouse location
- Accept or decline incoming demands and orders
- Request nearby riders for delivery (within 10km radius)
- Cancel rider request if no rider responds
- Track assigned riders on a live map (5s polling)
- Manage stock (add/edit/delete items)
- Negotiate prices with shop owners
- View completed orders with customer reviews
- Dashboard stats (new demands, pending orders, stock items)

### Delivery Rider
- Self-registration as independent rider
- View nearby delivery requests within 10km (Haversine distance filter)
- Accept delivery requests
- Pickup order → triggers OTP sent to shop owner
- Complete delivery via:
  - Manual OTP entry (6-digit code from shop owner)
  - QR code scan (scan shop owner's displayed QR)
- Continuous GPS location upload (1-minute intervals)
- Open pickup/dropoff locations in Google Maps
- Real-time polling for new requests and delivery updates

### Marketplace
- Full-text product search across all suppliers
- Category filtering (Grocery, Pharmacy, Hardware, Stationery)
- Sort by: Nearest, Lowest Price, Top Rated
- PostGIS spatial search with real distance calculations (earthdistance)
- Infinite scroll pagination (50 items per batch)
- Stock status badges (In Stock / Low Stock / Out of Stock)
- Product detail with customer reviews
- Supplier comparison (side-by-side)
- Price negotiation (bargaining chat)

### AI Assistant
- Natural language product search ("Find me rice nearby")
- Intent classification (DeepSeek LLM + regex fallback)
- Multi-item bulk ordering ("10 oil, 5 soap, 3 noodles")
- Supplier catalog lookup
- Demand/supply forecasting (30-day trend analysis)
- Agentic execution engine (max 5 iterations with tool calls)
- Order placement directly from chat

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.47, Dart |
| Backend | Node.js, Express, TypeScript |
| Database | PostgreSQL (Supabase) + PostGIS |
| Auth | Supabase Auth (JWT) + X-User-Id (demo) |
| AI | DeepSeek LLM API |
| Maps | OpenStreetMap, Google Maps (navigation) |
| QR | qr_flutter (display), mobile_scanner (scan) |
| Deploy | Render (backend), iOS device (Flutter) |
| SMS | Twilio (OTP delivery) |

---

## Project Structure

```
TradeLink/
├── lib/
│   ├── core/
│   │   ├── config/          # API config, Supabase config
│   │   ├── constants/       # Colors, categories
│   │   └── services/        # ApiService (HTTP layer)
│   └── features/
│       ├── auth/            # Login, registration, profile, orders, notifications
│       ├── delivery/        # Rider home, request details, QR scanner
│       └── marketplace/     # Search, product detail, chat, negotiation
├── backend/
│   ├── src/
│   │   ├── controllers/     # Route handlers (14 files)
│   │   ├── services/        # Business logic (16 files)
│   │   ├── routes/          # Express route definitions
│   │   ├── middleware/      # Auth, async handler, validation
│   │   ├── db/              # PostgreSQL connection pool
│   │   └── types/           # TypeScript interfaces
│   ├── dist/                # Compiled JS (committed for Render)
│   └── package.json
├── supabase/
│   └── migrations/          # 26 SQL migration files
└── ios/                     # iOS-specific config (permissions, signing)
```

---

## Database Schema (26 Migrations)

| Migration | Purpose |
|-----------|---------|
| 01 | Users table with role enum (shop_owner/supplier/delivery_man) |
| 02 | Products catalog |
| 03 | Supplier inventory (stockholder_inventory) |
| 04 | Shop owner procurement demands |
| 05 | Orders + OTPs tables |
| 06 | Notifications + ratings tables |
| 07-09 | Password hash, auth OTPs, extended profile |
| 10-13 | Language pref, demand location, delivery OTP, supplier match count |
| 14-15 | Product/stock refactor, PostGIS spatial search + earthdistance |
| 16-17 | Auto-rating trigger, product-level reviews |
| 18-20 | Orders-inventory link, demand target price, target supplier |
| 21-23 | Negotiations, negotiation chat, order pricing |
| 24-26 | Chat schema, delivery men, independent riders, stock images |

---

## API Endpoints

### Orders
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/orders/direct` | Place direct order from marketplace |
| GET | `/orders/shop-owner` | Shop owner's orders |
| GET | `/orders/pending` | Supplier's pending orders |
| GET | `/orders/completed` | Supplier's completed orders |
| POST | `/orders/:id/accept` | Accept order |
| POST | `/orders/:id/decline` | Decline order |
| POST | `/orders/:id/out-for-delivery` | Mark out for delivery |
| POST | `/orders/:id/send-otp` | Send OTP to shop owner |
| POST | `/orders/:id/verify-delivery` | Verify delivery with OTP |

### Delivery / Riders
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/delivery/register` | Rider registration |
| PATCH | `/orders/:id/request-rider` | Broadcast delivery request |
| PATCH | `/orders/:id/cancel-rider-request` | Cancel rider search |
| GET | `/delivery/requests` | Nearby delivery requests (10km) |
| PATCH | `/delivery/requests/:id/accept` | Accept delivery |
| GET | `/delivery/orders` | Rider's deliveries |
| PATCH | `/delivery/orders/:id/pickup` | Mark order picked up |
| PATCH | `/delivery/orders/:id/status` | Complete delivery (OTP/QR) |

### Marketplace
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/marketplace/search` | Search products (spatial) |
| POST | `/marketplace/products/:id` | Product detail |
| GET | `/reviews/inventory/:id/reviews` | Product reviews |

### Negotiation
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/negotiations/initiate` | Start bargain |
| POST | `/negotiations/message` | Send message |
| POST | `/negotiations/counter` | Counter-offer |
| POST | `/negotiations/respond` | Accept/decline |
| POST | `/negotiations/:id/finalize` | Convert to order |

### AI Assistant
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/assistant/chat` | Chat with intent classification |
| POST | `/assistant/forecast` | Demand/supply forecast |

---

## Getting Started

### Prerequisites
- Flutter 3.47+
- Node.js 18+
- Xcode (iOS development)
- Supabase project with PostgreSQL

### Backend Setup
```bash
cd backend
cp .env.example .env    # Configure DATABASE_URL, SUPABASE_JWT_SECRET, etc.
npm install
npm run build
npm start
```

### Flutter Setup
```bash
flutter pub get
flutter run
```

### Environment Variables (backend/.env)
```
DATABASE_URL=postgresql://...
SUPABASE_JWT_SECRET=...
DEEPSEEK_API_KEY=...
TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
TWILIO_PHONE_NUMBER=...
```

---

## Deployment

### Backend (Render)
1. Push to `main` branch of `kazi343534/tradelink-backend-live`
2. In Render dashboard: Manual Deploy → Deploy latest commit
3. After deploy, run `npm run build` and commit `backend/dist/` (Render runs compiled JS)

### iOS
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter run --release -d <device-id>
```

---

## License

This project was developed as part of CSE327 coursework.
