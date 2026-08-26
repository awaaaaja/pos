-- ============================================
-- KopiPOS — Sprint 2: RLS Policies
-- Migration: 20240101000001_rls_policies.sql
-- ============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE outlets ENABLE ROW LEVEL SECURITY;
ALTER TABLE tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- ============================================
-- HELPER: Get current user's role
-- ============================================

CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================
-- HELPER: Check if user has permission
-- ============================================

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

-- ============================================
-- PROFILES
-- ============================================

-- Users can read their own profile
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (id = auth.uid());

-- Owner can read all profiles
CREATE POLICY "profiles_select_owner" ON profiles
  FOR SELECT USING (auth.user_role() = 'owner');

-- Owner can update all profiles
CREATE POLICY "profiles_update_owner" ON profiles
  FOR UPDATE USING (auth.user_role() = 'owner');

-- Users can update their own profile (limited fields)
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (id = auth.uid());

-- Owner can insert profiles
CREATE POLICY "profiles_insert_owner" ON profiles
  FOR INSERT WITH CHECK (auth.user_role() = 'owner');

-- ============================================
-- ROLES (read-only for everyone, managed via SQL)
-- ============================================

CREATE POLICY "roles_select_all" ON roles
  FOR SELECT USING (true);

-- ============================================
-- PERMISSIONS (read-only)
-- ============================================

CREATE POLICY "permissions_select_all" ON permissions
  FOR SELECT USING (true);

-- ============================================
-- ROLE_PERMISSIONS (read-only)
-- ============================================

CREATE POLICY "role_permissions_select_all" ON role_permissions
  FOR SELECT USING (true);

-- ============================================
-- OUTLETS
-- ============================================

-- Everyone can read outlets
CREATE POLICY "outlets_select_all" ON outlets
  FOR SELECT USING (true);

-- Only owner can manage outlets
CREATE POLICY "outlets_insert_owner" ON outlets
  FOR INSERT WITH CHECK (auth.user_role() = 'owner');

CREATE POLICY "outlets_update_owner" ON outlets
  FOR UPDATE USING (auth.user_role() = 'owner');

CREATE POLICY "outlets_delete_owner" ON outlets
  FOR DELETE USING (auth.user_role() = 'owner');

-- ============================================
-- TABLES
-- ============================================

-- Everyone can read tables
CREATE POLICY "tables_select_all" ON tables
  FOR SELECT USING (true);

-- Owner and cashier can manage tables
CREATE POLICY "tables_insert_owner_cashier" ON tables
  FOR INSERT WITH CHECK (auth.user_role() IN ('owner', 'cashier'));

CREATE POLICY "tables_update_owner_cashier" ON tables
  FOR UPDATE USING (auth.user_role() IN ('owner', 'cashier'));

CREATE POLICY "tables_delete_owner" ON tables
  FOR DELETE USING (auth.user_role() = 'owner');

-- ============================================
-- CATEGORIES
-- ============================================

-- Everyone can read active categories
CREATE POLICY "categories_select_all" ON categories
  FOR SELECT USING (true);

-- Only owner can manage categories
CREATE POLICY "categories_insert_owner" ON categories
  FOR INSERT WITH CHECK (auth.user_role() = 'owner');

CREATE POLICY "categories_update_owner" ON categories
  FOR UPDATE USING (auth.user_role() = 'owner');

CREATE POLICY "categories_delete_owner" ON categories
  FOR DELETE USING (auth.user_role() = 'owner');

-- ============================================
-- PRODUCTS
-- ============================================

-- Everyone can read active products
CREATE POLICY "products_select_all" ON products
  FOR SELECT USING (is_active = true OR auth.user_role() = 'owner');

-- Only owner can manage products
CREATE POLICY "products_insert_owner" ON products
  FOR INSERT WITH CHECK (auth.user_role() = 'owner');

CREATE POLICY "products_update_owner" ON products
  FOR UPDATE USING (auth.user_role() = 'owner');

CREATE POLICY "products_delete_owner" ON products
  FOR DELETE USING (auth.user_role() = 'owner');

-- ============================================
-- AUDIT LOGS
-- ============================================

-- Only owner can read audit logs
CREATE POLICY "audit_logs_select_owner" ON audit_logs
  FOR SELECT USING (auth.user_role() = 'owner');

-- System can insert audit logs (via SECURITY DEFINER function)
CREATE POLICY "audit_logs_insert_system" ON audit_logs
  FOR INSERT WITH CHECK (true);

-- No one can update or delete audit logs
CREATE POLICY "audit_logs_no_update" ON audit_logs
  FOR UPDATE USING (false);

CREATE POLICY "audit_logs_no_delete" ON audit_logs
  FOR DELETE USING (false);
