<script setup lang="ts">
import { ref } from "vue";
import { supabase } from "@/services/supabase";
import { Upload, CheckCircle, AlertTriangle, X } from "lucide-vue-next";

interface ParsedRow {
  sku: string;
  barcode: string;
  name: string;
  category: string;
  cost: number;
  price: number;
  stock: number;
  valid: boolean;
  error: string;
}

const step = ref<"upload" | "preview" | "done">("upload");
const rows = ref<ParsedRow[]>([]);
const importing = ref(false);

function parseCSV(text: string): ParsedRow[] {
  const lines = text.trim().split("\n");
  if (lines.length < 2) return [];

  return lines.slice(1).map((line) => {
    const cols = line.split(",").map((c) => c.trim());
    const sku = cols[0] ?? "";
    const barcode = cols[1] ?? "";
    const name = cols[2] ?? "";
    const category = cols[3] ?? "";
    const cost = parseFloat(cols[4]) || 0;
    const price = parseFloat(cols[5]) || 0;
    const stock = parseFloat(cols[6]) || 0;

    const errors: string[] = [];
    if (!sku) errors.push("SKU required");
    if (!name) errors.push("Name required");
    if (price <= 0) errors.push("Price must be > 0");

    return { sku, barcode, name, category, cost, price, stock, valid: errors.length === 0, error: errors.join("; ") };
  });
}

function onFileChange(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    rows.value = parseCSV(reader.result as string);
    step.value = "preview";
  };
  reader.readAsText(file);
}

async function handleImport() {
  importing.value = true;
  const validRows = rows.value.filter((r) => r.valid);

  // Get or create default category
  let categoryId: string | null = null;
  const { data: existingCat } = await supabase
    .from("categories")
    .select("id")
    .eq("name", "Imported")
    .limit(1)
    .maybeSingle();
  categoryId = existingCat?.id;
  if (!categoryId) {
    const { data: newCat } = await supabase
      .from("categories")
      .insert({ name: "Imported", is_active: true })
      .select("id")
      .single();
    categoryId = newCat?.id;
  }

  for (const row of validRows) {
    const { data: product } = await supabase
      .from("products")
      .insert({
        sku: row.sku,
        barcode: row.barcode || null,
        name: row.name,
        category_id: categoryId,
        cost_price: row.cost,
        selling_price: row.price,
        is_active: true,
        track_inventory: true,
      })
      .select("id")
      .single();

    if (product) {
      const outlet = await supabase.from("outlets").select("id").limit(1).single();
      if (outlet.data) {
        await supabase.from("inventory").insert({
          product_id: product.id,
          outlet_id: outlet.data.id,
          qty: row.stock,
        });
      }
    }
  }

  importing.value = false;
  step.value = "done";
}

function reset() {
  step.value = "upload";
  rows.value = [];
}

const validCount = rows.value.filter((r) => r.valid).length;
const errorCount = rows.value.filter((r) => !r.valid).length;
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h2 class="text-lg font-semibold text-white">Import Products</h2>
      <button v-if="step !== 'upload'" class="text-sm text-gray-400 hover:text-white" @click="reset">
        Start Over
      </button>
    </div>

    <!-- Step 1: Upload -->
    <div v-if="step === 'upload'" class="rounded-xl border-2 border-dashed border-gray-700 bg-gray-800 p-8 text-center">
      <Upload class="mx-auto mb-3 h-10 w-10 text-gray-500" />
      <p class="mb-2 text-sm text-gray-400">Upload CSV with columns:</p>
      <p class="mb-4 font-mono text-xs text-gray-500">SKU, Barcode, Name, Category, Cost, Price, Stock</p>
      <label class="cursor-pointer rounded-lg bg-amber-600 px-4 py-2 text-sm font-medium text-white hover:bg-amber-500">
        Choose CSV File
        <input type="file" accept=".csv" class="hidden" @change="onFileChange" />
      </label>
    </div>

    <!-- Step 2: Preview -->
    <div v-if="step === 'preview'" class="space-y-4">
      <div class="flex gap-3">
        <span class="rounded-full bg-emerald-500/20 px-3 py-1 text-xs text-emerald-400">
          <CheckCircle class="mr-1 inline h-3 w-3" /> {{ validCount }} valid
        </span>
        <span v-if="errorCount > 0" class="rounded-full bg-red-500/20 px-3 py-1 text-xs text-red-400">
          <AlertTriangle class="mr-1 inline h-3 w-3" /> {{ errorCount }} errors
        </span>
      </div>

      <div class="max-h-[400px] overflow-y-auto rounded-xl border border-gray-700 bg-gray-800">
        <table class="w-full text-sm">
          <thead class="sticky top-0 bg-gray-800">
            <tr class="border-b border-gray-700 text-left text-gray-400">
              <th class="p-2">SKU</th>
              <th class="p-2">Name</th>
              <th class="p-2 text-right">Price</th>
              <th class="p-2 text-right">Stock</th>
              <th class="p-2">Status</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(r, i) in rows"
              :key="i"
              class="border-b border-gray-700/50"
              :class="r.valid ? '' : 'bg-red-500/5'"
            >
              <td class="p-2 font-mono text-xs text-gray-300">{{ r.sku }}</td>
              <td class="p-2 text-white">{{ r.name }}</td>
              <td class="p-2 text-right text-gray-300">{{ r.price.toLocaleString() }}</td>
              <td class="p-2 text-right text-gray-300">{{ r.stock }}</td>
              <td class="p-2">
                <span v-if="r.valid" class="text-xs text-emerald-400">OK</span>
                <span v-else class="text-xs text-red-400" :title="r.error">Error</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <button
        :disabled="validCount === 0 || importing"
        class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-500 disabled:opacity-40"
        @click="handleImport"
      >
        {{ importing ? "Importing..." : `Import ${validCount} Products` }}
      </button>
    </div>

    <!-- Step 3: Done -->
    <div v-if="step === 'done'" class="rounded-xl border border-gray-700 bg-gray-800 p-8 text-center">
      <CheckCircle class="mx-auto mb-3 h-10 w-10 text-emerald-400" />
      <p class="text-lg font-semibold text-white">Import Complete</p>
      <p class="mt-1 text-sm text-gray-400">{{ validCount }} products imported successfully</p>
      <button class="mt-4 rounded-lg bg-amber-600 px-4 py-2 text-sm font-medium text-white hover:bg-amber-500" @click="reset">
        Import More
      </button>
    </div>
  </div>
</template>
