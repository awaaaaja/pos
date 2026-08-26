import { supabase } from "@/services/supabase";
import type { Promo, Coupon, ApiResponse } from "@/types";

export async function getPromos(): Promise<ApiResponse<Promo[]>> {
  const { data, error } = await supabase
    .from("promos")
    .select("*")
    .order("created_at", { ascending: false });
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function createPromo(
  input: Omit<Promo, "id" | "created_at" | "updated_at" | "is_active">,
): Promise<ApiResponse<Promo>> {
  const { data, error } = await supabase
    .from("promos")
    .insert(input)
    .select()
    .single();
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function updatePromo(id: string, input: Partial<Promo>): Promise<ApiResponse<Promo>> {
  const { data, error } = await supabase
    .from("promos")
    .update({ ...input, updated_at: new Date().toISOString() })
    .eq("id", id)
    .select()
    .single();
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function deletePromo(id: string): Promise<ApiResponse<null>> {
  const { error } = await supabase.from("promos").delete().eq("id", id);
  if (error) return { data: null, error: error.message };
  return { data: null, error: null };
}

export async function getCoupons(): Promise<ApiResponse<Coupon[]>> {
  const { data, error } = await supabase
    .from("coupons")
    .select("*, promo:promos(name, type)")
    .order("created_at", { ascending: false });
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function createCoupon(
  input: Omit<Coupon, "id" | "created_at" | "used_count" | "is_active">,
): Promise<ApiResponse<Coupon>> {
  const { data, error } = await supabase
    .from("coupons")
    .insert({ ...input, code: input.code.toUpperCase() })
    .select()
    .single();
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function deleteCoupon(id: string): Promise<ApiResponse<null>> {
  const { error } = await supabase.from("coupons").delete().eq("id", id);
  if (error) return { data: null, error: error.message };
  return { data: null, error: null };
}
