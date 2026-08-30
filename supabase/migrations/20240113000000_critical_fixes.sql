-- ============================================
-- KopiPOS — Critical P0 Fixes
-- Migration: 20240113000000_critical_fixes.sql
-- ============================================

-- 1. Fix complete_order: accept draft/confirmed/preparing/ready (not just ready/completed)
CREATE OR REPLACE FUNCTION complete_order(p_order_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_order RECORD;
BEGIN
  SELECT * INTO v_order FROM orders WHERE id = p_order_id FOR UPDATE;

  IF v_order IS NULL THEN
    RETURN jsonb_build_object('error', 'Order not found');
  END IF;

  IF v_order.status NOT IN ('draft', 'confirmed', 'preparing', 'ready') THEN
    RETURN jsonb_build_object('error', 'Order cannot be completed from status: ' || v_order.status);
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

-- 2. Fix login_by_pin: remove pin_code from return (security leak)
DROP FUNCTION IF EXISTS public.login_by_pin(TEXT);

CREATE OR REPLACE FUNCTION public.login_by_pin(pin_hash TEXT)
RETURNS TABLE(id UUID, full_name TEXT, role TEXT, outlet_id UUID, is_active BOOLEAN, created_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.full_name, p.role::text, p.outlet_id, p.is_active, p.created_at
  FROM profiles p
  WHERE p.pin_code = pin_hash AND p.is_active = true;
END;
$$;

COMMENT ON FUNCTION public.login_by_pin IS 'PIN login lookup — bypasses RLS via SECURITY DEFINER, does NOT return pin_code hash';

-- 3. Add settings table for tax/service charge (if not exists)
CREATE TABLE IF NOT EXISTS settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  outlet_id UUID REFERENCES outlets(id),
  key TEXT NOT NULL,
  value JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(outlet_id, key)
);

ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "settings_select_auth" ON settings FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "settings_insert_auth" ON settings FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "settings_update_auth" ON settings FOR UPDATE USING (auth.role() = 'authenticated');

-- Seed default settings for Main Store
INSERT INTO settings (outlet_id, key, value)
SELECT id, 'tax', '{"percent": 11, "enabled": true}'::jsonb FROM outlets WHERE name = 'Main Store'
ON CONFLICT (outlet_id, key) DO NOTHING;

INSERT INTO settings (outlet_id, key, value)
SELECT id, 'service_charge', '{"percent": 5, "enabled": true}'::jsonb FROM outlets WHERE name = 'Main Store'
ON CONFLICT (outlet_id, key) DO NOTHING;

-- 4. Add get_settings RPC for easy frontend access
DROP FUNCTION IF EXISTS public.get_settings(UUID);

CREATE OR REPLACE FUNCTION public.get_settings(p_outlet_id UUID)
RETURNS TABLE(key TEXT, value JSONB)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT s.key, s.value
  FROM settings s
  WHERE s.outlet_id = p_outlet_id;
END;
$$;

-- 5. Fix generate_invoice_number race condition with advisory lock
DROP FUNCTION IF EXISTS generate_invoice_number();

CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS TEXT AS $$
DECLARE
  today TEXT;
  seq INT;
  inv TEXT;
BEGIN
  -- Advisory lock prevents concurrent duplicate invoice numbers
  PERFORM pg_advisory_lock(100001);

  today := to_char(now(), 'YYYYMMDD');
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(invoice_number FROM 14 FOR 5) AS INT)
  ), 0) + 1
  INTO seq
  FROM orders
  WHERE invoice_number LIKE 'INV-' || today || '-%';

  inv := 'INV-' || today || '-' || LPAD(seq::TEXT, 5, '0');

  PERFORM pg_advisory_unlock(100001);
  RETURN inv;
END;
$$ LANGUAGE plpgsql;
