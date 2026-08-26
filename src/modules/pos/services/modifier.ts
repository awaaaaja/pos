import { supabase } from "@/services/supabase";
import type { ModifierWithOptions, ApiResponse } from "@/types";

/**
 * Get all modifiers with their options for a product
 */
export async function getModifiersByProduct(
  productId: string,
): Promise<ApiResponse<ModifierWithOptions[]>> {
  const { data, error } = await supabase
    .from("modifiers")
    .select("*, modifier_options(*)")
    .eq("product_id", productId)
    .order("sort_order");

  if (error) return { data: null, error: error.message };

  // Sort options within each modifier
  const modifiers = (data ?? []).map((m) => ({
    ...m,
    modifier_options: m.modifier_options
      .filter((o: { is_active: boolean }) => o.is_active)
      .sort((a: { sort_order: number }, b: { sort_order: number }) => a.sort_order - b.sort_order),
  }));

  return { data: modifiers, error: null };
}

/**
 * Get all modifiers (admin view)
 */
export async function getAllModifiers(): Promise<ApiResponse<ModifierWithOptions[]>> {
  const { data, error } = await supabase
    .from("modifiers")
    .select("*, modifier_options(*)")
    .order("sort_order");

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}
