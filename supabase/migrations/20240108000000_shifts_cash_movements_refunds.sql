-- ============================================
-- KopiPOS — Sprint 8: Shift + Refund + Cash Movements
-- Migration: 20240108000000_shifts_cash_movements_refunds.sql
-- ============================================

-- ============================================
-- ENUMS
-- ============================================

CREATE TYPE shift_status AS ENUM ('open', 'closed');
CREATE TYPE cash_movement_type AS ENUM ('cash_sale', 'cash_in', 'cash_out', 'refund');

-- ============================================
-- SHIFTS TABLE
-- ============================================

CREATE TABLE shifts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  cashier_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status shift_status NOT NULL DEFAULT 'open',
  opening_cash NUMERIC(12,2) NOT NULL DEFAULT 0,
  closing_cash NUMERIC(12,2),          -- actual cash counted at close
  expected_cash NUMERIC(12,2),          -- calculated: opening + cash_in - cash_out - refunds
  difference NUMERIC(12,2),             -- closing - expected
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_shifts_outlet ON shifts(outlet_id);
CREATE INDEX idx_shifts_cashier ON shifts(cashier_id);
CREATE INDEX idx_shifts_status ON shifts(status);
CREATE INDEX idx_shifts_opened ON shifts(opened_at);

ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "shifts_select_auth" ON shifts FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "shifts_insert_auth" ON shifts FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "shifts_update_auth" ON shifts FOR UPDATE USING (auth.role() = 'authenticated');

-- ============================================
-- CASH MOVEMENTS TABLE
-- ============================================

CREATE TABLE cash_movements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
  type cash_movement_type NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  reference TEXT,                         -- order_id for cash_sale/refund, description for cash_in/out
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_cash_movements_shift ON cash_movements(shift_id);
CREATE INDEX idx_cash_movements_type ON cash_movements(type);
CREATE INDEX idx_cash_movements_created ON cash_movements(created_at);

ALTER TABLE cash_movements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cash_movements_select_auth" ON cash_movements FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "cash_movements_insert_auth" ON cash_movements FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ============================================
-- REFUNDS TABLE
-- ============================================

CREATE TABLE refunds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL,
  reason TEXT NOT NULL,
  approved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_refunds_order ON refunds(order_id);
CREATE INDEX idx_refunds_created ON refunds(created_at);

ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "refunds_select_auth" ON refunds FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "refunds_insert_auth" ON refunds FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ============================================
-- SHIFT RPC FUNCTIONS
-- ============================================

-- Open shift
CREATE OR REPLACE FUNCTION open_shift(
  p_outlet_id UUID,
  p_cashier_id UUID,
  p_opening_cash NUMERIC(12,2)
)
RETURNS JSONB AS $$
DECLARE
  v_existing UUID;
BEGIN
  -- Check for existing open shift for this cashier+outlet
  SELECT id INTO v_existing
  FROM shifts
  WHERE outlet_id = p_outlet_id AND cashier_id = p_cashier_id AND status = 'open'
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RETURN jsonb_build_object('error', 'You already have an open shift');
  END IF;

  INSERT INTO shifts (outlet_id, cashier_id, opening_cash, status)
  VALUES (p_outlet_id, p_cashier_id, p_opening_cash, 'open')
  RETURNING id INTO v_existing;

  PERFORM log_audit_event(
    p_cashier_id, NULL, 'shift_open', 'shift', v_existing,
    jsonb_build_object('opening_cash', p_opening_cash)
  );

  RETURN jsonb_build_object('success', true, 'shift_id', v_existing);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Close shift
CREATE OR REPLACE FUNCTION close_shift(
  p_shift_id UUID,
  p_closing_cash NUMERIC(12,2)
)
RETURNS JSONB AS $$
DECLARE
  v_shift RECORD;
  v_expected NUMERIC(12,2);
  v_diff NUMERIC(12,2);
  v_pending INT;
