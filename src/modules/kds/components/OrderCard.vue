<script setup lang="ts">
import { computed } from "vue";
import type { KdsOrder } from "@/modules/kds/services/order";

const props = defineProps<{
  order: KdsOrder;
}>();

const emit = defineEmits<{
  start: [orderId: string];
  ready: [orderId: string];
}>();

const elapsed = computed(() => {
  const created = new Date(props.order.created_at).getTime();
  const now = Date.now();
  const diff = Math.floor((now - created) / 1000);
  const m = Math.floor(diff / 60);
  const s = diff % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
});

function itemName(item: KdsOrder["order_items"][0]) {
  return item.product?.name ?? "Item";
}

function itemModifiers(item: KdsOrder["order_items"][0]) {
  return item.order_item_modifiers
    ?.map((m) => m.modifier_option_id)
    .filter(Boolean)
    .join(", ") ?? "";
}
</script>

<template>
  <div class="rounded-xl border border-gray-700 bg-gray-800 p-4">
    <div class="mb-3 flex items-center justify-between">
      <span class="text-sm font-bold text-white">
        {{ order.invoice_number || order.id.slice(0, 8) }}
      </span>
      <span
        class="rounded-full px-2 py-0.5 text-xs font-medium"
        :class="{
          'bg-blue-500/20 text-blue-300': order.status === 'confirmed',
          'bg-amber-500/20 text-amber-300': order.status === 'preparing',
          'bg-emerald-500/20 text-emerald-300': order.status === 'ready',
        }"
      >
        {{ elapsed }}
      </span>
    </div>

    <div class="mb-3 space-y-1.5">
      <div
        v-for="item in order.order_items"
        :key="item.id"
        class="flex items-start justify-between text-sm"
      >
        <div class="flex-1">
          <span class="font-medium text-white">{{ item.quantity }}x {{ itemName(item) }}</span>
          <p v-if="itemModifiers(item)" class="text-xs text-gray-400">{{ itemModifiers(item) }}</p>
          <p v-if="item.notes" class="text-xs text-amber-400/80">{{ item.notes }}</p>
        </div>
      </div>
    </div>

    <p v-if="order.notes" class="mb-3 text-xs text-amber-400/80">{{ order.notes }}</p>

    <div class="flex gap-2">
      <button
        v-if="order.status === 'confirmed'"
        class="flex-1 rounded-lg bg-blue-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-blue-500 active:scale-[0.97]"
        @click="emit('start', order.id)"
      >
        START
      </button>
      <button
        v-if="order.status === 'preparing'"
        class="flex-1 rounded-lg bg-emerald-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-emerald-500 active:scale-[0.97]"
        @click="emit('ready', order.id)"
      >
        READY
      </button>
      <span
        v-if="order.status === 'ready'"
        class="flex-1 rounded-lg bg-emerald-900/50 px-3 py-2 text-center text-xs font-semibold text-emerald-300"
      >
        DONE
      </span>
    </div>
  </div>
</template>
