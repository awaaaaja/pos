<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useCategoryStore } from "@/modules/products/stores/category";

const store = useCategoryStore();

const showModal = ref(false);
const editingId = ref<string | null>(null);
const form = ref({ name: "", description: "", sort_order: 0 });

onMounted(() => {
  store.fetchCategories();
});

function openCreate() {
  editingId.value = null;
  form.value = { name: "", description: "", sort_order: 0 };
  showModal.value = true;
}

function openEdit(category: {
  id: string;
  name: string;
  description: string | null;
  sort_order: number;
}) {
  editingId.value = category.id;
  form.value = {
    name: category.name,
    description: category.description ?? "",
    sort_order: category.sort_order,
  };
  showModal.value = true;
}

async function handleSubmit() {
  if (!form.value.name.trim()) return;

  if (editingId.value) {
    await store.editCategory(editingId.value, form.value);
  } else {
    await store.addCategory(form.value);
  }
  showModal.value = false;
}

async function handleArchive(id: string) {
  await store.archive(id);
}

async function handleRestore(id: string) {
  await store.restore(id);
}

async function handleDelete(id: string) {
  if (confirm("Delete this category permanently?")) {
    await store.remove(id);
  }
}
</script>

<template>
  <div>
    <div class="mb-6 flex items-center justify-between">
      <h2 class="text-2xl font-semibold">Categories</h2>
      <button
        class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white transition hover:opacity-90"
        @click="openCreate"
      >
        + Add Category
      </button>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="py-12 text-center text-secondary">Loading...</div>

    <!-- Empty -->
    <div
      v-else-if="store.categories.length === 0"
      class="rounded-2xl border border-dashed border-gray-300 py-12 text-center"
    >
      <p class="text-secondary">No categories yet</p>
      <button class="mt-2 text-sm text-primary hover:underline" @click="openCreate">
        Create one
      </button>
    </div>

    <!-- Table -->
    <div v-else class="overflow-hidden rounded-xl border bg-surface">
      <table class="w-full text-left text-sm">
        <thead class="border-b bg-gray-50 text-xs uppercase text-secondary">
          <tr>
            <th class="px-4 py-3">Name</th>
            <th class="px-4 py-3">Description</th>
            <th class="px-4 py-3">Sort</th>
            <th class="px-4 py-3">Status</th>
            <th class="px-4 py-3 text-right">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="cat in store.categories" :key="cat.id" class="border-b last:border-0">
            <td class="px-4 py-3 font-medium">{{ cat.name }}</td>
            <td class="px-4 py-3 text-secondary">{{ cat.description || "—" }}</td>
            <td class="px-4 py-3">{{ cat.sort_order }}</td>
            <td class="px-4 py-3">
              <span
                :class="cat.is_active ? 'text-success' : 'text-secondary'"
                class="text-xs font-medium"
              >
                {{ cat.is_active ? "Active" : "Archived" }}
              </span>
            </td>
            <td class="px-4 py-3 text-right">
              <div class="flex items-center justify-end gap-2">
                <button class="text-xs text-primary hover:underline" @click="openEdit(cat)">
                  Edit
                </button>
                <button
                  v-if="cat.is_active"
                  class="text-xs text-warning hover:underline"
                  @click="handleArchive(cat.id)"
                >
                  Archive
                </button>
                <button
                  v-else
                  class="text-xs text-success hover:underline"
                  @click="handleRestore(cat.id)"
                >
                  Restore
                </button>
                <button class="text-xs text-danger hover:underline" @click="handleDelete(cat.id)">
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
        <div class="w-full max-w-md rounded-2xl bg-surface p-6 shadow-lg">
          <h3 class="mb-4 text-lg font-semibold">
            {{ editingId ? "Edit Category" : "New Category" }}
          </h3>
          <form class="space-y-4" @submit.prevent="handleSubmit">
            <div>
              <label class="mb-1 block text-sm font-medium">Name</label>
              <input
                v-model="form.name"
                type="text"
                class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                required
              />
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Description</label>
              <input
                v-model="form.description"
                type="text"
                class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Sort Order</label>
              <input
                v-model.number="form.sort_order"
                type="number"
                class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
              />
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
                {{ editingId ? "Save Changes" : "Create" }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </Teleport>
  </div>
</template>
