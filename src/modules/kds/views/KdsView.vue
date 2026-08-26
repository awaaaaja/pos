<script setup lang="ts">
import { computed } from "vue";
import { useRealtimeOrders } from "@/modules/kds/composables/useRealtimeOrders";
import { supabase } from "@/services/supabase";
import OrderCard from "@/modules/kds/components/OrderCard.vue";

const { orders } = useRealtimeOrders();

const newOrders = computed(() => orders.value.filter((o) => o.status === "confirmed"));
const preparingOrders = computed(() => orders.value.filter((o) => o.status === "preparing"));
const readyOrders = computed(() => orders.value.filter((o) => o.status === "ready"));

async function startPreparing(orderId: string) {
  await supabase.rpc("start_preparing", { p_order_id: orderId });
}

async function markReady(orderId: string) {
  await supabase.rpc("mark_ready", { p_order_id: orderId });
}
</script>

<template>
  <div class="grid h-full grid-cols-3 gap-4">
    <div class="flex flex-col overflow-hidden">
      <h3 class="mb-3 text-sm font-medium uppercase text-gray-400">
        NEW <span class="ml-1 text-gray-600">({{ newOrders.length }})</span>
      </h3>
      <div class="flex-1 space-y-3 overflow-y-auto pr-1">
        <OrderCard
          v-for="order in newOrders"
          :key="order.id"
          :order="order"
          @start="startPreparing"
        />
        <p v-if="newOrders.length === 0" class="text-sm text-gray-600">No orders</p>
      </div>
    </div>

    <div class="flex flex-col overflow-hidden">
      <h3 class="mb-3 text-sm font-medium uppercase text-gray-400">
        PREPARING <span class="ml-1 text-gray-600">({{ preparingOrders.length }})</span>
      </h3>
      <div class="flex-1 space-y-3 overflow-y-auto pr-1">
        <OrderCard
          v-for="order in preparingOrders"
          :key="order.id"
          :order="order"
          @ready="markReady"
        />
        <p v-if="preparingOrders.length === 0" class="text-sm text-gray-600">No orders</p>
      </div>
    </div>

    <div class="flex flex-col overflow-hidden">
      <h3 class="mb-3 text-sm font-medium uppercase text-gray-400">
        READY <span class="ml-1 text-gray-600">({{ readyOrders.length }})</span>
      </h3>
      <div class="flex-1 space-y-3 overflow-y-auto pr-1">
        <OrderCard
          v-for="order in readyOrders"
          :key="order.id"
          :order="order"
        />
        <p v-if="readyOrders.length === 0" class="text-sm text-gray-600">No orders</p>
      </div>
    </div>
  </div>
</template>
