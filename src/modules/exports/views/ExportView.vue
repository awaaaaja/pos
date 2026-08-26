<script setup lang="ts">
import { ref } from "vue";
import { supabase } from "@/services/supabase";
import { Download } from "lucide-vue-next";

type Entity = "products" | "customers" | "orders" | "expenses" | "ingredients";
const entity = ref<Entity>("products");
const loading = ref(false);

const entities: { value: Entity; label: string }[] = [
  { value: "products", label: "Products" },
  { value: "customers", label: "Customers" },
  { value: "orders", label: "Orders" },
  { value: "expenses", label: "Expenses" },
  { value: "ingredients", label: "Ingredients" },
];

function toCSV(headers: string[], rows: (string | number | null)[][]): string {
  const escape = (v: string | number | null) => {
    if (v === null || v === undefined) return "";
    const s = String(v);
    return s.includes(",") || s.includes('"') || s.includes("\n")
      ? `"${s.replace(/"/g, '""')}"`
      : s;
  };
  return [headers.join(","), ...rows.map((r) => r.map(escape).join(","))].join("\n");
}

function download(csv: string, filename: string) {
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

async function handleExport() {
  loading.value = true;
  const today = new Date().toISOString().slice(0, 10);

  if (entity.value === "products") {
    const { data } = await supabase.from("products").select("sku, barcode, name, selling_price, cost_price, is_active").order("name");
    const rows = (data ?? []).map((r) => [r.sku, r.barcode, r.name, r.selling_price, r.cost_price, r.is_active]);
    download(toCSV(["SKU", "Barcode", "Name", "Price", "Cost", "Active"], rows), `products-${today}.csv`);
  } else if (entity.value === "customers") {
    const { data } = await supabase.from("customers").select("name, phone, email, points, total_spending").order("name");
    const rows = (data ?? []).map((r) => [r.name, r.phone, r.email, r.points, r.total_spending]);
    download(toCSV(["Name", "Phone", "Email", "Points", "Total Spending"], rows), `customers-${today}.csv`);
  } else if (entity.value === "orders") {
    const { data } = await supabase.from("orders").select("invoice_number, status, total, created_at").order("created_at", { ascending: false }).limit(1000);
    const rows = (data ?? []).map((r) => [r.invoice_number, r.status, r.total, r.created_at]);
    download(toCSV(["Invoice", "Status", "Total", "Date"], rows), `orders-${today}.csv`);
  } else if (entity.value === "expenses") {
    const { data } = await supabase.from("expenses").select("category, amount, description, date").order("date", { ascending: false });
    const rows = (data ?? []).map((r) => [r.category, r.amount, r.description, r.date]);
    download(toCSV(["Category", "Amount", "Description", "Date"], rows), `expenses-${today}.csv`);
  } else if (entity.value === "ingredients") {
    const { data } = await supabase.from("ingredients").select("sku, name, unit, stock, minimum_stock, cost").eq("is_active", true).order("name");
    const rows = (data ?? []).map((r) => [r.sku, r.name, r.unit, r.stock, r.minimum_stock, r.cost]);
    download(toCSV(["SKU", "Name", "Unit", "Stock", "Min Stock", "Cost"], rows), `ingredients-${today}.csv`);
  }

  loading.value = false;
}
</script>

<template>
  <div class="space-y-4">
    <h2 class="text-lg font-semibold text-white">Export Data</h2>

    <div class="rounded-xl border border-gray-700 bg-gray-800 p-6">
      <p class="mb-4 text-sm text-gray-400">Select data to export as CSV:</p>

      <div class="mb-4 grid grid-cols-2 gap-2 sm:grid-cols-3">
        <button
          v-for="e in entities"
          :key="e.value"
          class="rounded-lg border px-4 py-3 text-sm font-medium transition"
          :class="
            entity === e.value
              ? 'border-amber-500 bg-amber-500/10 text-amber-400'
              : 'border-gray-600 text-gray-400 hover:border-gray-500 hover:text-white'
          "
          @click="entity = e.value"
        >
          {{ e.label }}
        </button>
      </div>

      <button
        :disabled="loading"
        class="flex items-center gap-2 rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-500 disabled:opacity-40"
        @click="handleExport"
      >
        <Download class="h-4 w-4" />
        {{ loading ? "Exporting..." : `Export ${entity}` }}
      </button>
    </div>
  </div>
</template>
