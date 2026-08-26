import { supabase } from "@/services/supabase";
import type { PurchaseOrder, ApiResponse } from "@/types";

export async function getPOs(): Promise<ApiResponse<PurchaseOrder[]>> {
  const { data, error } = await supabase
    .from("purchase_orders")
    .select("*, supplier:suppliers(*), items:purchase_order_items(*, product:products(name, sku))")
    .order("created_at", { ascending: false });
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function getPO(id: string): Promise<ApiResponse<PurchaseOrder>> {
  const { data, error } = await supabase
    .from("purchase_orders")
    .select(
      "*, supplier:suppliers(*), items:purchase_order_items(*, product:products(name, sku, barcode))",
    )
    .eq("id", id)
    .single();
  if (error) return { data: null, error: error.message };
  return { data, error: null };
}

export async function createPO(
  supplierId: string,
  items: { product_id: string; expected_qty: number; unit_cost: number }[],
  notes?: string,
): Promise<{ success: boolean; id?: string; error?: string }> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const { data: orderNumber } = await supabase.rpc("generate_po_number");

  const { data: po, error: poError } = await supabase
    .from("purchase_orders")
    .insert({
      supplier_id: supplierId,
      order_number: orderNumber,
      notes: notes || null,
      created_by: user?.id,
    })
    .select("id")
    .single();

  if (poError) return { success: false, error: poError.message };

  const { error: itemsError } = await supabase
    .from("purchase_order_items")
    .insert(items.map((i) => ({ po_id: po.id, ...i })));

  if (itemsError) return { success: false, error: itemsError.message };
  return { success: true, id: po.id };
}

export async function approvePO(id: string): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc("approve_po", { p_po_id: id });
  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true };
}

export async function orderPO(id: string): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc("order_po", { p_po_id: id });
  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true };
}

export async function receivePO(
  poId: string,
  productId: string,
  qty: number,
  outletId: string,
): Promise<{ success: boolean; error?: string }> {
  const { data, error } = await supabase.rpc("receive_po", {
    p_po_id: poId,
    p_product_id: productId,
    p_qty: qty,
    p_outlet_id: outletId,
  });
  if (error) return { success: false, error: error.message };
  if (data?.error) return { success: false, error: data.error };
  return { success: true };
}
