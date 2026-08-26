-- ============================================
-- KopiPOS — FULL DATABASE SETUP
-- Paste this ENTIRE file into Supabase Dashboard > SQL Editor > Run
-- ============================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- ENUMS
-- ============================================

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('owner', 'cashier', 'barista');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE order_status AS ENUM (
    'draft', 'confirmed', 'preparing', 'ready', 'completed', 'cancelled', 'void', 'refund'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE table_status AS ENUM ('available', 'occupied', 'waiting_payment');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE payment_method AS ENUM ('cash', 'qris', 'debit', 'credit', 'ewallet', 'transfer');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE audit_action AS ENUM (
    'login', 'logout', 'create', 'update', 'delete',
    'void', 'refund', 'discount', 'payment',
    'stock_adjustment', 'stock_opname',
    'shift_open', 'shift_close',
    'import', 'export'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE shift_status AS ENUM ('open', 'closed');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE cash_movement_type AS ENUM ('cash_sale', 'cash_in', 'cash_out', 'refund');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE po_status AS ENUM (
    'draft', 'approved', 'ordered', 'partially_received', 'completed', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE inventory_movement_type AS ENUM (
    'purchase', 'waste', 'opname', 'adjustment', 'sale'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================
-- TABLES
-- ============================================

-- Roles (seeded, not editable)
CREATE TABLE IF NOT EXISTS roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name user_role NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Permissions
CREATE TABLE IF NOT EXISTS permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Role ↔ Permission mapping
CREATE TABLE IF NOT EXISTS role_permissions (
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

-- Outlets (must exist before profiles)
CREATE TABLE IF NOT EXISTS outlets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Profiles (extends auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  pin_code TEXT,
  role user_role NOT NULL DEFAULT 'cashier',
  outlet_id UUID,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- FK from profiles to outlets
DO $$ BEGIN
  ALTER TABLE profiles ADD CONSTRAINT fk_profiles_outlet
    FOREIGN KEY (outlet_id) REFERENCES outlets(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Tables (POS table management)
CREATE TABLE IF NOT EXISTS tables (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  number TEXT NOT NULL,
  capacity INTEGER DEFAULT 4,
  status table_status NOT NULL DEFAULT 'available',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(outlet_id, number)
);

-- Categories
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Products
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  sku TEXT UNIQUE,
  barcode TEXT UNIQUE,
  description TEXT,
  image_url TEXT,
  cost_price NUMERIC(12,2) DEFAULT 0,
  selling_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  taxable BOOLEAN DEFAULT true,
  track_inventory BOOLEAN DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Orders (was MISSING from migrations!)
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id) ON DELETE SET NULL,
  table_id UUID REFERENCES tables(id) ON DELETE SET NULL,
  cashier_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  order_type TEXT, -- 'dine_in', 'takeaway'
  status order_status NOT NULL DEFAULT 'draft',
  invoice_number TEXT,
  subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
  discount NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax NUMERIC(12,2) NOT NULL DEFAULT 0,
  service_charge NUMERIC(12,2) NOT NULL DEFAULT 0,
  total NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

-- Order Items (was MISSING from migrations!)
CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC(12,2) NOT NULL DEFAULT 0,
  modifier_total NUMERIC(12,2) NOT NULL DEFAULT 0,
  subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Audit Logs
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  actor_name TEXT,
  action audit_action NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  detail JSONB,
  reason TEXT,
  approved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Modifiers
CREATE TABLE IF NOT EXISTS modifiers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  required BOOLEAN DEFAULT false,
  max_selections INTEGER DEFAULT 1,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS modifier_options (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  modifier_id UUID NOT NULL REFERENCES modifiers(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price_adjustment NUMERIC(12,2) DEFAULT 0,
  is_default BOOLEAN DEFAULT false,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS order_item_modifiers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_item_id UUID NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
  modifier_option_id UUID NOT NULL REFERENCES modifier_options(id) ON DELETE RESTRICT,
  price_adjustment NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Payments
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  method payment_method NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  reference_number TEXT,
  status TEXT NOT NULL DEFAULT 'completed',
  paid_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Shifts
CREATE TABLE IF NOT EXISTS shifts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  cashier_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status shift_status NOT NULL DEFAULT 'open',
  opening_cash NUMERIC(12,2) NOT NULL DEFAULT 0,
  closing_cash NUMERIC(12,2),
  expected_cash NUMERIC(12,2),
  difference NUMERIC(12,2),
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Cash Movements
CREATE TABLE IF NOT EXISTS cash_movements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
  type cash_movement_type NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  reference TEXT,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Refunds
CREATE TABLE IF NOT EXISTS refunds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL,
  reason TEXT NOT NULL,
  approved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Suppliers
CREATE TABLE IF NOT EXISTS suppliers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  payment_terms TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Purchase Orders
CREATE TABLE IF NOT EXISTS purchase_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  order_number TEXT NOT NULL UNIQUE,
  status po_status NOT NULL DEFAULT 'draft',
  expected_date DATE,
  notes TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS purchase_order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  po_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  expected_qty NUMERIC(10,2) NOT NULL DEFAULT 0,
  received_qty NUMERIC(10,2) NOT NULL DEFAULT 0,
  unit_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
  subtotal NUMERIC(12,2) GENERATED ALWAYS AS (expected_qty * unit_cost) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Inventory
CREATE TABLE IF NOT EXISTS inventory (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  qty NUMERIC(10,2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(product_id, outlet_id)
);

-- Inventory Movements
CREATE TABLE IF NOT EXISTS inventory_movements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  type inventory_movement_type NOT NULL,
  qty NUMERIC(10,2) NOT NULL,
  reference_type TEXT,
  reference_id UUID,
  notes TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Waste Records
CREATE TABLE IF NOT EXISTS waste_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  qty NUMERIC(10,2) NOT NULL,
  reason TEXT NOT NULL,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Expenses
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  description TEXT,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  attachment_url TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Stock Opnames
CREATE TABLE IF NOT EXISTS stock_opnames (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  status TEXT NOT NULL DEFAULT 'draft',
  notes TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS stock_opname_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  opname_id UUID NOT NULL REFERENCES stock_opnames(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  system_qty NUMERIC(10,2) NOT NULL,
  actual_qty NUMERIC(10,2) NOT NULL DEFAULT 0,
  difference NUMERIC(10,2) GENERATED ALWAYS AS (actual_qty - system_qty) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_outlet ON profiles(outlet_id);
CREATE INDEX IF NOT EXISTS idx_profiles_pin ON profiles(pin_code) WHERE pin_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_tables_outlet ON tables(outlet_id);
CREATE INDEX IF NOT EXISTS idx_modifiers_product ON modifiers(product_id);
CREATE INDEX IF NOT EXISTS idx_modifier_options_modifier ON modifier_options(modifier_id);
CREATE INDEX IF NOT EXISTS idx_order_item_modifiers_item ON order_item_modifiers(order_item_id);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_method ON payments(method);
CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON payments(paid_at);
CREATE INDEX IF NOT EXISTS idx_shifts_outlet ON shifts(outlet_id);
CREATE INDEX IF NOT EXISTS idx_shifts_cashier ON shifts(cashier_id);
CREATE INDEX IF NOT EXISTS idx_shifts_status ON shifts(status);
CREATE INDEX IF NOT EXISTS idx_shifts_opened ON shifts(opened_at);
CREATE INDEX IF NOT EXISTS idx_cash_movements_shift ON cash_movements(shift_id);
CREATE INDEX IF NOT EXISTS idx_cash_movements_type ON cash_movements(type);
CREATE INDEX IF NOT EXISTS idx_cash_movements_created ON cash_movements(created_at);
CREATE INDEX IF NOT EXISTS idx_refunds_order ON refunds(order_id);
CREATE INDEX IF NOT EXISTS idx_refunds_created ON refunds(created_at);
CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name);
CREATE INDEX IF NOT EXISTS idx_po_supplier ON purchase_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_po_status ON purchase_orders(status);
CREATE INDEX IF NOT EXISTS idx_po_items_po ON purchase_order_items(po_id);
CREATE INDEX IF NOT EXISTS idx_po_items_product ON purchase_order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_product ON inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_outlet ON inventory(outlet_id);
CREATE INDEX IF NOT EXISTS idx_inv_mov_product ON inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_inv_mov_type ON inventory_movements(type);
CREATE INDEX IF NOT EXISTS idx_inv_mov_ref ON inventory_movements(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_inv_mov_created ON inventory_movements(created_at);
CREATE INDEX IF NOT EXISTS idx_waste_product ON waste_records(product_id);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date);

-- ============================================
-- UPDATED_AT TRIGGER
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers only if they don't exist
DO $$ BEGIN
  CREATE TRIGGER trigger_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER trigger_outlets_updated_at BEFORE UPDATE ON outlets FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER trigger_tables_updated_at BEFORE UPDATE ON tables FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER trigger_categories_updated_at BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER trigger_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER trigger_orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER trigger_modifiers_updated_at BEFORE UPDATE ON modifiers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER trigger_modifier_options_updated_at BEFORE UPDATE ON modifier_options FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER trigger_shifts_updated_at BEFORE UPDATE ON shifts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER trigger_suppliers_updated_at BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER trigger_purchase_orders_updated_at BEFORE UPDATE ON purchase_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TRIGGER trigger_expenses_updated_at BEFORE UPDATE ON expenses FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================
-- RLS - Enable on all tables
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE outlets ENABLE ROW LEVEL SECURITY;
ALTER TABLE tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE modifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE modifier_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_item_modifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE waste_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_opnames ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_opname_items ENABLE ROW LEVEL SECURITY;

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION auth.has_permission(p_permission_key TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM role_permissions rp
    JOIN permissions p ON p.id = rp.permission_id
    JOIN profiles pr ON pr.role = (SELECT name FROM roles WHERE id = rp.role_id)
    WHERE pr.id = auth.uid()
    AND p.key = p_permission_key
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Check if owner exists (for setup flow)
CREATE OR REPLACE FUNCTION has_owner()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE role = 'owner');
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Log audit event
CREATE OR REPLACE FUNCTION log_audit_event(
  p_actor_id UUID,
  p_actor_name TEXT,
  p_action audit_action,
  p_entity_type TEXT DEFAULT NULL,
  p_entity_id UUID DEFAULT NULL,
  p_detail JSONB DEFAULT NULL,
  p_reason TEXT DEFAULT NULL,
  p_approved_by UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO audit_logs (actor_id, actor_name, action, entity_type, entity_id, detail, reason, approved_by)
  VALUES (p_actor_id, p_actor_name, p_action, p_entity_type, p_entity_id, p_detail, p_reason, p_approved_by)
  RETURNING id INTO v_log_id;
  RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RLS POLICIES
-- ============================================

-- Profiles
DO $$ BEGIN CREATE POLICY "profiles_select_own" ON profiles FOR SELECT USING (id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "profiles_select_owner" ON profiles FOR SELECT USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "profiles_update_owner" ON profiles FOR UPDATE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (id = auth.uid()); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "profiles_insert_owner" ON profiles FOR INSERT WITH CHECK (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "profiles_insert_auth" ON profiles FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Roles, Permissions, Role_Permissions
DO $$ BEGIN CREATE POLICY "roles_select_all" ON roles FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "permissions_select_all" ON permissions FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "role_permissions_select_all" ON role_permissions FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Outlets
DO $$ BEGIN CREATE POLICY "outlets_select_all" ON outlets FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "outlets_insert_owner" ON outlets FOR INSERT WITH CHECK (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "outlets_update_owner" ON outlets FOR UPDATE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "outlets_delete_owner" ON outlets FOR DELETE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Tables
DO $$ BEGIN CREATE POLICY "tables_select_all" ON tables FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "tables_insert_owner_cashier" ON tables FOR INSERT WITH CHECK (auth.user_role() IN ('owner', 'cashier')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "tables_update_owner_cashier" ON tables FOR UPDATE USING (auth.user_role() IN ('owner', 'cashier')); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "tables_delete_owner" ON tables FOR DELETE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Categories
DO $$ BEGIN CREATE POLICY "categories_select_all" ON categories FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "categories_insert_owner" ON categories FOR INSERT WITH CHECK (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "categories_update_owner" ON categories FOR UPDATE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "categories_delete_owner" ON categories FOR DELETE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Products
DO $$ BEGIN CREATE POLICY "products_select_all" ON products FOR SELECT USING (is_active = true OR auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "products_insert_owner" ON products FOR INSERT WITH CHECK (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "products_update_owner" ON products FOR UPDATE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "products_delete_owner" ON products FOR DELETE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Orders
DO $$ BEGIN CREATE POLICY "orders_select_auth" ON orders FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "orders_insert_auth" ON orders FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "orders_update_auth" ON orders FOR UPDATE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Order Items
DO $$ BEGIN CREATE POLICY "order_items_select_auth" ON order_items FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "order_items_insert_auth" ON order_items FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "order_items_update_auth" ON order_items FOR UPDATE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "order_items_delete_auth" ON order_items FOR DELETE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Audit Logs
DO $$ BEGIN CREATE POLICY "audit_logs_select_owner" ON audit_logs FOR SELECT USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "audit_logs_insert_system" ON audit_logs FOR INSERT WITH CHECK (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "audit_logs_no_update" ON audit_logs FOR UPDATE USING (false); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "audit_logs_no_delete" ON audit_logs FOR DELETE USING (false); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Modifiers
DO $$ BEGIN CREATE POLICY "modifiers_select_all" ON modifiers FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "modifiers_insert_owner" ON modifiers FOR INSERT WITH CHECK (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "modifiers_update_owner" ON modifiers FOR UPDATE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "modifiers_delete_owner" ON modifiers FOR DELETE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Modifier Options
DO $$ BEGIN CREATE POLICY "modifier_options_select_all" ON modifier_options FOR SELECT USING (true); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "modifier_options_insert_owner" ON modifier_options FOR INSERT WITH CHECK (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "modifier_options_update_owner" ON modifier_options FOR UPDATE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "modifier_options_delete_owner" ON modifier_options FOR DELETE USING (auth.user_role() = 'owner'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Order Item Modifiers
DO $$ BEGIN CREATE POLICY "order_item_modifiers_select_auth" ON order_item_modifiers FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "order_item_modifiers_insert_auth" ON order_item_modifiers FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "order_item_modifiers_delete_auth" ON order_item_modifiers FOR DELETE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Payments
DO $$ BEGIN CREATE POLICY "payments_select_auth" ON payments FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "payments_insert_auth" ON payments FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Shifts
DO $$ BEGIN CREATE POLICY "shifts_select_auth" ON shifts FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "shifts_insert_auth" ON shifts FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "shifts_update_auth" ON shifts FOR UPDATE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Cash Movements
DO $$ BEGIN CREATE POLICY "cash_movements_select_auth" ON cash_movements FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "cash_movements_insert_auth" ON cash_movements FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Refunds
DO $$ BEGIN CREATE POLICY "refunds_select_auth" ON refunds FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "refunds_insert_auth" ON refunds FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Suppliers
DO $$ BEGIN CREATE POLICY "suppliers_select_auth" ON suppliers FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "suppliers_insert_auth" ON suppliers FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "suppliers_update_auth" ON suppliers FOR UPDATE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "suppliers_delete_auth" ON suppliers FOR DELETE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Purchase Orders
DO $$ BEGIN CREATE POLICY "po_select_auth" ON purchase_orders FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "po_insert_auth" ON purchase_orders FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "po_update_auth" ON purchase_orders FOR UPDATE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Purchase Order Items
DO $$ BEGIN CREATE POLICY "po_items_select_auth" ON purchase_order_items FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "po_items_insert_auth" ON purchase_order_items FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "po_items_update_auth" ON purchase_order_items FOR UPDATE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Inventory
DO $$ BEGIN CREATE POLICY "inventory_select_auth" ON inventory FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "inventory_insert_auth" ON inventory FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "inventory_update_auth" ON inventory FOR UPDATE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Inventory Movements
DO $$ BEGIN CREATE POLICY "inv_mov_select_auth" ON inventory_movements FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "inv_mov_insert_auth" ON inventory_movements FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Waste Records
DO $$ BEGIN CREATE POLICY "waste_select_auth" ON waste_records FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "waste_insert_auth" ON waste_records FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Expenses
DO $$ BEGIN CREATE POLICY "expenses_select_auth" ON expenses FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "expenses_insert_auth" ON expenses FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "expenses_update_auth" ON expenses FOR UPDATE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "expenses_delete_auth" ON expenses FOR DELETE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Stock Opnames
DO $$ BEGIN CREATE POLICY "opname_select_auth" ON stock_opnames FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "opname_insert_auth" ON stock_opnames FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "opname_update_auth" ON stock_opnames FOR UPDATE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Stock Opname Items
DO $$ BEGIN CREATE POLICY "opname_items_select_auth" ON stock_opname_items FOR SELECT USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "opname_items_insert_auth" ON stock_opname_items FOR INSERT WITH CHECK (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "opname_items_update_auth" ON stock_opname_items FOR UPDATE USING (auth.role() = 'authenticated'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================
-- RPC FUNCTIONS
-- ============================================

-- Invoice number generator
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS TEXT AS $$
DECLARE
  today TEXT;
  seq INT;
BEGIN
  today := to_char(now(), 'YYYYMMDD');
  SELECT COALESCE(MAX(CAST(SUBSTRING(invoice_number FROM 14 FOR 5) AS INT)), 0) + 1 INTO seq
  FROM orders WHERE invoice_number LIKE 'INV-' || today || '-%';
  RETURN 'INV-' || today || '-' || LPAD(seq::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- Confirm order
CREATE OR REPLACE FUNCTION confirm_order(p_order_id UUID, p_table_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_order RECORD; v_invoice TEXT;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF v_order IS NULL THEN RETURN jsonb_build_object('error', 'Order not found'); END IF;
  IF v_order.status != 'draft' THEN RETURN jsonb_build_object('error', 'Order must be in draft status'); END IF;
  v_invoice := generate_invoice_number();
  UPDATE orders SET status = 'confirmed', invoice_number = v_invoice, table_id = COALESCE(p_table_id, table_id), updated_at = now() WHERE id = p_order_id;
  IF p_table_id IS NOT NULL THEN UPDATE tables SET status = 'occupied', updated_at = now() WHERE id = p_table_id; END IF;
  PERFORM log_audit_event(NULL, 'system', 'payment', 'order', p_order_id, jsonb_build_object('action', 'confirm', 'invoice', v_invoice));
  RETURN jsonb_build_object('success', true, 'invoice_number', v_invoice, 'status', 'confirmed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cancel order
CREATE OR REPLACE FUNCTION cancel_order(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE v_order RECORD;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF v_order IS NULL THEN RETURN jsonb_build_object('error', 'Order not found'); END IF;
  IF v_order.status != 'draft' THEN RETURN jsonb_build_object('error', 'Only draft orders can be cancelled'); END IF;
  UPDATE orders SET status = 'cancelled', updated_at = now() WHERE id = p_order_id;
  IF v_order.table_id IS NOT NULL THEN UPDATE tables SET status = 'available', updated_at = now() WHERE id = v_order.table_id; END IF;
  RETURN jsonb_build_object('success', true, 'status', 'cancelled');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Complete order
CREATE OR REPLACE FUNCTION complete_order(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE v_order RECORD; v_shift_id UUID;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF v_order IS NULL THEN RETURN jsonb_build_object('error', 'Order not found'); END IF;
  IF v_order.status NOT IN ('ready', 'completed') THEN RETURN jsonb_build_object('error', 'Order must be ready or completed'); END IF;
  UPDATE orders SET status = 'completed', completed_at = now(), updated_at = now() WHERE id = p_order_id;
  IF v_order.table_id IS NOT NULL THEN UPDATE tables SET status = 'available', updated_at = now() WHERE id = v_order.table_id; END IF;
  IF v_order.order_type IS NOT NULL THEN
    SELECT id INTO v_shift_id FROM shifts WHERE cashier_id = v_order.cashier_id AND status = 'open' LIMIT 1;
    IF v_shift_id IS NOT NULL THEN PERFORM record_cash_movement(v_shift_id, 'cash_sale', v_order.total, p_order_id::TEXT); END IF;
  END IF;
  PERFORM log_audit_event(NULL, 'system', 'payment', 'order', p_order_id, jsonb_build_object('action', 'complete'));
  RETURN jsonb_build_object('success', true, 'status', 'completed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Void order
CREATE OR REPLACE FUNCTION void_order(p_order_id UUID, p_reason TEXT, p_approved_by UUID)
RETURNS JSONB AS $$
DECLARE v_order RECORD;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF v_order IS NULL THEN RETURN jsonb_build_object('error', 'Order not found'); END IF;
  IF v_order.status != 'confirmed' THEN RETURN jsonb_build_object('error', 'Only confirmed orders can be voided'); END IF;
  UPDATE orders SET status = 'void', updated_at = now() WHERE id = p_order_id;
  IF v_order.table_id IS NOT NULL THEN UPDATE tables SET status = 'available', updated_at = now() WHERE id = v_order.table_id; END IF;
  PERFORM log_audit_event(NULL, 'system', 'void', 'order', p_order_id, jsonb_build_object('reason', p_reason), p_reason, p_approved_by);
  RETURN jsonb_build_object('success', true, 'status', 'void');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Start preparing
CREATE OR REPLACE FUNCTION start_preparing(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE v_order RECORD;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF v_order IS NULL THEN RETURN jsonb_build_object('error', 'Order not found'); END IF;
  IF v_order.status != 'confirmed' THEN RETURN jsonb_build_object('error', 'Order must be confirmed first'); END IF;
  UPDATE orders SET status = 'preparing', updated_at = now() WHERE id = p_order_id;
  RETURN jsonb_build_object('success', true, 'status', 'preparing');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Mark ready
CREATE OR REPLACE FUNCTION mark_ready(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE v_order RECORD;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF v_order IS NULL THEN RETURN jsonb_build_object('error', 'Order not found'); END IF;
  IF v_order.status != 'preparing' THEN RETURN jsonb_build_object('error', 'Order must be preparing'); END IF;
  UPDATE orders SET status = 'ready', updated_at = now() WHERE id = p_order_id;
  RETURN jsonb_build_object('success', true, 'status', 'ready');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Refund order
CREATE OR REPLACE FUNCTION refund_order(p_order_id UUID, p_reason TEXT, p_approved_by UUID)
RETURNS JSONB AS $$
DECLARE v_order RECORD; v_refund_id UUID;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;
  IF v_order IS NULL THEN RETURN jsonb_build_object('error', 'Order not found'); END IF;
  IF v_order.status != 'completed' THEN RETURN jsonb_build_object('error', 'Only completed orders can be refunded'); END IF;
  INSERT INTO refunds (order_id, amount, reason, approved_by, created_by) VALUES (p_order_id, v_order.total, p_reason, p_approved_by, p_approved_by) RETURNING id INTO v_refund_id;
  UPDATE orders SET status = 'refund', updated_at = now() WHERE id = p_order_id;
  IF v_order.table_id IS NOT NULL THEN UPDATE tables SET status = 'available', updated_at = now() WHERE id = v_order.table_id; END IF;
  PERFORM log_audit_event(NULL, 'system', 'refund', 'order', p_order_id, jsonb_build_object('reason', p_reason, 'refund_id', v_refund_id, 'amount', v_order.total), p_reason, p_approved_by);
  RETURN jsonb_build_object('success', true, 'refund_id', v_refund_id, 'status', 'refund');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Transfer table
CREATE OR REPLACE FUNCTION transfer_table(p_from_table_id UUID, p_to_table_id UUID)
RETURNS JSONB AS $$
DECLARE v_target_status TEXT;
BEGIN
  SELECT status INTO v_target_status FROM tables WHERE id = p_to_table_id;
  IF v_target_status != 'available' THEN RETURN jsonb_build_object('error', 'Target table is not available'); END IF;
  UPDATE orders SET table_id = p_to_table_id, updated_at = now() WHERE table_id = p_from_table_id AND status IN ('confirmed', 'preparing');
  UPDATE tables SET status = 'available', updated_at = now() WHERE id = p_from_table_id;
  UPDATE tables SET status = 'occupied', updated_at = now() WHERE id = p_to_table_id;
  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Open shift
CREATE OR REPLACE FUNCTION open_shift(p_outlet_id UUID, p_cashier_id UUID, p_opening_cash NUMERIC(12,2))
RETURNS JSONB AS $$
DECLARE v_existing UUID;
BEGIN
  SELECT id INTO v_existing FROM shifts WHERE outlet_id = p_outlet_id AND cashier_id = p_cashier_id AND status = 'open' LIMIT 1;
  IF v_existing IS NOT NULL THEN RETURN jsonb_build_object('error', 'You already have an open shift'); END IF;
  INSERT INTO shifts (outlet_id, cashier_id, opening_cash, status) VALUES (p_outlet_id, p_cashier_id, p_opening_cash, 'open') RETURNING id INTO v_existing;
  PERFORM log_audit_event(p_cashier_id, NULL, 'shift_open', 'shift', v_existing, jsonb_build_object('opening_cash', p_opening_cash));
  RETURN jsonb_build_object('success', true, 'shift_id', v_existing);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Close shift
CREATE OR REPLACE FUNCTION close_shift(p_shift_id UUID, p_closing_cash NUMERIC(12,2))
RETURNS JSONB AS $$
DECLARE v_shift RECORD; v_expected NUMERIC(12,2); v_diff NUMERIC(12,2); v_pending INT;
BEGIN
  SELECT * INTO v_shift FROM shifts WHERE id = p_shift_id FOR UPDATE;
  IF v_shift IS NULL THEN RETURN jsonb_build_object('error', 'Shift not found'); END IF;
  IF v_shift.status != 'open' THEN RETURN jsonb_build_object('error', 'Shift is already closed'); END IF;
  SELECT COUNT(*) INTO v_pending FROM orders WHERE cashier_id = v_shift.cashier_id AND status IN ('confirmed', 'preparing', 'ready') AND created_at >= v_shift.opened_at;
  IF v_pending > 0 THEN RETURN jsonb_build_object('error', 'Cannot close shift: ' || v_pending || ' pending order(s)'); END IF;
  SELECT COALESCE(SUM(CASE type WHEN 'cash_sale' THEN amount WHEN 'cash_in' THEN amount WHEN 'cash_out' THEN -amount WHEN 'refund' THEN -amount ELSE 0 END), 0) INTO v_expected FROM cash_movements WHERE shift_id = p_shift_id;
  v_expected := v_shift.opening_cash + v_expected;
  v_diff := p_closing_cash - v_expected;
  UPDATE shifts SET status = 'closed', closing_cash = p_closing_cash, expected_cash = v_expected, difference = v_diff, closed_at = now() WHERE id = p_shift_id;
  PERFORM log_audit_event(v_shift.cashier_id, NULL, 'shift_close', 'shift', p_shift_id, jsonb_build_object('opening_cash', v_shift.opening_cash, 'closing_cash', p_closing_cash, 'expected_cash', v_expected, 'difference', v_diff));
  RETURN jsonb_build_object('success', true, 'expected_cash', v_expected, 'closing_cash', p_closing_cash, 'difference', v_diff);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Record cash movement
CREATE OR REPLACE FUNCTION record_cash_movement(p_shift_id UUID, p_type cash_movement_type, p_amount NUMERIC(12,2), p_reference TEXT DEFAULT NULL, p_description TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE v_id UUID;
BEGIN
  INSERT INTO cash_movements (shift_id, type, amount, reference, description) VALUES (p_shift_id, p_type, p_amount, p_reference, p_description) RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'movement_id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PO functions
CREATE OR REPLACE FUNCTION generate_po_number()
RETURNS TEXT AS $$
DECLARE today TEXT; seq INT;
BEGIN
  today := to_char(now(), 'YYYYMMDD');
  SELECT COALESCE(MAX(CAST(SUBSTRING(order_number FROM 6 FOR 5) AS INT)), 0) + 1 INTO seq FROM purchase_orders WHERE order_number LIKE 'PO-' || today || '-%';
  RETURN 'PO-' || today || '-' || LPAD(seq::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION approve_po(p_po_id UUID)
RETURNS JSONB AS $$
DECLARE v_po RECORD;
BEGIN
  SELECT * INTO v_po FROM purchase_orders WHERE id = p_po_id FOR UPDATE;
  IF v_po IS NULL THEN RETURN jsonb_build_object('error', 'PO not found'); END IF;
  IF v_po.status != 'draft' THEN RETURN jsonb_build_object('error', 'Only draft POs can be approved'); END IF;
  UPDATE purchase_orders SET status = 'approved', updated_at = now() WHERE id = p_po_id;
  RETURN jsonb_build_object('success', true, 'status', 'approved');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION order_po(p_po_id UUID)
RETURNS JSONB AS $$
DECLARE v_po RECORD;
BEGIN
  SELECT * INTO v_po FROM purchase_orders WHERE id = p_po_id FOR UPDATE;
  IF v_po IS NULL THEN RETURN jsonb_build_object('error', 'PO not found'); END IF;
  IF v_po.status != 'approved' THEN RETURN jsonb_build_object('error', 'Only approved POs can be ordered'); END IF;
  UPDATE purchase_orders SET status = 'ordered', updated_at = now() WHERE id = p_po_id;
  RETURN jsonb_build_object('success', true, 'status', 'ordered');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION receive_po(p_po_id UUID, p_product_id UUID, p_qty NUMERIC(10,2), p_outlet_id UUID)
RETURNS JSONB AS $$
DECLARE v_po RECORD; v_item RECORD; v_new_received NUMERIC(10,2); v_total_expected NUMERIC(10,2); v_total_received NUMERIC(10,2);
BEGIN
  SELECT * INTO v_po FROM purchase_orders WHERE id = p_po_id FOR UPDATE;
  IF v_po IS NULL THEN RETURN jsonb_build_object('error', 'PO not found'); END IF;
  IF v_po.status NOT IN ('ordered', 'partially_received') THEN RETURN jsonb_build_object('error', 'PO must be ordered or partially received'); END IF;
  SELECT * INTO v_item FROM purchase_order_items WHERE po_id = p_po_id AND product_id = p_product_id FOR UPDATE;
  IF v_item IS NULL THEN RETURN jsonb_build_object('error', 'Product not in this PO'); END IF;
  v_new_received := v_item.received_qty + p_qty;
  IF v_new_received > v_item.expected_qty THEN RETURN jsonb_build_object('error', 'Received qty exceeds expected qty'); END IF;
  UPDATE purchase_order_items SET received_qty = v_new_received WHERE id = v_item.id;
  INSERT INTO inventory (product_id, outlet_id, qty) VALUES (p_product_id, p_outlet_id, p_qty) ON CONFLICT (product_id, outlet_id) DO UPDATE SET qty = inventory.qty + p_qty, updated_at = now();
  INSERT INTO inventory_movements (product_id, outlet_id, type, qty, reference_type, reference_id, notes) VALUES (p_product_id, p_outlet_id, 'purchase', p_qty, 'goods_receipt', p_po_id, 'PO ' || v_po.order_number);
  SELECT SUM(expected_qty), SUM(received_qty) INTO v_total_expected, v_total_received FROM purchase_order_items WHERE po_id = p_po_id;
  IF v_total_received >= v_total_expected THEN UPDATE purchase_orders SET status = 'completed', updated_at = now() WHERE id = p_po_id;
  ELSE UPDATE purchase_orders SET status = 'partially_received', updated_at = now() WHERE id = p_po_id; END IF;
  RETURN jsonb_build_object('success', true, 'new_received', v_new_received);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Waste
CREATE OR REPLACE FUNCTION record_waste(p_product_id UUID, p_outlet_id UUID, p_qty NUMERIC(10,2), p_reason TEXT, p_created_by UUID)
RETURNS JSONB AS $$
DECLARE v_inv RECORD; v_waste_id UUID;
BEGIN
  SELECT * INTO v_inv FROM inventory WHERE product_id = p_product_id AND outlet_id = p_outlet_id FOR UPDATE;
  IF v_inv IS NULL OR v_inv.qty < p_qty THEN RETURN jsonb_build_object('error', 'Insufficient stock'); END IF;
  UPDATE inventory SET qty = qty - p_qty, updated_at = now() WHERE product_id = p_product_id AND outlet_id = p_outlet_id;
  INSERT INTO waste_records (product_id, outlet_id, qty, reason, created_by) VALUES (p_product_id, p_outlet_id, p_qty, p_reason, p_created_by) RETURNING id INTO v_waste_id;
  INSERT INTO inventory_movements (product_id, outlet_id, type, qty, reference_type, reference_id, notes, created_by) VALUES (p_product_id, p_outlet_id, 'waste', -p_qty, 'waste', v_waste_id, p_reason, p_created_by);
  RETURN jsonb_build_object('success', true, 'waste_id', v_waste_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Stock opname confirm
CREATE OR REPLACE FUNCTION confirm_stock_opname(p_opname_id UUID)
RETURNS JSONB AS $$
DECLARE v_opname RECORD; v_item RECORD;
BEGIN
  SELECT * INTO v_opname FROM stock_opnames WHERE id = p_opname_id FOR UPDATE;
  IF v_opname IS NULL THEN RETURN jsonb_build_object('error', 'Opname not found'); END IF;
  IF v_opname.status != 'draft' THEN RETURN jsonb_build_object('error', 'Opname already confirmed'); END IF;
  FOR v_item IN SELECT * FROM stock_opname_items WHERE opname_id = p_opname_id LOOP
    IF v_item.difference != 0 THEN
      INSERT INTO inventory (product_id, outlet_id, qty) VALUES (v_item.product_id, v_opname.outlet_id, v_item.difference) ON CONFLICT (product_id, outlet_id) DO UPDATE SET qty = inventory.qty + v_item.difference, updated_at = now();
      INSERT INTO inventory_movements (product_id, outlet_id, type, qty, reference_type, reference_id, notes) VALUES (v_item.product_id, v_opname.outlet_id, 'opname', v_item.difference, 'opname', p_opname_id, 'Stock opname: ' || v_item.system_qty || ' -> ' || v_item.actual_qty);
    END IF;
  END LOOP;
  UPDATE stock_opnames SET status = 'confirmed', confirmed_at = now() WHERE id = p_opname_id;
  RETURN jsonb_build_object('success', true, 'status', 'confirmed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- SEED DATA
-- ============================================

INSERT INTO roles (name, display_name) VALUES ('owner', 'Owner/Admin'), ('cashier', 'Cashier'), ('barista', 'Barista/Kitchen')
ON CONFLICT (name) DO NOTHING;

INSERT INTO permissions (key, description) VALUES
  ('pos.use', 'Access POS'), ('orders.view', 'View orders'), ('orders.create', 'Create orders'),
  ('products.view', 'View products'), ('products.manage', 'Manage products'), ('categories.manage', 'Manage categories'),
  ('inventory.view', 'View inventory'), ('inventory.manage', 'Manage inventory'), ('tables.manage', 'Manage tables'),
  ('payments.process', 'Process payments'), ('shifts.view', 'View shifts'), ('shifts.manage', 'Manage shifts'),
  ('reports.view', 'View reports'), ('users.manage', 'Manage users'), ('audit.view', 'View audit logs'),
  ('purchasing.manage', 'Manage purchasing'), ('suppliers.manage', 'Manage suppliers')
ON CONFLICT (key) DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p WHERE r.name = 'owner'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p WHERE r.name = 'cashier'
AND p.key IN ('pos.use', 'orders.view', 'orders.create', 'products.view', 'payments.process', 'shifts.view', 'reports.view')
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p WHERE r.name = 'barista'
AND p.key IN ('orders.view', 'products.view')
ON CONFLICT DO NOTHING;

INSERT INTO outlets (name, address) VALUES ('Main Store', 'Jl. Kopi No. 1')
ON CONFLICT DO NOTHING;

-- Seed tables
INSERT INTO tables (outlet_id, number, capacity, status)
SELECT id, 'A01', 4, 'available' FROM outlets WHERE name = 'Main Store' ON CONFLICT DO NOTHING;
INSERT INTO tables (outlet_id, number, capacity, status)
SELECT id, 'A02', 4, 'available' FROM outlets WHERE name = 'Main Store' ON CONFLICT DO NOTHING;
INSERT INTO tables (outlet_id, number, capacity, status)
SELECT id, 'A03', 2, 'available' FROM outlets WHERE name = 'Main Store' ON CONFLICT DO NOTHING;
INSERT INTO tables (outlet_id, number, capacity, status)
SELECT id, 'B01', 6, 'available' FROM outlets WHERE name = 'Main Store' ON CONFLICT DO NOTHING;
INSERT INTO tables (outlet_id, number, capacity, status)
SELECT id, 'B02', 8, 'available' FROM outlets WHERE name = 'Main Store' ON CONFLICT DO NOTHING;

-- ============================================
-- STORAGE BUCKET
-- ============================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('product-images', 'product-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'])
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- SEED OWNER ACCOUNT (bypass email rate limit)
-- ============================================

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'admin@kopipos.com',
  crypt('admin123', gen_salt('bf')),
  now(), now(), now(),
  '', '', '', ''
) ON CONFLICT DO NOTHING;

INSERT INTO profiles (id, full_name, role, is_active)
SELECT id, 'Admin', 'owner', true
FROM auth.users WHERE email = 'admin@kopipos.com'
ON CONFLICT DO NOTHING;

-- Done!
