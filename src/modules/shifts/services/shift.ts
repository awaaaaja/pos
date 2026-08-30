import { supabase } from "@/services/supabase";
import type { ApiResponse, Shift, CashMovement, CashMovementType } from "@/types";

export async function getOpenShift(cashierId: string, outletId?: string): Promise<ApiResponse<Shift>> {
  let query = supabase
    .from("shifts")
    .select("*")
    .eq("cashier_id", cashierId)
    .eq("status", "open");

  if (outletId) {
    query = query.eq("outlet_id", outletId);
  }

  const { data, error } = await query.limit(1).maybeSingle();

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function openShift(
  outletId: string,
  cashierId: string,
  openingCash: number,
): Promise<{ success: boolean; shift_id?: string; error?: string }> {
  const { data, error } = await supabase.rpc("open_shift", {
    p_outlet_id: outletId,
    p_cashier_id: cashierId,
    p_opening_cash: openingCash,
  });

  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true, shift_id: data.shift_id };
}

export async function closeShift(
  shiftId: string,
  closingCash: number,
): Promise<{ success: boolean; expected_cash?: number; difference?: number; error?: string }> {
  const { data, error } = await supabase.rpc("close_shift", {
    p_shift_id: shiftId,
    p_closing_cash: closingCash,
  });

  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return {
    success: true,
    expected_cash: data.expected_cash,
    difference: data.difference,
  };
}

export async function recordCashMovement(
  shiftId: string,
  type: CashMovementType,
  amount: number,
  reference?: string,
  description?: string,
): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc("record_cash_movement", {
    p_shift_id: shiftId,
    p_type: type,
    p_amount: amount,
    p_reference: reference || null,
    p_description: description || null,
  });

  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true };
}

export async function getCashMovements(shiftId: string): Promise<ApiResponse<CashMovement[]>> {
  const { data, error } = await supabase
    .from("cash_movements")
    .select("*")
    .eq("shift_id", shiftId)
    .order("created_at", { ascending: true });

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function getShiftHistory(outletId: string, limit = 20): Promise<ApiResponse<Shift[]>> {
  const { data, error } = await supabase
    .from("shifts")
    .select("*")
    .eq("outlet_id", outletId)
    .order("opened_at", { ascending: false })
    .limit(limit);

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}
