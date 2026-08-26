import { supabase } from "@/services/supabase";
import type { Expense, ApiResponse } from "@/types";

export async function getExpenses(limit = 50): Promise<ApiResponse<Expense[]>> {
  const { data, error } = await supabase
    .from("expenses")
    .select("*")
    .order("date", { ascending: false })
    .limit(limit);
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function createExpense(input: {
  category: string;
  amount: number;
  description?: string;
  date: string;
  attachment_url?: string;
}): Promise<ApiResponse<Expense>> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const { data, error } = await supabase
    .from("expenses")
    .insert({ ...input, created_by: user?.id })
    .select()
    .single();
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function deleteExpense(id: string): Promise<ApiResponse<null>> {
  const { error } = await supabase.from("expenses").delete().eq("id", id);
  if (error) return { data: null, error: error.message };
  return { data: null, error: null };
}
