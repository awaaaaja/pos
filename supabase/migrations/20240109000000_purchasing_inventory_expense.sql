-- ============================================
-- KopiPOS — Sprint 9: Purchasing + Inventory + Expense + Waste
-- Migration: 20240109000000_purchasing_inventory_expense.sql
-- ============================================

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE po_status AS ENUM (
  'draft', 'approved', 'ordered', 'partially_received', 'completed', 'cancelled'
);

CREATE TYPE inventory_movement_type AS ENUM (
  'purchase', 'waste', 'opname', 'adjustment', 'sale'
);

-- ============================================
-- SUPPLIERS
-- ============================================

CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  payment_terms TEXT,  -- e.g. "NET 30", "COD"
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_suppliers_name ON suppliers(name);
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "suppliers_select_auth" ON suppliers FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "suppliers_insert_auth" ON suppliers FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "suppliers_update_auth" ON suppliers FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "suppliers_delete_auth" ON suppliers FOR DELETE USING (auth.role() = 'authenticated');

-- ============================================
-- PURCHASE ORDERS
-- ============================================

CREATE TABLE purchase_orders (
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

CREATE INDEX idx_po_supplier ON purchase_orders(supplier_id);
CREATE INDEX idx_po_status ON purchase_orders(status);
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "po_select_auth" ON purchase_orders FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "po_insert_auth" ON purchase_orders FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "po_update_auth" ON purchase_orders FOR UPDATE USING (auth.role() = 'authenticated');

-- ============================================
-- PURCHASE ORDER ITEMS
-- ============================================

CREATE TABLE purchase_order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  po_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  expected_qty NUMERIC(10,2) NOT NULL DEFAULT 0,
  received_qty NUMERIC(10,2) NOT NULL DEFAULT 0,
  unit_cost NUMERIC(12,2) NOT NULL DEFAULT 0,
  subtotal NUMERIC(12,2) GENERATED ALWAYS AS (expected_qty * unit_cost) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_po_items_po ON purchase_order_items(po_id);
CREATE INDEX idx_po_items_product ON purchase_order_items(product_id);
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "po_items_select_auth" ON purchase_order_items FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "po_items_insert_auth" ON purchase_order_items FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "po_items_update_auth" ON purchase_order_items FOR UPDATE USING (auth.role() = 'authenticated');

-- ============================================
-- INVENTORY (stock levels per product per outlet)
-- ============================================

CREATE TABLE inventory (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  qty NUMERIC(10,2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(product_id, outlet_id)
);

CREATE INDEX idx_inventory_product ON inventory(product_id);
CREATE INDEX idx_inventory_outlet ON inventory(outlet_id);
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "inventory_select_auth" ON inventory FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "inventory_insert_auth" ON inventory FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "inventory_update_auth" ON inventory FOR UPDATE USING (auth.role() = 'authenticated');

-- ============================================
-- INVENTORY MOVEMENTS
-- ============================================

CREATE TABLE inventory_movements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  type inventory_movement_type NOT NULL,
  qty NUMERIC(10,2) NOT NULL,  -- positive=in, negative=out
  reference_type TEXT,  -- 'purchase', 'waste', 'opname', 'adjustment', 'sale'
  reference_id UUID,    -- po_id, waste_id, opname_id, etc.
  notes TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_inv_mov_product ON inventory_movements(product_id);
CREATE INDEX idx_inv_mov_type ON inventory_movements(type);
CREATE INDEX idx_inv_mov_ref ON inventory_movements(reference_type, reference_id);
CREATE INDEX idx_inv_mov_created ON inventory_movements(created_at);
ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "inv_mov_select_auth" ON inventory_movements FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "inv_mov_insert_auth" ON inventory_movements FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ============================================
-- WASTE RECORDS
-- ============================================

CREATE TABLE waste_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  qty NUMERIC(10,2) NOT NULL,
  reason TEXT NOT NULL,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_waste_product ON waste_records(product_id);
ALTER TABLE waste_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "waste_select_auth" ON waste_records FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "waste_insert_auth" ON waste_records FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ============================================
-- EXPENSES
-- ============================================

CREATE TABLE expenses (
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

CREATE INDEX idx_expenses_category ON expenses(category);
CREATE INDEX idx_expenses_date ON expenses(date);
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "expenses_select_auth" ON expenses FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "expenses_insert_auth" ON expenses FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "expenses_update_auth" ON expenses FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "expenses_delete_auth" ON expenses FOR DELETE USING (auth.role() = 'authenticated');

-- ============================================
-- STOCK OPNAME
-- ============================================

CREATE TABLE stock_opnames (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  status TEXT NOT NULL DEFAULT 'draft',  -- draft, confirmed
  notes TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ
);

ALTER TABLE stock_opnames ENABLE ROW LEVEL SECURITY;
CREATE POLICY "opname_select_auth" ON stock_opnames FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "opname_insert_auth" ON stock_opnames FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "opname_update_auth" ON stock_opnames FOR UPDATE USING (auth.role() = 'authenticated');

CREATE TABLE stock_opname_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  opname_id UUID NOT NULL REFERENCES stock_opnames(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  system_qty NUMERIC(10,2) NOT NULL,
  actual_qty NUMERIC(10,2) NOT NULL DEFAULT 0,
  difference NUMERIC(10,2) GENERATED ALWAYS AS (actual_qty - system_qty) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE stock_opname_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "opname_items_select_auth" ON stock_opname_items FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "opname_items_insert_auth" ON stock_opname_items FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "opname_items_update_auth" ON stock_opname_items FOR UPDATE USING (auth.role() = 'authenticated');

-- ============================================
-- RPC: PURCHASE ORDER STATE MACHINE
-- ============================================

CREATE OR REPLACE FUNCTION approve_po(p_po_id UUID)
RETURNS JSONB AS $$
DECLARE v_po RECORD;
BEGIN
  SELECT * INTO v_po FROM purchase_orders WHERE id = p_po_id FOR UPDATE;
  IF v_po IS NULL THEN RETURN jsonb_build_object('error', 'PO not found'); END IF;
  IF v_po.status != 'draft' THEN RETURN jsonb_build_object('error', 'Only draft POs can be approved'); END IF;

  UPDATE purchase_orders SET status = 'approved', updated_at = now() WHERE id = p_po_id;
  PERFORM log_audit_event(NULL, 'system', 'update', 'purchase_order', p_po_id, jsonb_build_object('action', 'approve'));
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
  PERFORM log_audit_event(NULL, 'system', 'update', 'purchase_order', p_po_id, jsonb_build_object('action', 'order'));
  RETURN jsonb_build_object('success', true, 'status', 'ordered');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION receive_po(
  p_po_id UUID,
  p_product_id UUID,
  p_qty NUMERIC(10,2),
  p_outlet_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_po RECORD;
  v_item RECORD;
  v_new_received NUMERIC(10,2);
  v_total_expected NUMERIC(10,2);
  v_total_received NUMERIC(10,2);
BEGIN
  SELECT * INTO v_po FROM purchase_orders WHERE id = p_po_id FOR UPDATE;
  IF v_po IS NULL THEN RETURN jsonb_build_object('error', 'PO not found'); END IF;
  IF v_po.status NOT IN ('ordered', 'partially_received') THEN
    RETURN jsonb_build_object('error', 'PO must be ordered or partially received');
  END IF;

  -- Find PO item
  SELECT * INTO v_item FROM purchase_order_items
  WHERE po_id = p_po_id AND product_id = p_product_id FOR UPDATE;

  IF v_item IS NULL THEN RETURN jsonb_build_object('error', 'Product not in this PO'); END IF;

  v_new_received := v_item.received_qty + p_qty;

  IF v_new_received > v_item.expected_qty THEN
    RETURN jsonb_build_object('error', 'Received qty exceeds expected qty');
  END IF;

  -- Update received qty
  UPDATE purchase_order_items SET received_qty = v_new_received WHERE id = v_item.id;

  -- Upsert inventory
  INSERT INTO inventory (product_id, outlet_id, qty)
  VALUES (p_product_id, p_outlet_id, p_qty)
  ON CONFLICT (product_id, outlet_id)
  DO UPDATE SET qty = inventory.qty + p_qty, updated_at = now();

  -- Record movement
  INSERT INTO inventory_movements (product_id, outlet_id, type, qty, reference_type, reference_id, notes)
  VALUES (p_product_id, p_outlet_id, 'purchase', p_qty, 'goods_receipt', p_po_id,
    'PO ' || v_po.order_number || ' - ' || v_item.expected_qty || ' ordered');

  -- Update PO status
  SELECT SUM(expected_qty), SUM(received_qty)
  INTO v_total_expected, v_total_received
  FROM purchase_order_items WHERE po_id = p_po_id;

  IF v_total_received >= v_total_expected THEN
    UPDATE purchase_orders SET status = 'completed', updated_at = now() WHERE id = p_po_id;
  ELSE
    UPDATE purchase_orders SET status = 'partially_received', updated_at = now() WHERE id = p_po_id;
  END IF;

  PERFORM log_audit_event(NULL, 'system', 'create', 'inventory_movement', NULL,
    jsonb_build_object('type', 'purchase', 'product_id', p_product_id, 'qty', p_qty, 'po_id', p_po_id));

  RETURN jsonb_build_object('success', true, 'new_received', v_new_received);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RPC: WASTE
-- ============================================

CREATE OR REPLACE FUNCTION record_waste(
  p_product_id UUID,
  p_outlet_id UUID,
  p_qty NUMERIC(10,2),
  p_reason TEXT,
  p_created_by UUID
)
RETURNS JSONB AS $$
DECLARE
  v_inv RECORD;
  v_waste_id UUID;
BEGIN
  -- Check stock
  SELECT * INTO v_inv FROM inventory
  WHERE product_id = p_product_id AND outlet_id = p_outlet_id FOR UPDATE;

  IF v_inv IS NULL OR v_inv.qty < p_qty THEN
    RETURN jsonb_build_object('error', 'Insufficient stock');
  END IF;

  -- Deduct stock
  UPDATE inventory SET qty = qty - p_qty, updated_at = now()
  WHERE product_id = p_product_id AND outlet_id = p_outlet_id;

  -- Record waste
  INSERT INTO waste_records (product_id, outlet_id, qty, reason, created_by)
  VALUES (p_product_id, p_outlet_id, p_qty, p_reason, p_created_by)
  RETURNING id INTO v_waste_id;

  -- Record movement
  INSERT INTO inventory_movements (product_id, outlet_id, type, qty, reference_type, reference_id, notes, created_by)
  VALUES (p_product_id, p_outlet_id, 'waste', -p_qty, 'waste', v_waste_id, p_reason, p_created_by);

  PERFORM log_audit_event(p_created_by, NULL, 'create', 'waste', v_waste_id,
    jsonb_build_object('product_id', p_product_id, 'qty', p_qty, 'reason', p_reason));

  RETURN jsonb_build_object('success', true, 'waste_id', v_waste_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RPC: STOCK OPNAME CONFIRM
-- ============================================

CREATE OR REPLACE FUNCTION confirm_stock_opname(p_opname_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_opname RECORD;
  v_item RECORD;
BEGIN
  SELECT * INTO v_opname FROM stock_opnames WHERE id = p_opname_id FOR UPDATE;
  IF v_opname IS NULL THEN RETURN jsonb_build_object('error', 'Opname not found'); END IF;
  IF v_opname.status != 'draft' THEN RETURN jsonb_build_object('error', 'Opname already confirmed'); END IF;

  -- Process each item
  FOR v_item IN SELECT * FROM stock_opname_items WHERE opname_id = p_opname_id
  LOOP
    IF v_item.difference != 0 THEN
      -- Upsert inventory
      INSERT INTO inventory (product_id, outlet_id, qty)
      VALUES (v_item.product_id, v_opname.outlet_id, v_item.difference)
      ON CONFLICT (product_id, outlet_id)
      DO UPDATE SET qty = inventory.qty + v_item.difference, updated_at = now();

      -- Record movement
      INSERT INTO inventory_movements (product_id, outlet_id, type, qty, reference_type, reference_id, notes)
      VALUES (v_item.product_id, v_opname.outlet_id, 'opname', v_item.difference, 'opname', p_opname_id,
        'Stock opname adjustment: ' || v_item.system_qty || ' -> ' || v_item.actual_qty);
    END IF;
  END LOOP;

  UPDATE stock_opnames SET status = 'confirmed', confirmed_at = now() WHERE id = p_opname_id;

  PERFORM log_audit_event(NULL, 'system', 'stock_opname', 'stock_opname', p_opname_id, NULL);
  RETURN jsonb_build_object('success', true, 'status', 'confirmed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RPC: EXPENSE CRUD helpers
-- ============================================

CREATE OR REPLACE FUNCTION generate_po_number()
RETURNS TEXT AS $$
DECLARE
  today TEXT;
  seq INT;
BEGIN
  today := to_char(now(), 'YYYYMMDD');
  SELECT COALESCE(MAX(CAST(SUBSTRING(order_number FROM 6 FOR 5) AS INT)), 0) + 1 INTO seq
  FROM purchase_orders WHERE order_number LIKE 'PO-' || today || '-%';
  RETURN 'PO-' || today || '-' || LPAD(seq::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;
