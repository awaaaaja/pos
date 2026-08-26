<script setup lang="ts">
import { ref, onMounted } from "vue";
import { CircleCheck } from "lucide-vue-next";
import { supabase } from "@/services/supabase";
import { useAuthStore } from "@/modules/auth/stores/auth";
import type { Product } from "@/types";

const auth = useAuthStore();
const products = ref<Product[]>([]);
const loading = ref(false);
const outletId = ref("");

interface OpnameItem {
  product_id: string;
  product_name: string;
  system_qty: number;
  actual_qty: number;
}
const opnameItems = ref<OpnameItem[]>([]);
const notes = ref("");
const showResult = ref(false);
const resultText = ref("");

onMounted(async () => {
  outletId.value = auth.user?.profile.outlet_id || "";
  // Owner may not have outlet_id — fetch first available outlet
  if (!outletId.value) {
    const { data: outlets } = await supabase.from("outlets").select("id").limit(1);
    outletId.value = outlets?.[0]?.id || "";
  }
  loading.value = true;
  const { data } = await supabase.from("products").select("*").eq("is_active", true).order("name");
  products.value = data ?? [];

  // Get current stock for each product
  for (const p of products.value) {
    const { data: inv } = await supabase
      .from("inventory")
      .select("qty")
      .eq("product_id", p.id)
      .eq("outlet_id", outletId.value)
      .maybeSingle();
    opnameItems.value.push({
      product_id: p.id,
      product_name: p.name,
      system_qty: inv?.qty ?? 0,
      actual_qty: 0,
    });
  }
  loading.value = false;
});

async function handleConfirm() {
  if (!outletId.value) return;
  const diffItems = opnameItems.value.filter((i) => i.actual_qty !== i.system_qty);
  if (diffItems.length === 0) {
    alert("No differences to record");
    return;
  }

  // Create opname
  const { data: opname, error: opErr } = await supabase
    .from("stock_opnames")
    .insert({ outlet_id: outletId.value, notes: notes.value || null, created_by: auth.user?.id })
    .select("id")
    .single();

  if (opErr || !opname) {
    alert(opErr?.message || "Failed");
    return;
  }

  // Insert items
  const items = diffItems.map((i) => ({
    opname_id: opname.id,
    product_id: i.product_id,
    system_qty: i.system_qty,
    actual_qty: i.actual_qty,
  }));
  await supabase.from("stock_opname_items").insert(items);

  // Confirm
  const { data: rpcResult, error: rpcErr } = await supabase.rpc("confirm_stock_opname", {
    p_opname_id: opname.id,
  });
  if (rpcErr || rpcResult?.error) {
    alert(rpcErr?.message || rpcResult?.error);
    return;
  }

  resultText.value = `${diffItems.length} item(s) adjusted`;
  showResult.value = true;
}

function formatQty(n: number) {
  return n.toLocaleString("id-ID", { minimumFractionDigits: 0 });
}
</script>

<template>
  <div class="mx-auto max-w-4xl py-6">
    <h2 class="mb-6 text-2xl font-semibold">Stock Opname</h2>

    <div v-if="loading" class="py-12 text-center text-secondary">Loading inventory...</div>

    <template v-else>
      <div class="mb-4 rounded-2xl border bg-surface p-4">
        <p class="text-sm text-secondary">
          Record actual stock count. Products with differences will be adjusted.
        </p>
      </div>

      <div class="mb-4 overflow-x-auto rounded-2xl border bg-surface">
        <table class="w-full text-left text-sm">
          <thead class="border-b bg-gray-50 text-xs text-secondary">
            <tr>
              <th class="px-4 py-2">Product</th>
              <th class="px-4 py-2 text-right">System Qty</th>
              <th class="px-4 py-2 text-right">Actual Qty</th>
              <th class="px-4 py-2 text-right">Difference</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-for="item in opnameItems" :key="item.product_id" class="hover:bg-gray-50">
              <td class="px-4 py-2 font-medium">{{ item.product_name }}</td>
              <td class="px-4 py-2 text-right text-secondary">{{ formatQty(item.system_qty) }}</td>
              <td class="px-4 py-2 text-right">
                <input
                  v-model.number="item.actual_qty"
                  type="number"
                  min="0"
                  class="w-24 rounded border px-2 py-1 text-right text-sm focus:border-primary focus:outline-none"
                />
              </td>
              <td class="px-4 py-2 text-right">
                <span
                  :class="
                    item.actual_qty - item.system_qty === 0
                      ? 'text-secondary'
                      : item.actual_qty > item.system_qty
                        ? 'text-green-700'
                        : 'text-danger'
                  "
                  class="font-medium"
                >
                  {{ item.actual_qty - item.system_qty > 0 ? "+" : ""
                  }}{{ formatQty(item.actual_qty - item.system_qty) }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="flex items-center justify-between">
        <input
          v-model="notes"
          type="text"
          placeholder="Notes (optional)"
          class="w-64 rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
        />
        <button
          class="rounded-lg bg-primary px-6 py-2 text-sm font-medium text-white hover:opacity-90"
          @click="handleConfirm"
        >
          Confirm Opname
        </button>
      </div>
    </template>

    <Teleport to="body">
      <div
        v-if="showResult"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="showResult = false"
      >
        <div class="w-full max-w-sm rounded-2xl bg-surface p-6 text-center shadow-lg">
          <CircleCheck :size="40" :stroke-width="1.5" class="mx-auto mb-2 text-success" />
          <p class="text-lg font-semibold">Opname Complete</p>
          <p class="mb-4 text-sm text-secondary">{{ resultText }}</p>
          <button
            class="rounded-lg bg-primary px-6 py-2 text-sm font-medium text-white hover:opacity-90"
            @click="
              showResult = false;
              opnameItems = [];
            "
          >
            OK
          </button>
        </div>
      </div>
    </Teleport>
  </div>
</template>
