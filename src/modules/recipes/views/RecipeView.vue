<script setup lang="ts">
import { ref, onMounted } from "vue";
import { fetchRecipes, createRecipe, updateRecipeItems, deleteRecipe } from "@/modules/recipes/services/recipe";
import { fetchIngredients } from "@/modules/inventory/services/ingredient";
import { getActiveProducts } from "@/modules/products/services/product";
import type { Recipe, Ingredient, Product } from "@/types";
import { BookOpen, Plus, Trash2, X } from "lucide-vue-next";

const recipes = ref<Recipe[]>([]);
const ingredients = ref<Ingredient[]>([]);
const products = ref<Product[]>([]);
const showForm = ref(false);
const form = ref({ productId: "" });
const formItems = ref<{ ingredient_id: string; qty: number }[]>([{ ingredient_id: "", qty: 1 }]);

async function load() {
  const [r, i, p] = await Promise.all([
    fetchRecipes(),
    fetchIngredients(),
    getActiveProducts(),
  ]);
  recipes.value = r;
  ingredients.value = i;
  products.value = p.data ?? [];
}

function addItem() {
  formItems.value.push({ ingredient_id: "", qty: 1 });
}

function removeItem(index: number) {
  formItems.value.splice(index, 1);
}

async function submit() {
  if (!form.value.productId || formItems.value.length === 0) return;
  const validItems = formItems.value.filter((i) => i.ingredient_id && i.qty > 0);
  if (validItems.length === 0) return;

  await createRecipe(form.value.productId, validItems);
  showForm.value = false;
  form.value = { productId: "" };
  formItems.value = [{ ingredient_id: "", qty: 1 }];
  await load();
}

async function remove(id: string) {
  if (!confirm("Delete this recipe?")) return;
  await deleteRecipe(id);
  await load();
}

onMounted(load);
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h2 class="text-lg font-semibold text-white">Recipes</h2>
      <button
        class="flex items-center gap-1.5 rounded-lg bg-amber-600 px-3 py-2 text-sm font-medium text-white hover:bg-amber-500"
        @click="showForm = !showForm"
      >
        <Plus class="h-4 w-4" />
        Add Recipe
      </button>
    </div>

    <div v-if="showForm" class="rounded-xl border border-gray-700 bg-gray-800 p-4">
      <div class="mb-3 flex items-center justify-between">
        <h3 class="text-sm font-medium text-white">New Recipe</h3>
        <button @click="showForm = false" class="text-gray-400 hover:text-white">
          <X class="h-4 w-4" />
        </button>
      </div>
      <form @submit.prevent="submit" class="space-y-3">
        <select
          v-model="form.productId"
          class="w-full rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white"
        >
          <option value="" disabled>Select product</option>
          <option v-for="p in products" :key="p.id" :value="p.id">{{ p.name }}</option>
        </select>

        <div class="space-y-2">
          <div v-for="(item, idx) in formItems" :key="idx" class="flex gap-2">
            <select
              v-model="item.ingredient_id"
              class="flex-1 rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white"
            >
              <option value="" disabled>Ingredient</option>
              <option v-for="i in ingredients" :key="i.id" :value="i.id">
                {{ i.name }} ({{ i.unit }})
              </option>
            </select>
            <input
              v-model.number="item.qty"
              type="number"
              min="0.01"
              step="0.01"
              placeholder="Qty"
              class="w-24 rounded-lg border border-gray-600 bg-gray-900 px-3 py-2 text-sm text-white"
            />
            <button
              type="button"
              @click="removeItem(idx)"
              class="rounded-lg bg-gray-700 px-2 text-gray-400 hover:text-red-400"
            >
              <Trash2 class="h-4 w-4" />
            </button>
          </div>
        </div>

        <button type="button" @click="addItem" class="text-xs text-amber-400 hover:text-amber-300">
          + Add ingredient
        </button>

        <button
          type="submit"
          class="w-full rounded-lg bg-emerald-600 px-3 py-2 text-sm font-medium text-white hover:bg-emerald-500"
        >
          Save Recipe
        </button>
      </form>
    </div>

    <div class="space-y-3">
      <div
        v-for="recipe in recipes"
        :key="recipe.id"
        class="rounded-xl border border-gray-700 bg-gray-800 p-4"
      >
        <div class="mb-2 flex items-center justify-between">
          <span class="font-medium text-white">{{ recipe.product?.name ?? "Unknown" }}</span>
          <button @click="remove(recipe.id)" class="text-gray-500 hover:text-red-400">
            <Trash2 class="h-4 w-4" />
          </button>
        </div>
        <div class="space-y-1">
          <div
            v-for="ri in recipe.recipe_items"
            :key="ri.id"
            class="flex items-center justify-between text-sm text-gray-400"
          >
            <span>{{ ri.ingredient?.name ?? "Unknown" }}</span>
            <span class="text-white">{{ ri.qty }} {{ ri.ingredient?.unit }}</span>
          </div>
          <p v-if="!recipe.recipe_items?.length" class="text-xs text-gray-600">No ingredients mapped</p>
        </div>
      </div>

      <p v-if="recipes.length === 0" class="py-12 text-center text-gray-500">
        <BookOpen class="mx-auto mb-2 h-8 w-8" />
        No recipes defined
      </p>
    </div>
  </div>
</template>
