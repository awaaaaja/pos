import { supabase } from "@/services/supabase";
import type { TableStatus, ApiResponse } from "@/types";

interface TableRecord {
  id: string;
  outlet_id: string;
  number: string;
  capacity: number;
  status: TableStatus;
  created_at: string;
  updated_at: string;
}

export async function getTables(): Promise<ApiResponse<TableRecord[]>> {
  const { data, error } = await supabase.from("tables").select("*").order("number");

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function createTable(
  input: Pick<TableRecord, "outlet_id" | "number" | "capacity">,
): Promise<ApiResponse<TableRecord>> {
  const { data, error } = await supabase
    .from("tables")
    .insert({ ...input, status: "available" })
    .select()
    .single();

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function updateTable(
  id: string,
  input: Partial<Pick<TableRecord, "number" | "capacity" | "status">>,
): Promise<ApiResponse<TableRecord>> {
  const { data, error } = await supabase
    .from("tables")
    .update(input)
    .eq("id", id)
    .select()
    .single();

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function deleteTable(id: string): Promise<ApiResponse<null>> {
  const { error } = await supabase.from("tables").delete().eq("id", id);
  if (error) return { data: null, error: error.message };
  return { data: null, error: null };
}

export async function transferTable(
  fromTableId: string,
  toTableId: string,
): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc("transfer_table", {
    p_from_table_id: fromTableId,
    p_to_table_id: toTableId,
  });

  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true };
}

export type { TableRecord };
