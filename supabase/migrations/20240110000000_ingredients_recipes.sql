-- ============================================
-- Sprint 7: Ingredients + Recipe Engine + Atomic Deduction
-- ============================================

-- 1. Ingredients table
CREATE TABLE ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  sku TEXT UNIQUE NOT NULL,
  barcode TEXT,
  unit TEXT NOT NULL DEFAULT 'pcs' CHECK (unit IN ('g','kg','ml','L','pcs','pack')),
  stock NUMERIC NOT NULL DEFAULT 0,
  minimum_stock NUMERIC NOT NULL DEFAULT 0,
  cost NUMERIC NOT NULL DEFAULT 0,
  supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Recipes: 1 product → n ingredients
CREATE TABLE recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Recipe items: which ingredients + qty per recipe
CREATE TABLE recipe_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  qty NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Ingredient stock movements (separate from product inventory_movements)
CREATE TABLE ingredient_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES outlets(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('purchase','adjustment','waste','order_deduction','stock_opname')),
  qty NUMERIC NOT NULL,
  reference_type TEXT,
  reference_id UUID,
  notes TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. RLS
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingredient_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner manage ingredients" ON ingredients FOR ALL USING (public.user_role() = 'owner');
CREATE POLICY "Owner manage recipes" ON recipes FOR ALL USING (public.user_role() = 'owner');
CREATE POLICY "Owner manage recipe_items" ON recipe_items FOR ALL USING (public.user_role() = 'owner');
CREATE POLICY "Owner view ingredient_movements" ON ingredient_movements FOR SELECT USING (public.user_role() = 'owner');
CREATE POLICY "Barista view ingredient_movements" ON ingredient_movements FOR SELECT USING (public.user_role() = 'barista');
CREATE POLICY "System insert ingredient_movements" ON ingredient_movements FOR INSERT WITH CHECK (true);

-- 6. RPC: complete_order_with_deduction — deducts ingredient stock atomically
CREATE OR REPLACE FUNCTION public.complete_order_with_deduction(p_order_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_item RECORD;
  v_recipe RECORD;
  v_ri RECORD;
  v_deduct NUMERIC;
BEGIN
  -- Lock the order row
  SELECT id, status INTO v_order
  FROM orders WHERE id = p_order_id FOR UPDATE;

  IF v_order IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF v_order.status NOT IN ('ready') THEN
    RAISE EXCEPTION 'Order must be in ready status to complete';
  END IF;

  -- Deduct ingredients per order item
  FOR v_item IN
    SELECT oi.id, oi.product_id, oi.quantity
    FROM order_items oi
    WHERE oi.order_id = p_order_id
  LOOP
    -- Find recipe for this product
    SELECT id INTO v_recipe
    FROM recipes
    WHERE product_id = v_item.product_id AND is_active = true
    LIMIT 1;

    IF v_recipe IS NULL THEN
      CONTINUE; -- No recipe = no ingredient deduction
    END IF;

    -- Deduct each ingredient
    FOR v_ri IN
      SELECT ri.ingredient_id, ri.qty
      FROM recipe_items ri
      WHERE ri.recipe_id = v_recipe.id
    LOOP
      v_deduct := v_ri.qty * v_item.quantity;

      -- Deduct from ingredients table
      UPDATE ingredients
      SET stock = stock - v_deduct,
          updated_at = now()
      WHERE id = v_ri.ingredient_id;

      -- Record movement
      INSERT INTO ingredient_movements (ingredient_id, outlet_id, type, qty, reference_type, reference_id, notes)
      SELECT v_ri.ingredient_id, o.outlet_id, 'order_deduction', -v_deduct, 'order', p_order_id,
             'Auto deduction from order ' || p_order_id
      FROM orders o
      WHERE o.id = p_order_id;
    END LOOP;
  END LOOP;

  -- Mark order as completed
  UPDATE orders
  SET status = 'completed',
      completed_at = now()
  WHERE id = p_order_id;
END;
$$;

-- 7. Indexes
CREATE INDEX idx_ingredients_sku ON ingredients(sku);
CREATE INDEX idx_ingredients_barcode ON ingredients(barcode);
CREATE INDEX idx_recipes_product ON recipes(product_id);
CREATE INDEX idx_recipe_items_recipe ON recipe_items(recipe_id);
CREATE INDEX idx_recipe_items_ingredient ON recipe_items(ingredient_id);
CREATE INDEX idx_ingredient_movements_ingredient ON ingredient_movements(ingredient_id);
