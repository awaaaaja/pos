<script setup lang="ts">
import { onMounted, ref } from "vue";
import { getExpenses, createExpense, deleteExpense } from "@/modules/expenses/services/expense";
import { supabase } from "@/services/supabase";
import { logAuditEvent } from "@/modules/auth/services/auth";
import { useToast } from "@/composables/useToast";
import type { Expense } from "@/types";

const toast = useToast();

const expenses = ref<Expense[]>([]);
const loading = ref(false);
const showModal = ref(false);
const uploading = ref(false);

const categories = [
  "Rent",
  "Utilities",
  "Salary",
  "Maintenance",
  "Supplies",
  "Transport",
  "Marketing",
  "Other",
];
const form = ref({
  category: "",
  amount: 0,
  description: "",
  date: new Date().toISOString().split("T")[0],
});
const attachmentFile = ref<File | null>(null);

onMounted(fetch);

async function fetch() {
  loading.value = true;
  const r = await getExpenses();
  expenses.value = r.data ?? [];
  loading.value = false;
}

function openCreate() {
  form.value = {
    category: "",
    amount: 0,
    description: "",
    date: new Date().toISOString().split("T")[0],
  };
  attachmentFile.value = null;
  showModal.value = true;
}

async function handleCreate() {
  if (!form.value.category || form.value.amount <= 0) return;

  let attachmentUrl: string | undefined;
  if (attachmentFile.value) {
    uploading.value = true;
    const path = `expenses/${Date.now()}-${attachmentFile.value.name}`;
    const { error: uploadError } = await supabase.storage
      .from("product-images")
      .upload(path, attachmentFile.value);
    if (!uploadError) {
      const { data: urlData } = supabase.storage.from("product-images").getPublicUrl(path);
      attachmentUrl = urlData.publicUrl;
    }
    uploading.value = false;
  }

  const r = await createExpense({ ...form.value, attachment_url: attachmentUrl });
  if (r.error) {
    toast.error(r.error);
    return;
  }
  expenses.value.unshift(r.data!);
  logAuditEvent({
    action: "create",
    entity_type: "expense",
    entity_id: r.data!.id,
    detail: { category: form.value.category, amount: form.value.amount },
  });
  showModal.value = false;
}

async function handleDelete(id: string) {
  if (!confirm("Delete this expense?")) return;
  const r = await deleteExpense(id);
  if (r.error) {
    toast.error(r.error);
    return;
  }
  expenses.value = expenses.value.filter((e) => e.id !== id);
  logAuditEvent({ action: "delete", entity_type: "expense", entity_id: id });
}

function formatCurrency(n: number) {
  return new Intl.NumberFormat("id-ID", {
    style: "currency",
    currency: "IDR",
    minimumFractionDigits: 0,
  }).format(n);
}
</script>

<template>
  <div class="mx-auto max-w-4xl py-6">
    <div class="mb-6 flex items-center justify-between">
      <h2 class="text-2xl font-semibold">Expenses</h2>
      <button
        class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90"
        @click="openCreate"
      >
        + Add Expense
      </button>
    </div>

    <div v-if="loading" class="py-12 text-center text-secondary">Loading...</div>
    <div
      v-else-if="expenses.length === 0"
      class="rounded-2xl border border-dashed py-12 text-center text-secondary"
    >
      No expenses yet
    </div>
    <div v-else class="overflow-x-auto rounded-2xl border bg-surface">
      <table class="w-full text-left text-sm">
        <thead class="border-b bg-gray-50 text-xs text-secondary">
          <tr>
            <th class="px-4 py-2">Date</th>
            <th class="px-4 py-2">Category</th>
            <th class="px-4 py-2">Amount</th>
            <th class="px-4 py-2">Description</th>
            <th class="px-4 py-2"></th>
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-for="e in expenses" :key="e.id" class="hover:bg-gray-50">
            <td class="px-4 py-3 text-xs">{{ e.date }}</td>
            <td class="px-4 py-3">
              <span class="rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium">{{
                e.category
              }}</span>
            </td>
            <td class="px-4 py-3 font-medium text-danger">{{ formatCurrency(e.amount) }}</td>
            <td class="px-4 py-3 text-secondary">{{ e.description || "-" }}</td>
            <td class="px-4 py-3">
              <button class="text-xs text-danger hover:underline" @click="handleDelete(e.id)">
                Delete
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
          <h3 class="mb-4 text-lg font-semibold">New Expense</h3>
          <form class="space-y-4" @submit.prevent="handleCreate">
            <div>
              <label class="mb-1 block text-sm font-medium">Category *</label>
              <select
                v-model="form.category"
                class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
                required
              >
                <option value="" disabled>Select...</option>
                <option v-for="c in categories" :key="c" :value="c">{{ c }}</option>
              </select>
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Amount *</label>
              <input
                v-model.number="form.amount"
                type="number"
                min="1"
                class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
                required
              />
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Date *</label>
              <input
                v-model="form.date"
                type="date"
                class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
                required
              />
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Description</label>
              <textarea
                v-model="form.description"
                rows="2"
                class="w-full rounded-lg border px-3 py-2 text-sm focus:border-primary focus:outline-none"
              ></textarea>
            </div>
            <div>
              <label class="mb-1 block text-sm font-medium">Attachment</label>
              <input
                type="file"
                accept="image/*,.pdf"
                class="w-full text-sm file:mr-3 file:rounded-lg file:border-0 file:bg-primary/10 file:px-3 file:py-1 file:text-sm file:text-primary"
                @change="attachmentFile = ($event.target as HTMLInputElement).files?.[0] || null"
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
                :disabled="uploading"
                class="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90 disabled:opacity-40"
              >
                {{ uploading ? "Uploading..." : "Create" }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </Teleport>
  </div>
</template>
