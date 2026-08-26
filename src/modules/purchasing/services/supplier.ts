import { supabase } from "@/services/supabase";
import type { Supplier, ApiResponse } from "@/types";

export async function getSuppliers(): Promise<ApiResponse<Supplier[]>> {
  const { data, error } = await supabase.from("suppliers").select("*").order("name");
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function createSupplier(
  input: Omit<Supplier, "id" | "created_at" | "updated_at" | "is_active">,
): Promise<ApiResponse<Supplier>> {
  const { data, error } = await supabase
    .from("suppliers")
    .insert({ ...input, is_active: true })
    .select()
    .single();
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function updateSupplier(
  id: string,
  input: Partial<Supplier>,
): Promise<ApiResponse<Supplier>> {
  const { data, error } = await supabase
    .from("suppliers")
    .update(input)
    .eq("id", id)
    .select()
    .single();
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function deleteSupplier(id: string): Promise<ApiResponse<null>> {
  const { error } = await supabase.from("suppliers").delete().eq("id", id);
  if (error) return { data: null, error: error.message };
  return { data: null, error: null };
}
