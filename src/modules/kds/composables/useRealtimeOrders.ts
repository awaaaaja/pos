import { ref, onMounted, onUnmounted } from "vue";
import { supabase } from "@/services/supabase";
import type { RealtimeChannel } from "@supabase/supabase-js";
import type { KdsOrder } from "@/modules/kds/services/order";

const orders = ref<KdsOrder[]>([]);
let channel: RealtimeChannel | null = null;

export function useRealtimeOrders() {
  async function loadOrders() {
    const { data } = await supabase
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

    orders.value = (data as KdsOrder[]) ?? [];
  }

  function subscribe() {
    channel = supabase
      .channel("kds-orders")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "orders" },
        () => {
          loadOrders();
        },
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "order_items" },
        () => {
          loadOrders();
        },
      )
      .subscribe();
  }

  function unsubscribe() {
    if (channel) {
      supabase.removeChannel(channel);
      channel = null;
    }
  }

  onMounted(() => {
    loadOrders();
    subscribe();
  });

  onUnmounted(() => {
    unsubscribe();
  });

  return { orders, loadOrders };
}
