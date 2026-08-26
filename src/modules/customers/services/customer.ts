import { supabase } from "@/services/supabase";
import type { Customer, ApiResponse } from "@/types";

export async function getCustomers(): Promise<ApiResponse<Customer[]>> {
  const { data, error } = await supabase
    .from("customers")
    .select("*")
    .eq("is_active", true)
    .order("name");
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function searchCustomers(query: string): Promise<ApiResponse<Customer[]>> {
  const { data, error } = await supabase
    .from("customers")
    .select("*")
    .eq("is_active", true)
    .or(`name.ilike.%${query}%,phone.ilike.%${query}%,email.ilike.%${query}%`)
    .order("name")
    .limit(10);
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function createCustomer(
  input: Omit<Customer, "id" | "created_at" | "updated_at" | "points" | "total_spending" | "is_active">,
): Promise<ApiResponse<Customer>> {
  const { data, error } = await supabase
    .from("customers")
    .insert({ ...input, phone: input.phone || null, email: input.email || null, birthday: input.birthday || null })
    .select()
    .single();
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function updateCustomer(
  id: string,
  input: Partial<Customer>,
): Promise<ApiResponse<Customer>> {
  const { data, error } = await supabase
    .from("customers")
    .update({ ...input, updated_at: new Date().toISOString() })
    .eq("id", id)
    .select()
    .single();
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function archiveCustomer(id: string): Promise<ApiResponse<null>> {
  const { error } = await supabase
    .from("customers")
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq("id", id);
  if (error) return { data: null, error: error.message };
  return { data: null, error: null };
}
