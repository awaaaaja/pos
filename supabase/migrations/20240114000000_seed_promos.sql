-- Seed test promos and coupons for KopiPOS

-- Promo: 10% off all orders
INSERT INTO promos (name, type, discount_value, minimum_purchase, maximum_discount, is_active)
VALUES ('Promo 10%', 'percentage', 10, 0, 50000, true)
ON CONFLICT DO NOTHING;

-- Coupon: FLAT10K off min 50k
INSERT INTO promos (name, type, discount_value, minimum_purchase, maximum_discount, is_active)
VALUES ('Diskon Rp10.000', 'fixed', 10000, 50000, NULL, true)
ON CONFLICT DO NOTHING;

-- Link coupons to the fixed promo
INSERT INTO coupons (promo_id, code, usage_limit, used_count, min_purchase, is_active)
SELECT p.id, 'FLAT10K', 100, 0, 50000, true
FROM promos p WHERE p.name = 'Diskon Rp10.000'
ON CONFLICT DO NOTHING;

INSERT INTO coupons (promo_id, code, usage_limit, used_count, min_purchase, is_active)
SELECT p.id, 'HEMAT20', 50, 0, 100000, true
FROM promos p WHERE p.name = 'Diskon Rp10.000'
ON CONFLICT DO NOTHING;

-- Default loyalty settings for Main Store
INSERT INTO loyalty_settings (outlet_id, points_per_rupiah, redeem_value_per_point, min_points_redeem, expiry_months, is_active)
SELECT id, 0.001, 1, 100, 12, true
FROM outlets WHERE name = 'Main Store'
ON CONFLICT DO NOTHING;
