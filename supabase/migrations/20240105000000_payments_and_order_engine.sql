-- ============================================
-- KopiPOS — Sprint 5: Payments + Order State Machine
-- Migration: 20240105000000_payments_and_order_engine.sql
-- ============================================

-- ============================================
-- PAYMENTS TABLE
-- ============================================

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  method payment_method NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  reference_number TEXT,       -- for QRIS/debit/credit/e-wallet/transfer
  status TEXT NOT NULL DEFAULT 'completed', -- completed, pending, failed
  paid_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_method ON payments(method);
CREATE INDEX idx_payments_paid_at ON payments(paid_at);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payments_select_auth" ON payments FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "payments_insert_auth" ON payments FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ============================================
-- INVOICE NUMBER GENERATOR
-- ============================================

CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS TEXT AS $$
DECLARE
  today TEXT;
  seq INT;
  inv TEXT;
BEGIN
  today := to_char(now(), 'YYYYMMDD');
  -- Get next sequence for today
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(invoice_number FROM 14 FOR 5) AS INT)
  ), 0) + 1
  INTO seq
  FROM orders
  WHERE invoice_number LIKE 'INV-' || today || '-%';

  inv := 'INV-' || today || '-' || LPAD(seq::TEXT, 5, '0');
  RETURN inv;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ORDER STATE MACHINE FUNCTIONS
-- ============================================

