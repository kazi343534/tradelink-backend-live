// Shared API DTOs. Field names mirror the Flutter client models so the
// frontend can deserialize responses without mapping.

export type UserRole = 'shop_owner' | 'supplier';

// ---- Tier 1: Master Product Catalog ----

export interface MasterProduct {
  id: string;
  name: string;
  category: string;
  unit: string;
  createdAt: string;
}

// ---- Tier 2: Stockholder Inventory ----

export interface StockItem {
  id: string;
  stockholderId: string;
  masterProductId: string | null;
  customProductName: string;
  category: string;
  pricePerUnit: number;
  quantityAvailable: number;
  unit: string;
  isAvailable: boolean;
  imageUrl: string | null;
  deliveryRadiusKm: number;
  createdAt: string;
  updatedAt: string;
}

// ---- Marketplace Search Result ----

export interface MarketplaceProduct {
  stockId: string;
  stockholderId: string;
  supplierName: string;
  warehouseAddress: string | null;
  supplierLat: number | null;
  supplierLng: number | null;
  supplierPhone?: string | null;
  productName: string;
  category: string;
  pricePerUnit: number;
  quantityAvailable: number;
  unit: string;
  imageUrl: string | null;
  deliveryRadiusKm: number;
  distanceKm: number;
  rating: number;
  ratingCount: number;
}

export interface MarketplaceSearchParams {
  query: string;
  shopLat: number | null;
  shopLng: number | null;
  category?: string;
  maxDistance?: number;
  sortBy?: string;
  limit?: number;
  offset?: number;
}

export interface NearbyDemand {
  id: string;
  shopOwnerId: string;
  productName: string;
  category: string;
  quantity: number;
  unit: string;
  notes: string | null;
  targetPrice?: number | null;
  deliveryAddress?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  distanceKm?: number | null;
  supplierMatchCount?: number;
  shopOwnerName?: string;
  shopOwnerPhone?: string;
  status: DemandStatus;
  createdAt: string;
}

export type DemandStatus =
  | 'open'
  | 'pending'
  | 'accepted'
  | 'delivered'
  | 'cancelled';

export interface OrderItem {
  id: string;
  demandId: string | null;
  shopOwnerId: string;
  supplierId: string;
  inventoryId?: string | null;
  productName: string;
  quantity: number;
  unit: string;
  unitPrice?: number | null;
  paymentStatus?: string;
  totalAmount: number;
  status: OrderStatus;
  deliveryAddress: string | null;
  deliveryOtp: string | null;
  createdAt: string;
}

export type OrderStatus =
  | 'pending'
  | 'accepted'
  | 'out_for_delivery'
  | 'in_transit'
  | 'delivered'
  | 'cancelled';

export interface NotificationItem {
  id: string;
  userId: string;
  title: string;
  subtitle: string;
  type: string;
  isRead: boolean;
  createdAt: string;
}

// ----- Request payloads -----

export interface CreateStockPayload {
  masterProductId?: string;
  customProductName: string;
  category: string;
  quantity: number;
  unit: string;
  pricePerUnit: number;
  imageUrl?: string;
  deliveryRadiusKm?: number;
}

export interface HomeStatsResponse {
  newDemandsCount: number;
  pendingOrdersCount: number;
  stockItemsCount: number;
  nearbyDemands: NearbyDemand[];
}

export interface AcceptDemandResponse {
  order: OrderItem;
  demandId: string;
  message: string;
}

// Returned to the supplier when they confirm the order for delivery.
// The OTP itself is NOT in this response — it is delivered to the
// shop owner via a notification.
export interface ConfirmDeliveryResponse {
  orderId: string;
  status: OrderStatus;
  message: string;
}