// ============================================
// KopiPOS — Shared Types
// ============================================

export type UserRole = "owner" | "cashier" | "barista";

export type OrderStatus =
  "draft" | "confirmed" | "preparing" | "ready" | "completed" | "cancelled" | "void" | "refund";

export type TableStatus = "available" | "occupied" | "waiting_payment";

export type PaymentMethod = "cash" | "qris" | "debit" | "credit" | "ewallet" | "transfer";

export type AuditAction =
  | "login"
  | "logout"
  | "create"
  | "update"
  | "delete"
  | "void"
  | "refund"
  | "discount"
  | "payment"
  | "stock_adjustment"
  | "stock_opname"
  | "shift_open"
  | "shift_close"
  | "import"
  | "export";

export interface Profile {
  id: string;
  full_name: string | null;
  pin_code: string | null;
  role: UserRole;
  outlet_id: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Role {
  id: string;
  name: UserRole;
  display_name: string;
  created_at: string;
}

export interface Permission {
  id: string;
  key: string;
  description: string | null;
  created_at: string;
}

export interface Outlet {
  id: string;
  name: string;
  address: string | null;
  phone: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Category {
  id: string;
  name: string;
  description: string | null;
  sort_order: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Product {
  id: string;
  category_id: string | null;
  name: string;
  sku: string | null;
  barcode: string | null;
  description: string | null;
  image_url: string | null;
  cost_price: number;
  selling_price: number;
  taxable: boolean;
  track_inventory: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface AuditLog {
  id: string;
  actor_id: string | null;
  actor_name: string | null;
  action: AuditAction;
  entity_type: string | null;
  entity_id: string | null;
  detail: Record<string, unknown> | null;
  reason: string | null;
  approved_by: string | null;
  ip_address: string | null;
  created_at: string;
}

export interface ApiResponse<T> {
  data: T | null;
  error: string | null;
}

// ============================================
// Sprint 4: Modifiers + Orders
// ============================================

export interface Modifier {
  id: string;
  product_id: string;
  name: string;
  required: boolean;
  max_selections: number;
  sort_order: number;
  created_at: string;
  updated_at: string;
}

export interface ModifierOption {
  id: string;
  modifier_id: string;
  name: string;
  price_adjustment: number;
  is_default: boolean;
  sort_order: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface ModifierWithOptions extends Modifier {
  modifier_options: ModifierOption[];
}

export interface Order {
  id: string;
  invoice_number: string | null;
  order_type: "dine_in" | "takeaway";
  table_id: string | null;
  customer_id: string | null;
  cashier_id: string | null;
  outlet_id: string | null;
  status: OrderStatus;
  subtotal: number;
  discount: number;
  discount_type: string | null;
  coupon_id: string | null;
  promo_id: string | null;
  tax: number;
  service_charge: number;
  total: number;
  notes: string | null;
  created_at: string;
  updated_at: string | null;
  completed_at: string | null;
}

export interface OrderItem {
  id: string;
  order_id: string;
  product_id: string;
  product_name: string;
  variant_id: string | null;
  quantity: number;
  unit_price: number;
  modifier_total: number;
  discount: number;
  subtotal: number;
  notes: string | null;
  status: string;
  created_at: string;
  // Joined data
  product?: Product;
  order_item_modifiers?: OrderItemModifier[];
}

export interface OrderItemModifier {
  id: string;
  order_item_id: string;
  modifier_option_id: string;
  price_adjustment: number;
  // Joined
  modifier_option?: ModifierOption;
}

// Cart-specific types (not persisted directly, used in store)
export interface CartItemModifier {
  option_id: string;
  option_name: string;
  price_adjustment: number;
}

export interface CartItem {
  product_id: string;
  product_name: string;
  product_price: number;
  image_url: string | null;
  quantity: number;
  unit_price: number;
  modifiers: CartItemModifier[];
  modifier_total: number;
  notes: string;
  subtotal: number;
}

// ============================================
// Sprint 8: Shifts + Cash Movements + Refunds
// ============================================

export type ShiftStatus = "open" | "closed";
export type CashMovementType = "cash_sale" | "cash_in" | "cash_out" | "refund";

export interface Shift {
  id: string;
  outlet_id: string;
  cashier_id: string;
  status: ShiftStatus;
  opening_cash: number;
  closing_cash: number | null;
  expected_cash: number | null;
  difference: number | null;
  opened_at: string;
  closed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface CashMovement {
  id: string;
  shift_id: string;
  type: CashMovementType;
  amount: number;
  reference: string | null;
  description: string | null;
  created_at: string;
}

export interface Refund {
  id: string;
  order_id: string;
  amount: number;
  reason: string;
  approved_by: string | null;
  created_by: string | null;
  created_at: string;
}

// ============================================
// Sprint 9: Purchasing + Inventory + Expense + Waste
// ============================================

export type POStatus =
  "draft" | "approved" | "ordered" | "partially_received" | "completed" | "cancelled";
export type InventoryMovementType = "purchase" | "waste" | "opname" | "adjustment" | "sale";

export interface Supplier {
  id: string;
  name: string;
  contact_person: string | null;
  phone: string | null;
  email: string | null;
  address: string | null;
  payment_terms: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface PurchaseOrder {
  id: string;
  supplier_id: string;
  order_number: string;
  status: POStatus;
  expected_date: string | null;
  notes: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  // Joined
  supplier?: Supplier;
  items?: PurchaseOrderItem[];
}

export interface PurchaseOrderItem {
  id: string;
  po_id: string;
  product_id: string;
  expected_qty: number;
  received_qty: number;
  unit_cost: number;
  subtotal: number;
  created_at: string;
  product?: Product;
}

export interface Inventory {
  id: string;
  product_id: string;
  outlet_id: string;
  qty: number;
  updated_at: string;
}

export interface InventoryMovement {
  id: string;
  product_id: string;
  outlet_id: string;
  type: InventoryMovementType;
  qty: number;
  reference_type: string | null;
  reference_id: string | null;
  notes: string | null;
  created_by: string | null;
  created_at: string;
}

export interface WasteRecord {
  id: string;
  product_id: string;
  outlet_id: string;
  qty: number;
  reason: string;
  created_by: string | null;
  created_at: string;
  product?: Product;
}

export interface Expense {
  id: string;
  category: string;
  amount: number;
  description: string | null;
  date: string;
  attachment_url: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface StockOpname {
  id: string;
  outlet_id: string;
  status: string;
  notes: string | null;
  created_by: string | null;
  created_at: string;
  confirmed_at: string | null;
}

export interface StockOpnameItem {
  id: string;
  opname_id: string;
  product_id: string;
  system_qty: number;
  actual_qty: number;
  difference: number;
  product?: Product;
}

// Sprint 7: Ingredients + Recipe
export type IngredientUnit = "g" | "kg" | "ml" | "L" | "pcs" | "pack";

export interface Ingredient {
  id: string;
  name: string;
  sku: string;
  barcode: string | null;
  unit: IngredientUnit;
  stock: number;
  minimum_stock: number;
  cost: number;
  supplier_id: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Recipe {
  id: string;
  product_id: string;
  name: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  product?: Product;
  recipe_items?: RecipeItem[];
}

export interface RecipeItem {
  id: string;
  recipe_id: string;
  ingredient_id: string;
  qty: number;
  created_at: string;
  ingredient?: Ingredient;
}

export interface IngredientMovement {
  id: string;
  ingredient_id: string;
  outlet_id: string;
  type: string;
  qty: number;
  reference_type: string | null;
  reference_id: string | null;
  notes: string | null;
  created_by: string | null;
  created_at: string;
  ingredient?: Ingredient;
}

// Sprint 10: Customer + Loyalty + Promo
export interface Customer {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  birthday: string | null;
  points: number;
  total_spending: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface LoyaltySettings {
  id: string;
  outlet_id: string;
  points_per_rupiah: number;
  redeem_value_per_point: number;
  min_points_redeem: number;
  expiry_months: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface LoyaltyTransaction {
  id: string;
  customer_id: string;
  order_id: string | null;
  type: "earn" | "redeem" | "expire" | "adjustment";
  points: number;
  description: string | null;
  created_by: string | null;
  created_at: string;
  customer?: Customer;
}

export interface Promo {
  id: string;
  name: string;
  type: "percentage" | "fixed" | "coupon" | "bogo" | "bundle" | "member_discount";
  discount_value: number;
  minimum_purchase: number;
  maximum_discount: number | null;
  start_date: string | null;
  end_date: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Coupon {
  id: string;
  promo_id: string;
  code: string;
  usage_limit: number | null;
  used_count: number;
  min_purchase: number;
  max_discount: number | null;
  start_date: string | null;
  end_date: string | null;
  customer_eligibility: "all" | "member" | "new";
  is_active: boolean;
  created_at: string;
  promo?: Promo;
}
