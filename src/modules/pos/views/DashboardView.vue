<script setup lang="ts">
import { ref, onMounted } from "vue";
import {
  getDashboardMetrics,
  type DashboardMetrics,
} from "@/modules/reports/services/dashboard";
import { useAuthStore } from "@/modules/auth/stores/auth";
import {
  DollarSign,
  ShoppingCart,
  TrendingUp,
  AlertTriangle,
  CreditCard,
} from "lucide-vue-next";

const auth = useAuthStore();
const metrics = ref<DashboardMetrics | null>(null);
const loading = ref(true);

onMounted(async () => {
  // Owner sees all outlets, others see their outlet only
  const isOwner = auth.user?.profile.role === "owner";
  const outletId = isOwner ? undefined : auth.user?.profile.outlet_id ?? undefined;
  metrics.value = await getDashboardMetrics(outletId);
  loading.value = false;
});

function fmt(n: number) {
  return new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    minimumFractionDigits: 0,
  }).format(n);
}

const methodLabels: Record<string, string> = {
  cash: "Cash",
  qris: "QRIS",
  debit: "Debit",
  credit: "Credit",
  ewallet: "E-Wallet",
  transfer: "Transfer",
};
</script>

<template>
  <div class="space-y-6">
    <h2 class="text-lg font-semibold text-white">Dashboard</h2>

    <div v-if="loading" class="py-12 text-center text-gray-500">Loading metrics...</div>

    <template v-else-if="metrics">
      <!-- KPI Cards -->
      <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <div class="rounded-xl border border-gray-700 bg-gray-800 p-4">
          <div class="mb-2 flex items-center gap-2 text-gray-400">
            <DollarSign class="h-4 w-4" />
            <span class="text-xs font-medium">Revenue Today</span>
          </div>
          <p class="text-xl font-bold text-white">{{ fmt(metrics.revenueToday) }}</p>
        </div>
        <div class="rounded-xl border border-gray-700 bg-gray-800 p-4">
          <div class="mb-2 flex items-center gap-2 text-gray-400">
            <DollarSign class="h-4 w-4" />
            <span class="text-xs font-medium">Revenue Month</span>
          </div>
          <p class="text-xl font-bold text-white">{{ fmt(metrics.revenueMonth) }}</p>
        </div>
        <div class="rounded-xl border border-gray-700 bg-gray-800 p-4">
          <div class="mb-2 flex items-center gap-2 text-gray-400">
            <ShoppingCart class="h-4 w-4" />
            <span class="text-xs font-medium">Orders</span>
          </div>
          <p class="text-xl font-bold text-white">
            {{ metrics.ordersToday }} <span class="text-sm font-normal text-gray-400">today</span>
          </p>
          <p class="text-xs text-gray-500">{{ metrics.ordersMonth }} this month</p>
        </div>
        <div class="rounded-xl border border-gray-700 bg-gray-800 p-4">
          <div class="mb-2 flex items-center gap-2 text-gray-400">
            <TrendingUp class="h-4 w-4" />
            <span class="text-xs font-medium">AOV</span>
          </div>
          <p class="text-xl font-bold text-white">{{ fmt(metrics.aov) }}</p>
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-2">
        <!-- Top Products -->
        <div class="rounded-xl border border-gray-700 bg-gray-800 p-4">
          <h3 class="mb-3 text-sm font-medium text-gray-400">Top Products (Month)</h3>
          <div v-if="metrics.topProducts.length === 0" class="py-4 text-center text-sm text-gray-600">
            No sales data yet
          </div>
          <div v-else class="space-y-2">
            <div
              v-for="(p, i) in metrics.topProducts"
              :key="p.name"
              class="flex items-center justify-between text-sm"
            >
              <div class="flex items-center gap-2">
                <span class="w-5 text-right text-xs text-gray-500">{{ i + 1 }}.</span>
                <span class="text-white">{{ p.name }}</span>
              </div>
              <div class="text-right">
                <span class="text-gray-400">{{ p.qty }}x</span>
                <span class="ml-2 font-medium text-white">{{ fmt(p.revenue) }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Low Stock -->
        <div class="rounded-xl border border-gray-700 bg-gray-800 p-4">
          <h3 class="mb-3 flex items-center gap-1.5 text-sm font-medium text-gray-400">
            <AlertTriangle class="h-4 w-4 text-amber-500" />
            Low Stock
          </h3>
          <div v-if="metrics.lowStock.length === 0" class="py-4 text-center text-sm text-gray-600">
            All ingredients above minimum
          </div>
          <div v-else class="space-y-2">
            <div
              v-for="s in metrics.lowStock"
              :key="s.name"
              class="flex items-center justify-between text-sm"
            >
              <span class="text-white">{{ s.name }}</span>
              <span class="font-medium text-red-400">
                {{ s.stock }} <span class="text-gray-500">/ {{ s.minimum }}</span>
              </span>
            </div>
          </div>
        </div>

        <!-- Payment Breakdown -->
        <div class="rounded-xl border border-gray-700 bg-gray-800 p-4">
          <h3 class="mb-3 flex items-center gap-1.5 text-sm font-medium text-gray-400">
            <CreditCard class="h-4 w-4" />
            Payment Breakdown (Month)
          </h3>
          <div v-if="metrics.paymentBreakdown.length === 0" class="py-4 text-center text-sm text-gray-600">
            No payments yet
          </div>
          <div v-else class="space-y-2">
            <div
              v-for="p in metrics.paymentBreakdown"
              :key="p.method"
              class="flex items-center justify-between text-sm"
            >
              <span class="text-white">{{ methodLabels[p.method] ?? p.method }}</span>
              <div class="text-right">
                <span class="text-gray-400">{{ p.count }}x</span>
                <span class="ml-2 font-medium text-white">{{ fmt(p.total) }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
