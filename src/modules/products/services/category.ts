import { supabase } from "@/services/supabase";
import type { Category, ApiResponse } from "@/types";

export async function getCategories(): Promise<ApiResponse<Category[]>> {
  const { data, error } = await supabase
    .from("categories")
    .select("*")
    .order("sort_order", { ascending: true });

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function getActiveCategories(): Promise<ApiResponse<Category[]>> {
  const { data, error } = await supabase
    .from("categories")
    .select("*")
    .eq("is_active", true)
    .order("sort_order", { ascending: true });

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function createCategory(
  input: Pick<Category, "name" | "description" | "sort_order">,
): Promise<ApiResponse<Category>> {
  const { data, error } = await supabase.from("categories").insert(input).select().single();

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function updateCategory(
  id: string,
  input: Partial<Pick<Category, "name" | "description" | "sort_order" | "is_active">>,
): Promise<ApiResponse<Category>> {
  const { data, error } = await supabase
    .from("categories")
    .update(input)
    .eq("id", id)
    .select()
    .single();

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function archiveCategory(id: string): Promise<ApiResponse<Category>> {
  return updateCategory(id, { is_active: false });
}

export async function restoreCategory(id: string): Promise<ApiResponse<Category>> {
  return updateCategory(id, { is_active: true });
}

export async function deleteCategory(id: string): Promise<ApiResponse<null>> {
  const { error } = await supabase.from("categories").delete().eq("id", id);
  if (error) return { data: null, error: error.message };
  return { data: null, error: null };
}
