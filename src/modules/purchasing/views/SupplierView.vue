<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useSupplierStore } from "@/modules/purchasing/stores/supplier";

const store = useSupplierStore();
const showModal = ref(false);
const editingId = ref<string | null>(null);
const form = ref({
  name: "",
  contact_person: "",
  phone: "",
  email: "",
  address: "",
  payment_terms: "",
});

onMounted(() => store.fetch());

function openCreate() {
  editingId.value = null;
  form.value = {
    name: "",
    contact_person: "",
    phone: "",
    email: "",
    address: "",
    payment_terms: "",
  };
  showModal.value = true;
}

function openEdit(s: {
  id: string;
  name: string;
  contact_person: string | null;
  phone: string | null;
  email: string | null;
  address: string | null;
  payment_terms: string | null;
}) {
  editingId.value = s.id;
  form.value = {
    name: s.name,
    contact_person: s.contact_person || "",
    phone: s.phone || "",
    email: s.email || "",
    address: s.address || "",
    payment_terms: s.payment_terms || "",
  };
  showModal.value = true;
}

async function handleSubmit() {
  if (!form.value.name.trim()) return;
  if (editingId.value) {
    await store.edit(editingId.value, form.value);
  } else {
    await store.add(form.value);
  }
  showModal.value = false;
}

async function handleDelete(id: string) {
  if (confirm("Delete this supplier?")) {
    await store.remove(id);
    showModal.value = false;
  }
}
</script>

<template>
  <div class="mx-auto max-w-4xl py-6">
    <div class="mb-6 flex items-center justify-between">
      <h2 class="text-2xl font-semibold">Suppliers</h2>
      <button
        class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90"
        @click="openCreate"
      >
        + Add Supplier
      </button>
    </div>

    <div v-if="store.loading" class="py-12 text-center text-secondary">Loading...</div>
    <div
      v-else-if="store.suppliers.length === 0"
      class="rounded-2xl border border-dashed py-12 text-center text-secondary"
    >
      No suppliers yet
    </div>
    <div v-else class="overflow-x-auto rounded-2xl border bg-surface">
      <table class="w-full text-left text-sm">
        <thead class="border-b bg-gray-50 text-xs text-secondary">
          <tr>
            <th class="px-4 py-2">Name</th>
            <th class="px-4 py-2">Contact</th>
            <th class="px-4 py-2">Phone</th>
            <th class="px-4 py-2">Payment Terms</th>
            <th class="px-4 py-2"></th>
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-for="s in store.suppliers" :key="s.id" class="hover:bg-gray-50">
            <td class="px-4 py-3 font-medium">{{ s.name }}</td>
            <td class="px-4 py-3 text-secondary">{{ s.contact_person || "-" }}</td>
            <td class="px-4 py-3 text-secondary">{{ s.phone || "-" }}</td>
            <td class="px-4 py-3 text-secondary">{{ s.payment_terms || "-" }}</td>
            <td class="px-4 py-3">
              <button class="text-xs text-primary hover:underline" @click="openEdit(s)">
                Edit
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <Teleport to="body">
      <div
        v-if="showModal"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        @click.self="showModal = false"
      >
        <div class="w-full max-w-md rounded-2xl bg-surface p-6 shadow-lg">
          <h3 class="mb-4 text-lg font-semibold">{{ editingId ? "Edit" : "New" }} Supplier</h3>
          <form class="space-y-3" @submit.prevent="handleSubmit">
            <div>
              <label class="mb-1 block text-sm font-medium">Name *</label
              ><input
                v-model="form.name"
                type="text"
                class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
                required
              />
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Contact Person</label
              ><input
                v-model="form.contact_person"
                type="text"
                class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
              />
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="mb-1 block text-sm font-medium">Phone</label
                ><input
                  v-model="form.phone"
                  type="text"
                  class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
                />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">Email</label
                ><input
                  v-model="form.email"
                  type="email"
                  class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
                />
              </div>
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Address</label
              ><textarea
                v-model="form.address"
                rows="2"
                class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
              ></textarea>
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Payment Terms</label
              ><input
                v-model="form.payment_terms"
                type="text"
                placeholder="e.g. NET 30, COD"
                class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
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
                {{ editingId ? "Save" : "Create" }}
              </button>
            </div>
            <button
              v-if="editingId"
              type="button"
              class="w-full text-center text-sm text-danger hover:underline"
              @click="handleDelete(editingId!)"
            >
              Delete Supplier
            </button>
          </form>
        </div>
      </div>
    </Teleport>
  </div>
</template>