BEGIN
  SELECT * INTO v_shift FROM shifts WHERE id = p_shift_id FOR UPDATE;

  IF v_shift IS NULL THEN
    RETURN jsonb_build_object('error', 'Shift not found');
  END IF;

  IF v_shift.status != 'open' THEN
    RETURN jsonb_build_object('error', 'Shift is already closed');
  END IF;

  -- Check for pending orders (not completed/cancelled)
  SELECT COUNT(*) INTO v_pending
  FROM orders o
  JOIN shift_cash_sales scs ON scs.order_id = o.id
  WHERE scs.shift_id = p_shift_id
    AND o.status NOT IN ('completed', 'cancelled', 'void', 'refund');

  -- Simpler: check orders paid during this shift window
  SELECT COUNT(*) INTO v_pending
  FROM orders
  WHERE cashier_id = v_shift.cashier_id
    AND status IN ('confirmed', 'preparing', 'ready')
    AND created_at >= v_shift.opened_at;

  IF v_pending > 0 THEN
    RETURN jsonb_build_object('error', 'Cannot close shift: ' || v_pending || ' pending order(s)');
  END IF;

  -- Calculate expected cash
  SELECT COALESCE(SUM(
    CASE type
      WHEN 'cash_sale' THEN amount
      WHEN 'cash_in' THEN amount
      WHEN 'cash_out' THEN -amount
      WHEN 'refund' THEN -amount
      ELSE 0
    END
  ), 0)
  INTO v_expected
  FROM cash_movements
  WHERE shift_id = p_shift_id;

  v_expected := v_shift.opening_cash + v_expected;
  v_diff := p_closing_cash - v_expected;

  UPDATE shifts
  SET status = 'closed',
      closing_cash = p_closing_cash,
      expected_cash = v_expected,
      difference = v_diff,
      closed_at = now()
  WHERE id = p_shift_id;

  PERFORM log_audit_event(
    v_shift.cashier_id, NULL, 'shift_close', 'shift', p_shift_id,
    jsonb_build_object(
      'opening_cash', v_shift.opening_cash,
      'closing_cash', p_closing_cash,
      'expected_cash', v_expected,
      'difference', v_diff
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'expected_cash', v_expected,
    'closing_cash', p_closing_cash,
    'difference', v_diff
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Record cash movement
CREATE OR REPLACE FUNCTION record_cash_movement(
  p_shift_id UUID,
  p_type cash_movement_type,
  p_amount NUMERIC(12,2),
  p_reference TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO cash_movements (shift_id, type, amount, reference, description)
  VALUES (p_shift_id, p_type, p_amount, p_reference, p_description)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'movement_id', v_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- REFUND RPC (with refunds table row)
-- ============================================

-- Override refund_order to also insert into refunds table
CREATE OR REPLACE FUNCTION refund_order(
  p_order_id UUID,
  p_reason TEXT,
  p_approved_by UUID
)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_refund_id UUID;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object('error', 'Order not found');
  END IF;

  IF v_order.status != 'completed' THEN
    RETURN jsonb_build_object('error', 'Only completed orders can be refunded');
  END IF;

  -- Insert refund record
  INSERT INTO refunds (order_id, amount, reason, approved_by, created_by)
  VALUES (p_order_id, v_order.total, p_reason, p_approved_by, p_approved_by)
  RETURNING id INTO v_refund_id;

  -- Update order status
  UPDATE orders SET status = 'refund', updated_at = now() WHERE id = p_order_id;

  -- Free table if assigned
  IF v_order.table_id IS NOT NULL THEN
    UPDATE tables SET status = 'available', updated_at = now()
    WHERE id = v_order.table_id;
  END IF;

  -- Record cash movement if paid by cash
  -- (shift_id must be found from open shift)
  PERFORM log_audit_event(
    NULL, 'system', 'refund', 'order', p_order_id,
    jsonb_build_object('reason', p_reason, 'refund_id', v_refund_id, 'amount', v_order.total),
    p_reason, p_approved_by
  );

  RETURN jsonb_build_object('success', true, 'refund_id', v_refund_id, 'status', 'refund');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- UPDATE existing complete_order to also record cash movement
-- ============================================

CREATE OR REPLACE FUNCTION complete_order(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
  v_shift_id UUID;
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

  -- Record cash movement if payment was cash
  IF v_order.order_type IS NOT NULL THEN
    SELECT id INTO v_shift_id
    FROM shifts
    WHERE cashier_id = v_order.cashier_id AND status = 'open'
    LIMIT 1;

    IF v_shift_id IS NOT NULL THEN
      PERFORM record_cash_movement(v_shift_id, 'cash_sale', v_order.total, p_order_id::TEXT);
    END IF;
  END IF;

  PERFORM log_audit_event(
    NULL, 'system', 'payment', 'order', p_order_id,
    jsonb_build_object('action', 'complete')
  );

  RETURN jsonb_build_object('success', true, 'status', 'completed');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
