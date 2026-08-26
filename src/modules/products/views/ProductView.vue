<script setup lang="ts">
import { onMounted, ref, computed } from "vue";
import { Coffee } from "lucide-vue-next";
import { useProductStore } from "@/modules/products/stores/product";
import { useCategoryStore } from "@/modules/products/stores/category";
import type { Product } from "@/types";

const productStore = useProductStore();
const categoryStore = useCategoryStore();

const showModal = ref(false);
const editingId = ref<string | null>(null);
const searchQuery = ref("");
const filterCategory = ref<string>("all");
const form = ref({
  name: "",
  sku: "",
  barcode: "",
  category_id: "",
  cost_price: 0,
  selling_price: 0,
  description: "",
  taxable: true,
  track_inventory: false,
});
const imageFile = ref<File | null>(null);

onMounted(() => {
  productStore.fetchProducts();
  categoryStore.fetchCategories();
});

const filteredProducts = computed(() => {
  let list = productStore.products;
  if (filterCategory.value !== "all") {
    list = list.filter((p) => p.category_id === filterCategory.value);
  }
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    list = list.filter(
      (p) =>
        p.name.toLowerCase().includes(q) ||
        p.sku?.toLowerCase().includes(q) ||
        p.barcode?.includes(q),
    );
  }
  return list;
});

function openCreate() {
  editingId.value = null;
  form.value = {
    name: "",
    sku: "",
    barcode: "",
    category_id: "",
    cost_price: 0,
    selling_price: 0,
    description: "",
    taxable: true,
    track_inventory: false,
  };
  imageFile.value = null;
  showModal.value = true;
}

function openEdit(product: Product) {
  editingId.value = product.id;
  form.value = {
    name: product.name,
    sku: product.sku ?? "",
    barcode: product.barcode ?? "",
    category_id: product.category_id ?? "",
    cost_price: product.cost_price,
    selling_price: product.selling_price,
    description: product.description ?? "",
    taxable: product.taxable,
    track_inventory: product.track_inventory,
  };
  imageFile.value = null;
  showModal.value = true;
}

function onImageChange(e: Event) {
  const input = e.target as HTMLInputElement;
  imageFile.value = input.files?.[0] ?? null;
}

async function handleSubmit() {
  if (!form.value.name.trim()) return;

  const payload = {
    ...form.value,
    sku: form.value.sku || null,
    barcode: form.value.barcode || null,
    category_id: form.value.category_id || null,
    image_url: null as string | null,
    is_active: true,
  };

  if (editingId.value) {
    await productStore.editProduct(editingId.value, payload);
    if (imageFile.value && editingId.value) {
      await productStore.uploadImage(editingId.value, imageFile.value);
    }
  } else {
    const success = await productStore.addProduct(payload);
    if (success && imageFile.value && productStore.products.length > 0) {
      const newest = productStore.products[0];
      await productStore.uploadImage(newest.id, imageFile.value);
    }
  }
  showModal.value = false;
}

async function handleArchive(id: string) {
  await productStore.archive(id);
}

async function handleRestore(id: string) {
  await productStore.restore(id);
}

async function handleDelete(id: string) {
  if (confirm("Delete this product permanently?")) {
    await productStore.remove(id);
  }
}

function formatCurrency(amount: number) {
  return new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR" }).format(amount);
}
</script>

