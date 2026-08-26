-- ============================================
-- Sprint 10: Customer + Loyalty + Promo
-- ============================================

-- 1. Customers
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  birthday DATE,
  points NUMERIC NOT NULL DEFAULT 0,
  total_spending NUMERIC NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Loyalty settings (singleton per outlet)
CREATE TABLE loyalty_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  points_per_rupiah NUMERIC NOT NULL DEFAULT 0.0001,
  redeem_value_per_point NUMERIC NOT NULL DEFAULT 100,
  min_points_redeem NUMERIC NOT NULL DEFAULT 100,
  expiry_months INT NOT NULL DEFAULT 12,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(outlet_id)
);

-- 3. Loyalty transactions
CREATE TABLE loyalty_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('earn', 'redeem', 'expire', 'adjustment')),
  points NUMERIC NOT NULL,
  description TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Promos
CREATE TABLE promos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('percentage', 'fixed', 'coupon', 'bogo', 'bundle', 'member_discount')),
  discount_value NUMERIC NOT NULL DEFAULT 0,
  minimum_purchase NUMERIC NOT NULL DEFAULT 0,
  maximum_discount NUMERIC,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Coupons (linked to promo type='coupon')
CREATE TABLE coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_id UUID NOT NULL REFERENCES promos(id) ON DELETE CASCADE,
  code TEXT UNIQUE NOT NULL,
  usage_limit INT,
  used_count INT NOT NULL DEFAULT 0,
  min_purchase NUMERIC NOT NULL DEFAULT 0,
  max_discount NUMERIC,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  customer_eligibility TEXT NOT NULL DEFAULT 'all' CHECK (customer_eligibility IN ('all', 'member', 'new')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Order discount breakdown
ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount_type TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS coupon_id UUID REFERENCES coupons(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS promo_id UUID REFERENCES promos(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id);

-- 7. RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE promos ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner manage customers" ON customers FOR ALL USING (public.user_role() = 'owner');
CREATE POLICY "Cashier view customers" ON customers FOR SELECT USING (public.user_role() = 'cashier');
CREATE POLICY "Barista view customers" ON customers FOR SELECT USING (public.user_role() = 'barista');
CREATE POLICY "Owner manage loyalty_settings" ON loyalty_settings FOR ALL USING (public.user_role() = 'owner');
CREATE POLICY "Owner manage loyalty_transactions" ON loyalty_transactions FOR ALL USING (public.user_role() = 'owner');
CREATE POLICY "Cashier view loyalty_transactions" ON loyalty_transactions FOR SELECT USING (public.user_role() = 'cashier');
CREATE POLICY "Owner manage promos" ON promos FOR ALL USING (public.user_role() = 'owner');
CREATE POLICY "Cashier view promos" ON promos FOR SELECT USING (public.user_role() = 'cashier');
CREATE POLICY "Owner manage coupons" ON coupons FOR ALL USING (public.user_role() = 'owner');
CREATE POLICY "Cashier view coupons" ON coupons FOR SELECT USING (public.user_role() = 'cashier');
CREATE POLICY "System insert loyalty_transactions" ON loyalty_transactions FOR INSERT WITH CHECK (true);

-- 8. RPC: earn loyalty points after order completion
CREATE OR REPLACE FUNCTION public.earn_loyalty_points(p_order_id UUID, p_customer_id UUID, p_amount NUMERIC)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_rate NUMERIC; v_points NUMERIC;
BEGIN
  SELECT points_per_rupiah INTO v_rate FROM loyalty_settings WHERE is_active = true LIMIT 1;
  IF v_rate IS NULL OR v_rate = 0 THEN RETURN; END IF;
  
  v_points := floor(p_amount * v_rate);
  IF v_points <= 0 THEN RETURN; END IF;
  
  UPDATE customers SET points = points + v_points, updated_at = now() WHERE id = p_customer_id;
  
  INSERT INTO loyalty_transactions (customer_id, order_id, type, points, description)
  VALUES (p_customer_id, p_order_id, 'earn', v_points, 'Points earned from order');
END;
$$;

-- 9. RPC: redeem loyalty points
CREATE OR REPLACE FUNCTION public.redeem_loyalty_points(p_customer_id UUID, p_points NUMERIC)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_customer RECORD; v_value NUMERIC; v_redeem_value NUMERIC;
BEGIN
  SELECT * INTO v_customer FROM customers WHERE id = p_customer_id FOR UPDATE;
  IF v_customer IS NULL THEN RAISE EXCEPTION 'Customer not found'; END IF;
  IF v_customer.points < p_points THEN RAISE EXCEPTION 'Insufficient points'; END IF;
  
  SELECT redeem_value_per_point INTO v_redeem_value FROM loyalty_settings WHERE is_active = true LIMIT 1;
  IF v_redeem_value IS NULL THEN v_redeem_value := 100; END IF;
  
  v_value := p_points * v_redeem_value;
  
  UPDATE customers SET points = points - p_points, updated_at = now() WHERE id = p_customer_id;
  
  INSERT INTO loyalty_transactions (customer_id, type, points, description)
  VALUES (p_customer_id, 'redeem', -p_points, 'Points redeemed: Rp' || v_value);
  
  RETURN v_value;
END;
$$;

-- 10. RPC: validate coupon
CREATE OR REPLACE FUNCTION public.validate_coupon(p_code TEXT, p_amount NUMERIC)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_coupon RECORD; v_promo RECORD;
BEGIN
  SELECT c.*, p.type as promo_type, p.discount_value, p.maximum_discount
  INTO v_coupon
  FROM coupons c JOIN promos p ON p.id = c.promo_id
  WHERE c.code = upper(p_code) AND c.is_active = true AND p.is_active = true;
  
  IF v_coupon IS NULL THEN RETURN jsonb_build_object('error', 'Coupon not found'); END IF;
  IF v_coupon.start_date IS NOT NULL AND now() < v_coupon.start_date THEN RETURN jsonb_build_object('error', 'Coupon not yet valid'); END IF;
  IF v_coupon.end_date IS NOT NULL AND now() > v_coupon.end_date THEN RETURN jsonb_build_object('error', 'Coupon expired'); END IF;
  IF v_coupon.usage_limit IS NOT NULL AND v_coupon.used_count >= v_coupon.usage_limit THEN RETURN jsonb_build_object('error', 'Coupon usage limit reached'); END IF;
  IF p_amount < v_coupon.min_purchase THEN RETURN jsonb_build_object('error', 'Minimum purchase not met'); END IF;
  
  UPDATE coupons SET used_count = used_count + 1 WHERE id = v_coupon.id;
  
  RETURN jsonb_build_object(
    'success', true,
    'coupon_id', v_coupon.id,
    'promo_type', v_coupon.promo_type,
    'discount_value', v_coupon.discount_value,
    'maximum_discount', v_coupon.maximum_discount
  );
END;
$$;

-- 11. Indexes
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_loyalty_transactions_customer ON loyalty_transactions(customer_id);
CREATE INDEX idx_coupons_code ON coupons(code);
CREATE INDEX idx_promos_active ON promos(is_active);
