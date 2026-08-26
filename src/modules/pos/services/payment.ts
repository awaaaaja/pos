import { supabase } from "@/services/supabase";
import type { PaymentMethod, ApiResponse } from "@/types";

export interface PaymentRecord {
  id: string;
  order_id: string;
  method: PaymentMethod;
  amount: number;
  reference_number: string | null;
  status: string;
  paid_at: string;
  created_at: string;
}

export async function createPayment(
  orderId: string,
  method: PaymentMethod,
  amount: number,
  referenceNumber?: string,
): Promise<ApiResponse<PaymentRecord>> {
  const { data, error } = await supabase
    .from("payments")
    .insert({
      order_id: orderId,
      method,
      amount,
      reference_number: referenceNumber || null,
      status: "completed",
    })
    .select()
    .single();

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function getPaymentsByOrder(orderId: string): Promise<ApiResponse<PaymentRecord[]>> {
  const { data, error } = await supabase
    .from("payments")
    .select("*")
    .eq("order_id", orderId)
    .order("paid_at", { ascending: true });

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

// RPC wrappers for order state machine

export async function confirmOrder(
  orderId: string,
  tableId?: string,
): Promise<{ success: boolean; invoice_number?: string; error?: string }> {
  const { data, error } = await supabase.rpc("confirm_order", {
    p_order_id: orderId,
    p_table_id: tableId || null,
  });

  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true, invoice_number: data.invoice_number };
}

export async function cancelOrder(orderId: string): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc("cancel_order", {
    p_order_id: orderId,
  });

  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true };
}

export async function completeOrder(
  orderId: string,
): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc("complete_order", {
    p_order_id: orderId,
  });

  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true };
}

export async function voidOrder(
  orderId: string,
  reason: string,
  approvedBy: string,
): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc("void_order", {
    p_order_id: orderId,
    p_reason: reason,
    p_approved_by: approvedBy,
  });

  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true };
}

export async function startPreparing(
  orderId: string,
): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc("start_preparing", {
    p_order_id: orderId,
  });

  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true };
}

export async function markReady(orderId: string): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc("mark_ready", {
    p_order_id: orderId,
  });

  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true };
}

export async function refundOrder(
  orderId: string,
  reason: string,
  approvedBy: string,
): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc("refund_order", {
    p_order_id: orderId,
    p_reason: reason,
    p_approved_by: approvedBy,
  });

  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true };
}

export async function getOrderWithItems(
  orderId: string,
): Promise<ApiResponse<Record<string, unknown>>> {
  const { data, error } = await supabase
    .from("orders")
    .select(
      "*, order_items(*, product:products(name), order_item_modifiers(*, modifier_option:modifier_options(name)))",
    )
    .eq("id", orderId)
    .single();

  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export type { PaymentMethod };
