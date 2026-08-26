import { supabase } from "@/services/supabase";
import type { Order, OrderItem, OrderItemModifier } from "@/types";

export interface KdsOrder extends Order {
  order_items: (OrderItem & {
    order_item_modifiers?: OrderItemModifier[];
    product?: { name: string };
  })[];
}

export async function fetchKdsOrders(): Promise<KdsOrder[]> {
  const { data, error } = await supabase
    .from("orders")
    .select(`
      *,
      order_items (
        *,
        product:products(name),
        order_item_modifiers(*)
      )
    `)
    .in("status", ["confirmed", "preparing", "ready"])
    .order("created_at", { ascending: true });

  if (error) {
    console.error("fetchKdsOrders error:", error);
    return [];
  }

  return (data as KdsOrder[]) ?? [];
}
