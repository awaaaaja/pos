-- ============================================
-- KopiPOS — Sprint 2: Database Foundation + Auth + RBAC
-- Migration: 20240101000000_initial_schema.sql
-- ============================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE user_role AS ENUM ('owner', 'cashier', 'barista');

CREATE TYPE order_status AS ENUM (
  'draft', 'confirmed', 'preparing', 'ready', 'completed', 'cancelled', 'void', 'refund'
);

CREATE TYPE table_status AS ENUM ('available', 'occupied', 'waiting_payment');

CREATE TYPE payment_method AS ENUM ('cash', 'qris', 'debit', 'credit', 'ewallet', 'transfer');

CREATE TYPE audit_action AS ENUM (
  'login', 'logout', 'create', 'update', 'delete',
  'void', 'refund', 'discount', 'payment',
  'stock_adjustment', 'stock_opname',
  'shift_open', 'shift_close',
  'import', 'export'
);

-- ============================================
-- TABLES
-- ============================================

-- Roles (seeded, not editable)
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name user_role NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Permissions
CREATE TABLE permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Role ↔ Permission mapping
CREATE TABLE role_permissions (
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

-- Profiles (extends auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  pin_code TEXT, -- hashed PIN for cashier/barista login
  role user_role NOT NULL DEFAULT 'cashier',
  outlet_id UUID, -- FK added after outlets table
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Outlets
CREATE TABLE outlets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add FK from profiles to outlets
ALTER TABLE profiles ADD CONSTRAINT fk_profiles_outlet
  FOREIGN KEY (outlet_id) REFERENCES outlets(id) ON DELETE SET NULL;

-- Tables (POS table management)
CREATE TABLE tables (
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
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Products
CREATE TABLE products (
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

-- Audit Logs
CREATE TABLE audit_logs (
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

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_outlet ON profiles(outlet_id);
CREATE INDEX idx_profiles_pin ON profiles(pin_code) WHERE pin_code IS NOT NULL;
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX idx_tables_outlet ON tables(outlet_id);

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

CREATE TRIGGER trigger_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_outlets_updated_at
  BEFORE UPDATE ON outlets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_tables_updated_at
  BEFORE UPDATE ON tables
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_categories_updated_at
  BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- AUDIT LOG HELPER FUNCTION
-- ============================================

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
-- SEED DATA
-- ============================================

-- Seed roles
INSERT INTO roles (name, display_name) VALUES
  ('owner', 'Owner/Admin'),
  ('cashier', 'Cashier'),
  ('barista', 'Barista/Kitchen');

-- Seed basic permissions
INSERT INTO permissions (key, description) VALUES
  ('pos.use', 'Access POS'),
  ('orders.view', 'View orders'),
  ('orders.create', 'Create orders'),
  ('products.view', 'View products'),
  ('products.manage', 'Manage products (CRUD)'),
  ('categories.manage', 'Manage categories'),
  ('inventory.view', 'View inventory'),
  ('inventory.manage', 'Manage inventory'),
  ('recipes.manage', 'Manage recipes'),
  ('tables.manage', 'Manage tables'),
  ('customers.view', 'View customers'),
  ('customers.manage', 'Manage customers'),
  ('payments.process', 'Process payments'),
  ('shifts.view', 'View shifts'),
  ('shifts.manage', 'Manage shifts'),
  ('reports.view', 'View reports'),
  ('reports.export', 'Export reports'),
  ('users.manage', 'Manage users'),
  ('settings.manage', 'Manage settings'),
  ('audit.view', 'View audit logs'),
  ('purchasing.manage', 'Manage purchasing'),
  ('suppliers.manage', 'Manage suppliers');

-- Assign permissions to roles
-- Owner gets everything
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.name = 'owner';

-- Cashier permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.name = 'cashier'
AND p.key IN ('pos.use', 'orders.view', 'orders.create', 'products.view',
              'customers.view', 'customers.manage', 'payments.process',
              'shifts.view', 'reports.view');

-- Barista permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE r.name = 'barista'
AND p.key IN ('orders.view', 'products.view');

-- Seed default outlet
INSERT INTO outlets (name, address) VALUES ('Main Store', 'Jl. Kopi No. 1');