<template>
  <div>
    <div class="mb-6 flex items-center justify-between">
      <h2 class="text-2xl font-semibold">Products</h2>
      <button
        class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition hover:opacity-90"
        @click="openCreate"
      >
        + Add Product
      </button>
    </div>

    <!-- Filters -->
    <div class="mb-4 flex gap-3">
      <input
        v-model="searchQuery"
        type="text"
        placeholder="Search name, SKU, barcode..."
        class="w-full max-w-xs rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
      />
      <select
        v-model="filterCategory"
        class="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none"
      >
        <option value="all">All Categories</option>
        <option v-for="cat in categoryStore.categories" :key="cat.id" :value="cat.id">
          {{ cat.name }}
        </option>
      </select>
    </div>

    <!-- Loading -->
    <div v-if="productStore.loading" class="py-12 text-center text-secondary">Loading...</div>

    <!-- Empty -->
    <div
      v-else-if="filteredProducts.length === 0"
      class="rounded-2xl border border-dashed border-gray-300 py-12 text-center"
    >
      <p class="text-secondary">No products found</p>
      <button class="mt-2 text-sm text-primary hover:underline" @click="openCreate">Add one</button>
    </div>

    <!-- Table -->
    <div v-else class="overflow-hidden rounded-xl border bg-surface">
      <table class="w-full text-left text-sm">
        <thead class="border-b bg-gray-50 text-xs uppercase text-secondary">
          <tr>
            <th class="px-4 py-3">Product</th>
            <th class="px-4 py-3">SKU</th>
            <th class="px-4 py-3">Barcode</th>
            <th class="px-4 py-3">Category</th>
            <th class="px-4 py-3 text-right">Cost</th>
            <th class="px-4 py-3 text-right">Price</th>
            <th class="px-4 py-3">Status</th>
            <th class="px-4 py-3 text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="product in filteredProducts" :key="product.id" class="border-b last:border-0">
            <td class="px-4 py-3">
              <div class="flex items-center gap-3">
                <img
                  v-if="product.image_url"
                  :src="product.image_url"
                  class="h-8 w-8 rounded object-cover"
                />
                <div
                  v-else
                  class="flex h-8 w-8 items-center justify-center rounded bg-gray-100 text-xs"
                >
                  <Coffee :size="14" :stroke-width="1.8" class="text-gray-400" />
                </div>
                <span class="font-medium">{{ product.name }}</span>
              </div>
            </td>
            <td class="px-4 py-3 text-secondary">{{ product.sku || "—" }}</td>
            <td class="px-4 py-3 font-mono text-xs">{{ product.barcode || "—" }}</td>
            <td class="px-4 py-3 text-secondary">
              {{ (product as { categories?: { name: string } }).categories?.name || "—" }}
            </td>
            <td class="px-4 py-3 text-right text-secondary">
              {{ formatCurrency(product.cost_price) }}
            </td>
            <td class="px-4 py-3 text-right font-medium">
              {{ formatCurrency(product.selling_price) }}
            </td>
            <td class="px-4 py-3">
              <span
                :class="product.is_active ? 'text-success' : 'text-secondary'"
                class="text-xs font-medium"
              >
                {{ product.is_active ? "Active" : "Archived" }}
              </span>
            </td>
            <td class="px-4 py-3 text-right">
              <div class="flex items-center justify-end gap-2">
                <button class="text-xs text-primary hover:underline" @click="openEdit(product)">
                  Edit
                </button>
                <button
                  v-if="product.is_active"
                  class="text-xs text-warning hover:underline"
                  @click="handleArchive(product.id)"
                >
                  Archive
                </button>
                <button
                  v-else
                  class="text-xs text-success hover:underline"
                  @click="handleRestore(product.id)"
                >
                  Restore
                </button>
                <button
                  class="text-xs text-danger hover:underline"
                  @click="handleDelete(product.id)"
                >
                  Delete
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal -->
    <Teleport to="body">
      <div
        v-if="showModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="showModal = false"
      >
        <div
          class="w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-2xl bg-surface p-6 shadow-lg"
        >
          <h3 class="mb-4 text-lg font-semibold">
            {{ editingId ? "Edit Product" : "New Product" }}
          </h3>
          <form class="space-y-4" @submit.prevent="handleSubmit">
            <div class="grid grid-cols-2 gap-4">
              <div class="col-span-2">
                <label class="mb-1 block text-sm font-medium">Name *</label>
                <input
                  v-model="form.name"
                  type="text"
                  class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                  required
                />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">SKU</label>
                <input
                  v-model="form.sku"
                  type="text"
                  class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">Barcode</label>
                <input
                  v-model="form.barcode"
                  type="text"
                  class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">Category</label>
                <select
                  v-model="form.category_id"
                  class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none"
                >
                  <option value="">None</option>
                  <option v-for="cat in categoryStore.categories" :key="cat.id" :value="cat.id">
                    {{ cat.name }}
                  </option>
                </select>
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">Image</label>
                <input
                  type="file"
                  accept="image/*"
                  class="w-full text-sm text-secondary file:mr-3 file:rounded-lg file:border-0 file:bg-gray-100 file:px-3 file:py-1.5 file:text-sm hover:file:bg-gray-200"
                  @change="onImageChange"
                />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">Cost Price</label>
                <input
                  v-model.number="form.cost_price"
                  type="number"
                  min="0"
                  class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">Selling Price *</label>
                <input
                  v-model.number="form.selling_price"
                  type="number"
                  min="0"
                  class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                  required
                />
              </div>
              <div class="col-span-2">
                <label class="mb-1 block text-sm font-medium">Description</label>
                <textarea
                  v-model="form.description"
                  rows="2"
                  class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                />
              </div>
              <div class="col-span-2 flex gap-6">
                <label class="flex items-center gap-2 text-sm">
                  <input v-model="form.taxable" type="checkbox" class="rounded" />
                  Taxable
                </label>
                <label class="flex items-center gap-2 text-sm">
                  <input v-model="form.track_inventory" type="checkbox" class="rounded" />
                  Track Inventory
                </label>
              </div>
            </div>
            <div class="flex justify-end gap-2 pt-2">
              <button
                type="button"
                class="rounded-lg border px-4 py-2 text-sm text-secondary hover:bg-gray-50"
                @click="showModal = false"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90"
              >
                {{ editingId ? "Save Changes" : "Create Product" }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </Teleport>
  </div>
</template>
