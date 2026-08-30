<script setup lang="ts">
import { ref, onMounted } from "vue";
import { supabase } from "@/services/supabase";
import { useAuthStore } from "@/modules/auth/stores/auth";
import { Calendar } from "lucide-vue-next";

interface SaleRow {
  date: string;
  orders: number;
  revenue: number;
  avg: number;
}

const auth = useAuthStore();
const rows = ref<SaleRow[]>([]);
const loading = ref(false);
const dateFrom = ref(new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10));
const dateTo = ref(new Date().toISOString().slice(0, 10));

async function load() {
  loading.value = true;
  const isOwner = auth.user?.profile.role === "owner";
  const outletId = auth.user?.profile.outlet_id;

  let query = supabase
    .from("orders")
    .select("created_at, total")
    .gte("created_at", dateFrom.value)
    .lte("created_at", dateTo.value + "T23:59:59")
    .in("status", ["completed"]);

  // Non-owner users only see their outlet's data
  if (!isOwner && outletId) {
    query = query.eq("outlet_id", outletId);
  }

  const { data } = await query;

  const map = new Map<string, { orders: number; revenue: number }>();
  for (const o of data ?? []) {
    const d = o.created_at.slice(0, 10);
    const existing = map.get(d) ?? { orders: 0, revenue: 0 };
    existing.orders++;
    existing.revenue += o.total;
    map.set(d, existing);
  }

  rows.value = [...map.entries()]
    .sort(([a], [b]) => b.localeCompare(a))
    .map(([date, v]) => ({
      date,
      orders: v.orders,
      revenue: v.revenue,
      avg: v.orders > 0 ? Math.round(v.revenue / v.orders) : 0,
    }));

  loading.value = false;
}

function fmt(n: number) {
  return new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR", minimumFractionDigits: 0 }).format(n);
}

function exportCSV() {
  const header = "Date,Orders,Revenue,AOV\n";
  const body = rows.value.map((r) => `${r.date},${r.orders},${r.revenue},${r.avg}`).join("\n");
  const blob = new Blob([header + body], { type: "text/csv" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `sales-report-${dateFrom.value}-to-${dateTo.value}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}

onMounted(load);
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h2 class="text-lg font-semibold text-white">Sales Report</h2>
      <button
        class="rounded-lg border border-gray-600 px-3 py-2 text-sm text-gray-300 hover:bg-gray-700"
        @click="exportCSV"
      >
        Export CSV
      </button>
    </div>

    <div class="flex items-end gap-3 rounded-xl border border-gray-700 bg-gray-800 p-4">
      <div>
        <label class="mb-1 block text-xs text-gray-400">From</label>
        <input v-model="dateFrom" type="date" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" @change="load" />
      </div>
      <div>
        <label class="mb-1 block text-xs text-gray-400">To</label>
        <input v-model="dateTo" type="date" class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white" @change="load" />
      </div>
    </div>

    <div v-if="loading" class="py-12 text-center text-gray-500">Loading...</div>

    <div v-else class="rounded-xl border border-gray-700 bg-gray-800">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-gray-700 text-left text-gray-400">
            <th class="p-3">Date</th>
            <th class="p-3 text-right">Orders</th>
            <th class="p-3 text-right">Revenue</th>
            <th class="p-3 text-right">AOV</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in rows" :key="r.date" class="border-b border-gray-700/50 hover:bg-gray-700/30">
            <td class="p-3 text-white">{{ r.date }}</td>
            <td class="p-3 text-right text-gray-300">{{ r.orders }}</td>
            <td class="p-3 text-right text-white">{{ fmt(r.revenue) }}</td>
            <td class="p-3 text-right text-gray-400">{{ fmt(r.avg) }}</td>
          </tr>
          <tr v-if="rows.length === 0">
            <td colspan="4" class="p-6 text-center text-gray-500">
              <Calendar class="mx-auto mb-2 h-8 w-8" />
              No sales data for this period
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
