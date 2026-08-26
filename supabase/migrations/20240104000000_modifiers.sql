-- ============================================
-- KopiPOS — Sprint 4: Modifiers + Order Item Modifiers
-- Migration: 20240104000000_modifiers.sql
-- ============================================

-- Modifier groups (e.g. Size, Milk Type, Extra Shot)
CREATE TABLE modifiers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name TEXT NOT NULL,           -- e.g. "Size", "Milk", "Sugar"
  required BOOLEAN DEFAULT false, -- must choose at least one option
  max_selections INTEGER DEFAULT 1, -- how many options can be selected
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Individual options within a modifier group
CREATE TABLE modifier_options (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  modifier_id UUID NOT NULL REFERENCES modifiers(id) ON DELETE CASCADE,
  name TEXT NOT NULL,           -- e.g. "Small", "Medium", "Large", "Oat Milk"
  price_adjustment NUMERIC(12,2) DEFAULT 0, -- +/− to base price
  is_default BOOLEAN DEFAULT false,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Link order_items to selected modifier_options
CREATE TABLE order_item_modifiers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_item_id UUID NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
  modifier_option_id UUID NOT NULL REFERENCES modifier_options(id) ON DELETE RESTRICT,
  price_adjustment NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_modifiers_product ON modifiers(product_id);
CREATE INDEX idx_modifier_options_modifier ON modifier_options(modifier_id);
CREATE INDEX idx_order_item_modifiers_item ON order_item_modifiers(order_item_id);

-- Updated_at triggers
CREATE TRIGGER trigger_modifiers_updated_at
  BEFORE UPDATE ON modifiers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_modifier_options_updated_at
  BEFORE UPDATE ON modifier_options
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- RLS POLICIES
-- ============================================

ALTER TABLE modifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE modifier_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_item_modifiers ENABLE ROW LEVEL SECURITY;

-- Modifiers: everyone can read, owner manages
CREATE POLICY "modifiers_select_all" ON modifiers FOR SELECT USING (true);
CREATE POLICY "modifiers_insert_owner" ON modifiers FOR INSERT WITH CHECK (auth.user_role() = 'owner');
CREATE POLICY "modifiers_update_owner" ON modifiers FOR UPDATE USING (auth.user_role() = 'owner');
CREATE POLICY "modifiers_delete_owner" ON modifiers FOR DELETE USING (auth.user_role() = 'owner');

-- Modifier options: everyone can read, owner manages
CREATE POLICY "modifier_options_select_all" ON modifier_options FOR SELECT USING (true);
CREATE POLICY "modifier_options_insert_owner" ON modifier_options FOR INSERT WITH CHECK (auth.user_role() = 'owner');
CREATE POLICY "modifier_options_update_owner" ON modifier_options FOR UPDATE USING (auth.user_role() = 'owner');
CREATE POLICY "modifier_options_delete_owner" ON modifier_options FOR DELETE USING (auth.user_role() = 'owner');

-- Order item modifiers: authenticated can read, authenticated can manage (cart operations)
CREATE POLICY "order_item_modifiers_select_auth" ON order_item_modifiers
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "order_item_modifiers_insert_auth" ON order_item_modifiers
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "order_item_modifiers_delete_auth" ON order_item_modifiers
  FOR DELETE USING (auth.role() = 'authenticated');
