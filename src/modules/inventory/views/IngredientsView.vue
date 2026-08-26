<script setup lang="ts">
import { ref, onMounted } from "vue";
import { fetchIngredients, createIngredient, archiveIngredient } from "@/modules/inventory/services/ingredient";
import type { Ingredient, IngredientUnit } from "@/types";
import { Package, Plus, X } from "lucide-vue-next";

const ingredients = ref<Ingredient[]>([]);
const showForm = ref(false);
const form = ref({
  name: "",
  sku: "",
  barcode: "",
  unit: "pcs" as IngredientUnit,
  minimum_stock: 0,
  cost: 0,
});

const units: IngredientUnit[] = ["g", "kg", "ml", "L", "pcs", "pack"];

async function load() {
  ingredients.value = await fetchIngredients();
}

async function submit() {
  if (!form.value.name || !form.value.sku) return;
  await createIngredient({
    ...form.value,
    barcode: form.value.barcode || null,
    supplier_id: null,
    is_active: true,
  });
  showForm.value = false;
  form.value = { name: "", sku: "", barcode: "", unit: "pcs", minimum_stock: 0, cost: 0 };
  await load();
}

async function archive(id: string) {
  if (!confirm("Archive this ingredient?")) return;
  await archiveIngredient(id);
  await load();
}

onMounted(load);
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h2 class="text-lg font-semibold text-white">Ingredients</h2>
      <button
        class="flex items-center gap-1.5 rounded-lg bg-amber-600 px-3 py-2 text-sm font-medium text-white hover:bg-amber-500"
        @click="showForm = !showForm"
      >
        <Plus class="h-4 w-4" />
        Add
      </button>
    </div>

    <div v-if="showForm" class="rounded-xl border border-gray-700 bg-gray-800 p-4">
      <div class="mb-3 flex items-center justify-between">
        <h3 class="text-sm font-medium text-white">New Ingredient</h3>
        <button @click="showForm = false" class="text-gray-400 hover:text-white">
          <X class="h-4 w-4" />
        </button>
      </div>
      <form @submit.prevent="submit" class="grid grid-cols-2 gap-3">
        <input
          v-model="form.name"
          placeholder="Name"
          class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white placeholder-gray-500"
        />
        <input
          v-model="form.sku"
          placeholder="SKU"
          class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white placeholder-gray-500"
        />
        <input
          v-model="form.barcode"
          placeholder="Barcode (optional)"
          class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white placeholder-gray-500"
        />
        <select
          v-model="form.unit"
          class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white"
        >
          <option v-for="u in units" :key="u" :value="u">{{ u }}</option>
        </select>
        <input
          v-model.number="form.minimum_stock"
          type="number"
          placeholder="Min stock"
          class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white placeholder-gray-500"
        />
        <input
          v-model.number="form.cost"
          type="number"
          placeholder="Cost"
          class="rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white placeholder-gray-500"
        />
        <button
          type="submit"
          class="col-span-2 rounded-lg bg-emerald-600 px-3 py-2 text-sm font-medium text-white hover:bg-emerald-500"
        >
          Save
        </button>
      </form>
    </div>

    <div class="rounded-xl border border-gray-700 bg-gray-800">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b border-gray-700 text-left text-gray-400">
            <th class="p-3">Name</th>
            <th class="p-3">SKU</th>
            <th class="p-3">Unit</th>
            <th class="p-3 text-right">Stock</th>
            <th class="p-3 text-right">Min</th>
            <th class="p-3 text-right">Cost</th>
            <th class="p-3"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="ing in ingredients"
            :key="ing.id"
            class="border-b border-gray-700/50 hover:bg-gray-700/30"
          >
            <td class="p-3 text-white">{{ ing.name }}</td>
            <td class="p-3 text-gray-400">{{ ing.sku }}</td>
            <td class="p-3 text-gray-400">{{ ing.unit }}</td>
            <td class="p-3 text-right" :class="ing.stock <= ing.minimum_stock ? 'text-red-400 font-medium' : 'text-white'">
              {{ ing.stock }}
            </td>
            <td class="p-3 text-right text-gray-400">{{ ing.minimum_stock }}</td>
            <td class="p-3 text-right text-gray-400">{{ ing.cost.toLocaleString() }}</td>
            <td class="p-3 text-right">
              <button @click="archive(ing.id)" class="text-xs text-gray-500 hover:text-red-400">Archive</button>
            </td>
          </tr>
          <tr v-if="ingredients.length === 0">
            <td colspan="7" class="p-6 text-center text-gray-500">
              <Package class="mx-auto mb-2 h-8 w-8" />
              No ingredients yet
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