-- Confirm order: DRAFT → CONFIRMED, set invoice#, set table to OCCUPIED
CREATE OR REPLACE FUNCTION confirm_order(
  p_order_id UUID,
  p_table_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_invoice TEXT;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object('error', 'Order not found');
  END IF;

  IF v_order.status != 'draft' THEN
    RETURN jsonb_build_object('error', 'Order must be in draft status');
  END IF;

  v_invoice := generate_invoice_number();

  UPDATE orders
  SET status = 'confirmed',
      invoice_number = v_invoice,
      table_id = COALESCE(p_table_id, table_id),
      updated_at = now()
  WHERE id = p_order_id;

  -- Set table to occupied if assigned
  IF p_table_id IS NOT NULL THEN
    UPDATE tables SET status = 'occupied', updated_at = now()
    WHERE id = p_table_id;
  END IF;

  -- Audit log
  PERFORM log_audit_event(
    NULL, 'system', 'payment', 'order', p_order_id,
    jsonb_build_object('action', 'confirm', 'invoice', v_invoice)
  );

  RETURN jsonb_build_object(
    'success', true,
    'invoice_number', v_invoice,
    'status', 'confirmed'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cancel order: DRAFT → CANCELLED
CREATE OR REPLACE FUNCTION cancel_order(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object('error', 'Order not found');
  END IF;

  IF v_order.status != 'draft' THEN
    RETURN jsonb_build_object('error', 'Only draft orders can be cancelled');
  END IF;

  UPDATE orders SET status = 'cancelled', updated_at = now() WHERE id = p_order_id;

  -- Free table if assigned
  IF v_order.table_id IS NOT NULL THEN
    UPDATE tables SET status = 'available', updated_at = now()
    WHERE id = v_order.table_id;
  END IF;

  PERFORM log_audit_event(
    NULL, 'system', 'delete', 'order', p_order_id,
    jsonb_build_object('action', 'cancel')
  );

  RETURN jsonb_build_object('success', true, 'status', 'cancelled');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Complete order: ready/completed → COMPLETED, free table
CREATE OR REPLACE FUNCTION complete_order(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object('error', 'Order not found');
  END IF;

  IF v_order.status NOT IN ('ready', 'completed') THEN
    RETURN jsonb_build_object('error', 'Order must be ready or completed');
  END IF;

  UPDATE orders
  SET status = 'completed', completed_at = now(), updated_at = now()
  WHERE id = p_order_id;

  -- Free table
  IF v_order.table_id IS NOT NULL THEN
    UPDATE tables SET status = 'available', updated_at = now()
    WHERE id = v_order.table_id;
  END IF;

  PERFORM log_audit_event(
    NULL, 'system', 'payment', 'order', p_order_id,
    jsonb_build_object('action', 'complete')
  );

  RETURN jsonb_build_object('success', true, 'status', 'completed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Void order: CONFIRMED → VOID (requires owner approval)
CREATE OR REPLACE FUNCTION void_order(
  p_order_id UUID,
  p_reason TEXT,
  p_approved_by UUID
)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object('error', 'Order not found');
  END IF;

  IF v_order.status != 'confirmed' THEN
    RETURN jsonb_build_object('error', 'Only confirmed orders can be voided');
  END IF;

  UPDATE orders SET status = 'void', updated_at = now() WHERE id = p_order_id;

  -- Free table
  IF v_order.table_id IS NOT NULL THEN
    UPDATE tables SET status = 'available', updated_at = now()
    WHERE id = v_order.table_id;
  END IF;

  PERFORM log_audit_event(
    NULL, 'system', 'void', 'order', p_order_id,
    jsonb_build_object('reason', p_reason),
    p_reason, p_approved_by
  );

  RETURN jsonb_build_object('success', true, 'status', 'void');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Start preparing: CONFIRMED → PREPARING
CREATE OR REPLACE FUNCTION start_preparing(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object('error', 'Order not found');
  END IF;

  IF v_order.status != 'confirmed' THEN
    RETURN jsonb_build_object('error', 'Order must be confirmed first');
  END IF;

  UPDATE orders SET status = 'preparing', updated_at = now() WHERE id = p_order_id;

  PERFORM log_audit_event(
    NULL, 'system', 'update', 'order', p_order_id,
    jsonb_build_object('action', 'start_preparing')
  );

  RETURN jsonb_build_object('success', true, 'status', 'preparing');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Mark ready: PREPARING → READY
CREATE OR REPLACE FUNCTION mark_ready(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object('error', 'Order not found');
  END IF;

  IF v_order.status != 'preparing' THEN
    RETURN jsonb_build_object('error', 'Order must be preparing');
  END IF;

  UPDATE orders SET status = 'ready', updated_at = now() WHERE id = p_order_id;

  PERFORM log_audit_event(
    NULL, 'system', 'update', 'order', p_order_id,
    jsonb_build_object('action', 'mark_ready')
  );

  RETURN jsonb_build_object('success', true, 'status', 'ready');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Refund order: COMPLETED → REFUND
CREATE OR REPLACE FUNCTION refund_order(
  p_order_id UUID,
  p_reason TEXT,
  p_approved_by UUID
)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object('error', 'Order not found');
  END IF;

  IF v_order.status != 'completed' THEN
    RETURN jsonb_build_object('error', 'Only completed orders can be refunded');
  END IF;

  UPDATE orders SET status = 'refund', updated_at = now() WHERE id = p_order_id;

  -- Free table if still assigned
  IF v_order.table_id IS NOT NULL THEN
    UPDATE tables SET status = 'available', updated_at = now()
    WHERE id = v_order.table_id;
  END IF;

  PERFORM log_audit_event(
    NULL, 'system', 'refund', 'order', p_order_id,
    jsonb_build_object('reason', p_reason),
    p_reason, p_approved_by
  );

  RETURN jsonb_build_object('success', true, 'status', 'refund');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- TABLE MANAGEMENT FUNCTIONS
-- ============================================

-- Transfer table: move order from one table to another
CREATE OR REPLACE FUNCTION transfer_table(
  p_from_table_id UUID,
  p_to_table_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_target_status TEXT;
BEGIN
  SELECT status INTO v_target_status FROM tables WHERE id = p_to_table_id;

  IF v_target_status != 'available' THEN
    RETURN jsonb_build_object('error', 'Target table is not available');
  END IF;

  -- Move order to new table
  UPDATE orders SET table_id = p_to_table_id, updated_at = now()
  WHERE table_id = p_from_table_id AND status IN ('confirmed', 'preparing');

  -- Update table statuses
  UPDATE tables SET status = 'available', updated_at = now() WHERE id = p_from_table_id;
  UPDATE tables SET status = 'occupied', updated_at = now() WHERE id = p_to_table_id;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- SEED: Add some default tables for demo
-- ============================================

INSERT INTO tables (outlet_id, number, capacity, status)
SELECT id, 'A01', 4, 'available' FROM outlets WHERE name = 'Main Store'
ON CONFLICT DO NOTHING;

INSERT INTO tables (outlet_id, number, capacity, status)
SELECT id, 'A02', 4, 'available' FROM outlets WHERE name = 'Main Store'
ON CONFLICT DO NOTHING;

INSERT INTO tables (outlet_id, number, capacity, status)
SELECT id, 'A03', 2, 'available' FROM outlets WHERE name = 'Main Store'
ON CONFLICT DO NOTHING;

INSERT INTO tables (outlet_id, number, capacity, status)
SELECT id, 'B01', 6, 'available' FROM outlets WHERE name = 'Main Store'
ON CONFLICT DO NOTHING;

INSERT INTO tables (outlet_id, number, capacity, status)
SELECT id, 'B02', 8, 'available' FROM outlets WHERE name = 'Main Store'
ON CONFLICT DO NOTHING;
